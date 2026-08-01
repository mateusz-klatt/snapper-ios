import Foundation
import Combine
import os

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    private let logger = AppLogger.make(category: "Auth")

    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var error: LoginViewError?

    private var wsToken: String?
    private let session: URLSession
    private let apiBaseURLProvider: @MainActor () -> String

    /// Single-flight slot shared by token refresh and wallet scoping.
    /// Concurrent callers await the same session rotation so refresh
    /// cookies cannot race each other.
    ///
    /// Without this coalescing, multiple parallel REST calls (e.g.
    /// ``HomeView.loadData``'s ``async let`` orders + positions) that
    /// each receive a 401 would each call ``fetchFreshWsToken()`` ->
    /// stampede of refresh requests + race-y double logout when the
    /// refresh itself returns 401.
    private var refreshTask: Task<RefreshData?, Never>?
    private var refreshTaskId: UInt64?
    private var nextRefreshTaskId: UInt64 = 0
    /// Invalidates refresh work that belongs to a session being torn
    /// down. Cancellation alone is insufficient because another caller
    /// may already be queued on the cancelled task and otherwise start a
    /// replacement refresh while ``logout()`` is awaiting the server.
    private var refreshGeneration: UInt64 = 0
    private var isLoggingOut = false
    private var logoutTask: Task<Void, Never>?

    private let appStateProvider: @Sendable @MainActor () -> AppState

    /// Initialize the auth service.
    ///
    /// ``appStateProvider`` is a lazy closure rather than a stored
    /// ``AppState`` value to avoid a static-init cycle: ``AppState.shared``
    /// captures a closure pointing at ``APIClient.shared`` (which in
    /// turn holds ``AuthService.shared``). Resolving any singleton's
    /// dependency eagerly during another singleton's init would
    /// re-enter the chain. The closure captures the symbol but does
    /// not evaluate it until ``login()`` calls it after both
    /// singletons are fully initialized.
    init(
        session: URLSession = .shared,
        apiBaseURLProvider: @MainActor @escaping () -> String = { AppConfig.apiBaseURL },
        appStateProvider: @escaping @Sendable @MainActor () -> AppState = { AppState.shared }
    ) {
        self.session = session
        self.apiBaseURLProvider = apiBaseURLProvider
        self.appStateProvider = appStateProvider
    }

    private convenience init() {
        self.init(session: .shared)
    }

    func login(username: String, password: String) async {
        guard let url = URL(string: "\(apiBaseURLProvider())\(AppConfig.Endpoints.login)") else {
            error = .invalidURL
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
            self.error = .serializationFailed
            return
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                self.error = .invalidResponse
                return
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loginResponse = try decoder.decode(LoginResponse.self, from: data)
                currentUser = loginResponse.payload.user
                self.error = nil
                /// Persist the locale BEFORE flipping ``isAuthenticated``.
                /// Flipping the @Published bool triggers the root view's
                /// post-login navigation synchronously on the next
                /// SwiftUI runloop tick; any ``await`` placed AFTER the
                /// flip would return into a world where MarketDataView
                /// has already mounted and started its first description
                /// fetch against a stale backend ``default_language``.
                /// Sequencing the persist first guarantees first-fetch
                /// correctness without a refetch round-trip.
                await appStateProvider().syncLocaleToBackend(skipAuthCheck: true, authService: self)
                /// Defend against a server that 401s the immediate
                /// ``/auth/me/update`` call placed inside this login
                /// flow. ``APIClient.request`` calls ``authService.logout()``
                /// on terminal 401s, which clears ``currentUser`` and
                /// invalidates the cookies. ``syncLocaleToBackend``
                /// swallows the throw so without this guard ``login()``
                /// would proceed to set ``isAuthenticated = true`` with
                /// ``currentUser == nil`` against an already-invalidated
                /// session, dropping the user into a half-logged-in
                /// state the UI cannot recover from.
                guard currentUser != nil else {
                    self.error = .invalidResponse
                    return
                }
                isAuthenticated = true
                await DeviceRegistrationService.shared().onLogin()
            } else {
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                self.error = errorResponse.map { .serverDetail($0.detail) } ?? .loginFailed
            }
        } catch let decodingError as DecodingError {
            logger.error(
                "Login response decoding failed: \(String(describing: decodingError), privacy: .public)"
            )
            refreshGeneration &+= 1
            refreshTask?.cancel()
            refreshTask = nil
            refreshTaskId = nil
            wsToken = nil
            currentUser = nil
            isAuthenticated = false
            self.error = .invalidResponse
        } catch {
            self.error = .network(error.localizedDescription)
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
        if let logoutTask {
            await logoutTask.value
            return
        }

        isLoggingOut = true
        refreshGeneration &+= 1

        /// Cancel any in-flight refresh BEFORE tearing down local
        /// session state — without this, ``performRefresh()`` can
        /// resolve after logout completes and re-stamp ``wsToken``
        /// with a value bound to a session the user has just signed
        /// out of. The stale token would be picked up by the next
        /// WS reconnect (or REST 401 retry) and bind the next
        /// session to the prior identity for that token's lifetime.
        refreshTask?.cancel()
        refreshTask = nil
        refreshTaskId = nil

        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await DeviceRegistrationService.shared().onLogout()
            await self.logoutFromServer()
            self.wsToken = nil
            self.currentUser = nil
            self.isAuthenticated = false
            self.isLoggingOut = false
            self.logoutTask = nil
        }
        logoutTask = task
        await task.value
    }

    private func logoutFromServer() async {
        guard let url = URL(string: "\(apiBaseURLProvider())\(AppConfig.Endpoints.logout)") else {
            logger.warning("Logout aborted: invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConfig.ContentType.json, forHTTPHeaderField: AppConfig.HTTPHeader.contentType)
        /// Bound the logout/refresh endpoints at 10s so a dead network
        /// can't leave us wedged forever. `URLSession.shared` is
        /// immutable, so set this per-URLRequest — the test session is
        /// free to override via its own configuration.
        request.timeoutInterval = 10

        do {
            _ = try await session.data(for: request)
        } catch {
            /// Network-level logout failure is non-fatal: local session is
            /// still cleared in `logout()`, but server-side blacklist may
            /// not have run. Log loudly so an oncall reading the device
            /// log can correlate "stale session on next login" reports.
            logger.warning("Server-side logout failed (local state still cleared): \(error.localizedDescription, privacy: .public)")
        }
    }

    func hasPermission(_ permission: Permission) -> Bool {
        guard let user = currentUser else { return false }
        return user.effectivePermissions?.contains(permission) == true
    }

    func canAccess(_ resource: String) -> Bool {
        guard let user = currentUser,
              let requirement = resourceRequirements[resource] else {
            return false
        }

        let requirementSatisfied: Bool
        switch requirement {
        case .authenticated:
            requirementSatisfied = true
        case let .anyPermission(permissions):
            requirementSatisfied = permissions.contains { permission in
                user.effectivePermissions?.contains(permission) == true
            }
        }
        guard requirementSatisfied else { return false }

        /// ``ai-reviews`` deliberately has NO extra clause: the generated
        /// requirement is ``anyPermission([readAiReviews,
        /// submitAiReviewDecision])`` and the screen now hosts two
        /// surfaces — the read-only decision audit list (``read:ai_reviews``)
        /// and the delegate pending inbox (``submit:ai_review_decision``
        /// plus the delegate identity). Narrowing the gate back to
        /// ``read:ai_reviews`` would lock a pure ``aiDelegate`` — the very
        /// principal the inbox exists for — out of the screen. Which of the
        /// two surfaces actually renders is decided per-session by
        /// ``AiReviewsViewModel``.
        if resource == "backtests" {
            return user.activeWalletPublicId != nil
        }
        return true
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
        let fresh = await refresh()
        return fresh?.wsToken
    }

    func selectActiveWallet(_ publicId: String) async -> Bool {
        guard !isLoggingOut, currentUser != nil else { return false }
        if currentUser?.activeWalletPublicId == publicId {
            return true
        }
        let fresh = await refresh(
            payload: RefreshTokenPayload(activeWalletPublicId: publicId)
        )
        return fresh?.user.activeWalletPublicId == publicId
    }

    private func refresh(payload: RefreshTokenPayload? = nil) async -> RefreshData? {
        let generation = refreshGeneration
        guard !isLoggingOut, currentUser != nil else { return nil }

        /// Payload callers that need a different wallet scope wait for
        /// every already-running rotation before taking ownership of
        /// the slot. Re-evaluating the slot in a loop matters: several
        /// waiters can resume from the same task, and only the first may
        /// create the next request. The others must observe and await it
        /// instead of starting concurrent one-use refresh rotations.
        while let existing = refreshTask {
            let fresh = await existing.value
            guard refreshGeneration == generation, !isLoggingOut else {
                return nil
            }
            if refreshResult(fresh, satisfies: payload) {
                return fresh
            }
        }

        guard refreshGeneration == generation,
              !isLoggingOut,
              currentUser != nil else {
            return nil
        }

        nextRefreshTaskId &+= 1
        let taskId = nextRefreshTaskId
        let task = Task<RefreshData?, Never> { @MainActor [weak self] in
            guard let self else { return nil }
            defer {
                /// A cancelled task may finish after a new session has
                /// started. Clear only the exact slot this task owns so
                /// stale work cannot erase a replacement refresh.
                if self.refreshGeneration == generation,
                   self.refreshTaskId == taskId {
                    self.refreshTask = nil
                    self.refreshTaskId = nil
                }
            }
            guard !Task.isCancelled,
                  self.refreshGeneration == generation,
                  !self.isLoggingOut,
                  self.currentUser != nil else {
                return nil
            }
            let freshToken = await self.performRefresh(payload: payload)
            /// Bail out before the slot write if logout cancelled
            /// the task while the refresh was in flight — applying
            /// a freshly-minted token to a torn-down session would
            /// bind the next login to the prior session's
            /// backend-side state for that token's lifetime.
            if Task.isCancelled ||
                self.refreshGeneration != generation ||
                self.isLoggingOut {
                return nil
            }
            if let freshToken {
                self.wsToken = freshToken.wsToken
                self.currentUser = freshToken.user
            }
            return freshToken
        }
        refreshTask = task
        refreshTaskId = taskId
        return await task.value
    }

    /// Decide whether a completed rotation already fulfilled the
    /// caller's requested scope. Plain token callers coalesce with any
    /// result. Wallet callers continue serially only when the completed
    /// response represents a different wallet operation.
    private func refreshResult(
        _ fresh: RefreshData?,
        satisfies payload: RefreshTokenPayload?
    ) -> Bool {
        guard let payload else { return true }
        guard let fresh else { return false }
        if let activeWalletPublicId = payload.activeWalletPublicId {
            return fresh.user.activeWalletPublicId == activeWalletPublicId
        }
        if payload.clearActiveWallet == true {
            return fresh.user.activeWalletPublicId == nil
        }
        return true
    }

    /// Bare refresh request — callers go through ``refresh(payload:)``
    /// so concurrent session rotations coalesce. The slot owner writes
    /// refreshed session state only after its cancellation check.
    private func performRefresh(payload: RefreshTokenPayload?) async -> RefreshData? {
        guard let url = URL(string: "\(apiBaseURLProvider())\(AppConfig.Endpoints.refresh)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConfig.ContentType.json, forHTTPHeaderField: AppConfig.HTTPHeader.contentType)
        if let payload {
            let provenance = EnvelopeMinter.shared.next(.control)
            let envelope = RefreshTokenRequest(
                type: "refresh_token_request",
                sequenceId: provenance.sequenceId,
                publicId: provenance.publicId,
                timestamp: provenance.timestamp,
                sessionId: provenance.sessionId,
                topic: nil,
                payload: payload
            )
            do {
                request.httpBody = try Self.envelopeEncoder.encode(envelope)
            } catch {
                logger.error("Failed to encode refresh request: \(error)")
                return nil
            }
        }
        /// Cap refresh attempts at 10s — see logoutFromServer comment for
        /// rationale. Refresh payload is small, so 10s is generous for
        /// real networks; a legitimate hang means the network is dead.
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
            return refreshResponse.payload
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
