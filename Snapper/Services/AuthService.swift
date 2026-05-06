import Foundation
import Combine
import os

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Snapper", category: "Auth")

    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var errorMessage: String?

    private var wsToken: String?
    private let session: URLSession
    private let apiBaseURLProvider: @MainActor () -> String

    /// Single-flight slot for ``fetchFreshWsToken()``. When a refresh
    /// is in flight, concurrent callers ``await`` the same task value
    /// instead of launching parallel network requests. Cleared by
    /// the inner task's ``defer`` block once the request resolves so
    /// the next caller starts a fresh refresh.
    ///
    /// Without this coalescing, multiple parallel REST calls (e.g.
    /// ``HomeView.loadData``'s ``async let`` orders + positions) that
    /// each receive a 401 would each call ``fetchFreshWsToken()`` ->
    /// stampede of refresh requests + race-y double logout when the
    /// refresh itself returns 401.
    private var refreshTask: Task<String?, Never>?

    init(
        session: URLSession = .shared,
        apiBaseURLProvider: @MainActor @escaping () -> String = { AppConfig.apiBaseURL }
    ) {
        self.session = session
        self.apiBaseURLProvider = apiBaseURLProvider
    }

    private convenience init() {
        self.init(session: .shared)
    }

    func login(username: String, password: String) async {
        guard let url = URL(string: "\(apiBaseURLProvider())\(AppConfig.Endpoints.login)") else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConfig.ContentType.json, forHTTPHeaderField: AppConfig.HTTPHeader.contentType)

        let provenance = EnvelopeMinter.shared.next(.control)
        let envelope = LoginRequest(
            type: "login_request",
            sequenceId: provenance.sequenceId,
            publicId: provenance.publicId,
            timestamp: provenance.timestamp,
            sessionId: provenance.sessionId,
            topic: nil,
            payload: LoginBody(username: username, password: password, rememberMe: nil)
        )
        do {
            request.httpBody = try Self.envelopeEncoder.encode(envelope)
        } catch {
            errorMessage = "Failed to serialize login request"
            return
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                return
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loginResponse = try decoder.decode(LoginResponse.self, from: data)
                currentUser = loginResponse.payload.user
                errorMessage = nil
                isAuthenticated = true
                await DeviceRegistrationService.shared().onLogin()
            } else {
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                errorMessage = errorResponse?.detail ?? "Login failed"
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
    }

    /// Shared encoder for outbound provenance envelopes. The custom
    /// date strategy emits millisecond-precision ISO 8601 so REST
    /// and WebSocket frames carry timestamps in the same shape as
    /// the frontend's ``new Date().toISOString()`` (`stampProvenance`
    /// in `frontend/src/lib/apiClient.ts`).
    private static let envelopeEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(EnvelopeMinter.formatTimestamp(date))
        }
        return encoder
    }()

    func logout() async {
        // Cancel any in-flight refresh BEFORE tearing down local
        // session state — without this, ``performRefresh()`` can
        // resolve after logout completes and re-stamp ``wsToken``
        // with a value bound to a session the user has just signed
        // out of. The stale token would be picked up by the next
        // WS reconnect (or REST 401 retry) and bind the next
        // session to the prior identity for that token's lifetime.
        refreshTask?.cancel()
        refreshTask = nil

        await DeviceRegistrationService.shared().onLogout()
        await logoutFromServer()
        wsToken = nil
        currentUser = nil
        isAuthenticated = false
    }

    private func logoutFromServer() async {
        guard let url = URL(string: "\(apiBaseURLProvider())\(AppConfig.Endpoints.logout)") else {
            logger.warning("Logout aborted: invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConfig.ContentType.json, forHTTPHeaderField: AppConfig.HTTPHeader.contentType)
        // Bound the logout/refresh endpoints at 10s so a dead network
        // can't leave us wedged forever. `URLSession.shared` is
        // immutable, so set this per-URLRequest — the test session is
        // free to override via its own configuration.
        request.timeoutInterval = 10

        do {
            _ = try await session.data(for: request)
        } catch {
            // Network-level logout failure is non-fatal: local session is
            // still cleared in `logout()`, but server-side blacklist may
            // not have run. Log loudly so an oncall reading the device
            // log can correlate "stale session on next login" reports.
            logger.warning("Server-side logout failed (local state still cleared): \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let roleHierarchy: [UserRole: Int] = [
        .viewer: 1,
        .operatorRole: 2,
        .admin: 3,
    ]

    func hasRole(_ role: UserRole) -> Bool {
        guard let user = currentUser else { return false }
        let userLevel = Self.roleHierarchy[user.role] ?? 0
        let requiredLevel = Self.roleHierarchy[role] ?? 0
        return userLevel >= requiredLevel
    }

    func hasPermission(_ permission: Permission) -> Bool {
        guard let user = currentUser else { return false }
        if user.role == .admin { return true }
        let perms = rolePermissions[user.role] ?? []
        return perms.contains(permission)
    }

    func canAccess(_ resource: String) -> Bool {
        guard let user = currentUser else { return false }
        let allowed = resourceAccess[resource] ?? []
        return allowed.contains(user.role)
    }

    func getWsToken() -> String? {
        return wsToken
    }

    /// Coalesces concurrent refresh callers into a single in-flight
    /// network request. Mirrors the bridge's `withLock(...)` slot
    /// pattern: the first caller mints a ``Task``, stores it in
    /// ``refreshTask`` and awaits it; subsequent callers see the
    /// in-flight slot and await the same task instead of launching
    /// their own. Once the inner task completes, ``defer`` clears
    /// the slot so the next refresh window starts fresh.
    func fetchFreshWsToken() async -> String? {
        if let existing = refreshTask {
            return await existing.value
        }
        let task = Task<String?, Never> { @MainActor [weak self] in
            guard let self else { return nil }
            defer { self.refreshTask = nil }
            let freshToken = await self.performRefresh()
            // Bail out before the slot write if logout cancelled
            // the task while the refresh was in flight — applying
            // a freshly-minted token to a torn-down session would
            // bind the next login to the prior session's
            // backend-side state for that token's lifetime.
            if Task.isCancelled {
                return nil
            }
            if let freshToken {
                self.wsToken = freshToken
            }
            return freshToken
        }
        refreshTask = task
        return await task.value
    }

    /// Bare refresh request — never call this directly; go through
    /// ``fetchFreshWsToken()`` so concurrent callers coalesce.
    /// The slot owner (``fetchFreshWsToken``) is responsible for
    /// writing ``wsToken`` AFTER a ``Task.isCancelled`` check, so
    /// this helper deliberately does NOT touch member state.
    private func performRefresh() async -> String? {
        guard let url = URL(string: "\(apiBaseURLProvider())\(AppConfig.Endpoints.refresh)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConfig.ContentType.json, forHTTPHeaderField: AppConfig.HTTPHeader.contentType)
        // Cap refresh attempts at 10s — see logoutFromServer comment for
        // rationale. Refresh payload is small, so 10s is generous for
        // real networks; a legitimate hang means the network is dead.
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let refreshResponse = try decoder.decode(RefreshResponse.self, from: data)
            return refreshResponse.payload.wsToken
        } catch {
            logger.error("Failed to fetch fresh ws_token: \(error)")
            return nil
        }
    }
}

struct ErrorResponse: Codable {
    let detail: String
}

extension AuthService: AuthRefreshing {}
