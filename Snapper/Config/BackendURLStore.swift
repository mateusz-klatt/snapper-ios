import Foundation
import os

/// Persistent runtime override for the backend base URL.
///
/// Defaults to the bundled ``Configuration.plist`` value (set by
/// Xcode Cloud's ``ci_post_clone.sh`` for App Store / TestFlight
/// builds). When the user supplies a custom backend via the Login
/// "Advanced" disclosure or Settings "Change backend…" sheet, the
/// canonicalized URL is persisted to UserDefaults and surfaced via
/// ``currentEffectiveURL()``. ``AppConfig.baseURL`` resolves through
/// this store so every downstream consumer (REST, WebSocket) picks
/// up the override on the next URL evaluation without rebuilding the
/// shared services.
///
/// Concurrency:
/// - The store is ``@unchecked Sendable``; mutable state lives
///   behind ``OSAllocatedUnfairLock`` so synchronous reads from the
///   ``APIClient`` ``@Sendable`` URL providers stay actor-free.
/// - Pure helpers (``canonicalize``) are ``static`` so callers can
///   validate input before reaching for the singleton.
///
/// Trust boundary:
/// - Persisted strings are revalidated via ``canonicalize`` on every
///   load. A corrupted UserDefaults entry is silently cleared and
///   the bundled default takes over — the store never returns a
///   URL that fails validation against the current build's policy
///   (e.g. release builds that reject ``http://``).
final class BackendURLStore: @unchecked Sendable {

    static let shared = BackendURLStore(userDefaults: .standard)

    static let userDefaultsKey = "snapper.customBackendURL"

    private static let logger = AppLogger.make(category: "BackendURLStore")

    private struct State: Sendable {
        var bundledBaseURL: URL
        var override: URL?

        var effective: URL {
            return override ?? bundledBaseURL
        }
    }

    private let userDefaults: UserDefaults
    private let lock: OSAllocatedUnfairLock<State>

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        let bundled = Self.loadBundledBaseURL()
        let initialOverride = Self.loadValidatedOverride(from: userDefaults)
        self.lock = OSAllocatedUnfairLock(initialState: State(
            bundledBaseURL: bundled,
            override: initialOverride
        ))
    }

    /// Sync, ``@Sendable``-callable getter for the effective URL.
    ///
    /// Returns the override if one is set; otherwise the bundled
    /// default. Always returns a valid URL.
    func currentEffectiveURL() -> URL {
        return lock.withLock { $0.effective }
    }

    /// Sync getter for the bundled base URL (Xcode Cloud / debug
    /// default), regardless of override state. Used by tests and by
    /// the Reset action in ``BackendURLEditor``.
    func bundledBaseURL() -> URL {
        return lock.withLock { $0.bundledBaseURL }
    }

    /// Returns ``true`` when a UserDefaults override is currently
    /// applied (regardless of whether it happens to equal the
    /// bundled default); ``false`` when no override is set.
    func hasOverride() -> Bool {
        return lock.withLock { $0.override != nil }
    }

    /// Persist a canonicalized override and update the cached
    /// effective URL. Callers MUST validate via ``canonicalize``
    /// first; passing an unvalidated URL is undefined behavior.
    func saveOverride(_ url: URL) {
        lock.withLock { state in
            state.override = url
        }
        userDefaults.set(url.absoluteString, forKey: Self.userDefaultsKey)
    }

    /// Remove any persisted override and revert to the bundled
    /// default URL. Idempotent.
    func clearOverride() {
        lock.withLock { state in
            state.override = nil
        }
        userDefaults.removeObject(forKey: Self.userDefaultsKey)
    }

    /// Canonicalize raw user input into a backend base URL.
    ///
    /// Rules (origin-only — anything beyond scheme+host+port is
    /// rejected so the URL always slots cleanly into the
    /// ``"\(baseURL)\(apiPrefix)\(endpoint)"`` interpolation pattern
    /// used by ``APIClient`` and ``WebSocketManager``):
    /// - Trim surrounding whitespace.
    /// - Lowercase scheme + host (RFC 3986 normalisation).
    /// - Reject path / query / fragment / userinfo segments.
    /// - Reject ``ws://`` / ``wss://`` (those are derived from
    ///   the base URL by ``AppConfig.makeWSBaseURL``).
    /// - In Release builds, reject anything that is not
    ///   ``https://`` — the App Store binary cannot honor ATS
    ///   exceptions and self-signed certificates.
    /// - Allow ``http://localhost``, ``http://127.x.x.x``, and
    ///   ``http://[::1]`` in Debug builds for local development.
    /// - Strip a trailing slash on the path so we never produce
    ///   ``...//api/...``.
    ///
    /// Returns ``nil`` on any rejection; callers MUST surface a
    /// human-readable validation error in the editor UI.
    static func canonicalize(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard var components = URLComponents(string: trimmed) else { return nil }

        let scheme = components.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else { return nil }
        components.scheme = scheme

        guard let host = components.host?.lowercased(), !host.isEmpty else { return nil }
        components.host = host

        // Release builds only allow https:// (App Store ATS).
        // Debug builds additionally permit http:// for loopback
        // addresses (localhost / 127.x.x.x / ::1) so developers
        // can point the app at a local server without TLS.
        #if !DEBUG
        if scheme == "http" { return nil }
        #else
        if scheme == "http" {
            let isLoopback = host == "localhost"
                || host == "::1"
                || host.hasPrefix("127.")
            guard isLoopback else { return nil }
        }
        #endif

        if components.user != nil || components.password != nil {
            return nil
        }
        if components.query != nil || components.fragment != nil {
            return nil
        }

        let path = components.percentEncodedPath
        if !(path.isEmpty || path == "/") {
            return nil
        }
        components.percentEncodedPath = ""

        return components.url
    }

    private static func loadBundledBaseURL() -> URL {
        guard
            let url = Bundle.main.url(forResource: "Configuration", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = plist as? [String: Any],
            let baseURLString = dict["BaseURL"] as? String,
            !baseURLString.isEmpty,
            let baseURL = URL(string: baseURLString)
        else {
            let message = "BackendURLStore: Configuration.plist missing or unparsable. App configuration is broken; defaulting to http://localhost:8000 so DEBUG launches surface the failure instead of crashing."
            logger.error("\(message, privacy: .public)")
            assertionFailure(message)
            return URL(string: "http://localhost:8000")!
        }
        return baseURL
    }

    private static func loadValidatedOverride(from defaults: UserDefaults) -> URL? {
        guard let raw = defaults.string(forKey: userDefaultsKey) else { return nil }
        guard let canonical = canonicalize(raw) else {
            logger.warning("Persisted custom backend URL failed re-validation; clearing.")
            defaults.removeObject(forKey: userDefaultsKey)
            return nil
        }
        return canonical
    }
}
