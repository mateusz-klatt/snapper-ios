import XCTest
@testable import Snapper

@MainActor
final class AppStateTests: XCTestCase {

    private static let walletKey = "selected_wallet_public_id"

    /// Build a UserDefaults instance backed by an ephemeral suite so
    /// concurrent test runs and stale state from prior runs cannot
    /// leak into the assertion under test.
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "test.AppStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testSelectedWalletDefaultsToNil() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(userDefaults: defaults)
        XCTAssertNil(state.selectedWalletPublicId)
    }

    func testSelectedWalletPersistsAcrossInstances() {
        let defaults = makeIsolatedDefaults()
        let writer = AppState(userDefaults: defaults)
        writer.selectedWalletPublicId = "wallet-abc"
        let reader = AppState(userDefaults: defaults)
        XCTAssertEqual(reader.selectedWalletPublicId, "wallet-abc")
    }

    func testSettingSelectedWalletToNilRemovesPersistence() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(userDefaults: defaults)
        state.selectedWalletPublicId = "wallet-xyz"
        XCTAssertEqual(defaults.string(forKey: Self.walletKey), "wallet-xyz")
        state.selectedWalletPublicId = nil
        XCTAssertNil(defaults.string(forKey: Self.walletKey))
    }

    func testFinancialColorPreferenceDefaultsToAuto() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(userDefaults: defaults)
        XCTAssertEqual(state.financialColorPreference, .auto)
    }

    func testFinancialColorPreferencePersistsAcrossInstances() {
        let defaults = makeIsolatedDefaults()
        let writer = AppState(userDefaults: defaults)
        writer.financialColorPreference = .risingRed
        let reader = AppState(userDefaults: defaults)
        XCTAssertEqual(reader.financialColorPreference, .risingRed)
    }

    func testFinancialColorPreferenceFallsBackToAutoForUnknownRawValue() {
        let defaults = makeIsolatedDefaults()
        defaults.set("not-a-real-value", forKey: financialColorPreferenceStorageKey)
        let state = AppState(userDefaults: defaults)
        XCTAssertEqual(state.financialColorPreference, .auto)
    }

    func testFinancialColorPreferenceWritesRawValueToUserDefaults() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(userDefaults: defaults)
        state.financialColorPreference = .risingGreen
        XCTAssertEqual(
            defaults.string(forKey: financialColorPreferenceStorageKey),
            "rising-green"
        )
    }

    /// Build an ``AppState`` whose initial ``locale`` is pinned to
    /// the supplied value via UserDefaults pre-population. Avoids
    /// triggering ``locale.didSet`` (and the in-flight task it
    /// spawns against the shared ``AuthService``) from the test
    /// body, so each test exercises ``syncLocaleToBackend`` through
    /// the explicit call with a controlled ``AuthService`` instance.
    private func makeAppState(
        locale: AppLocale,
        apiClientProvider: @escaping @Sendable @MainActor () -> APIClientProtocol
    ) -> (AppState, UserDefaults) {
        let defaults = makeIsolatedDefaults()
        defaults.set(locale.rawValue, forKey: "snapper-locale")
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["en"] },
            apiClientProvider: apiClientProvider
        )
        return (state, defaults)
    }

    /// Confirms ``syncLocaleToBackend(skipAuthCheck: false, ...)``
    /// no-ops when the supplied ``AuthService`` is logged out. The
    /// helper exits before touching ``apiClientProvider``, so the
    /// mock records zero calls.
    func testSyncLocaleSkipsBackendWhenLoggedOut() async {
        let mock = MockAPIClient()
        let calls = CallRecorder()
        mock.updateDefaultLanguageHandler = { lang in
            calls.record(lang)
        }
        let (appState, _) = makeAppState(locale: .us, apiClientProvider: { mock })
        let auth = AuthService(session: .shared, apiBaseURLProvider: { "http://test.invalid" })
        auth.isAuthenticated = false

        await appState.syncLocaleToBackend(skipAuthCheck: false, authService: auth)

        XCTAssertEqual(calls.values, [])
    }

    /// Authenticated locale change persists to backend via the mock.
    func testSyncLocalePersistsToBackendWhenAuthenticated() async {
        let mock = MockAPIClient()
        let calls = CallRecorder()
        mock.updateDefaultLanguageHandler = { lang in
            calls.record(lang)
        }
        let (appState, _) = makeAppState(locale: .pl, apiClientProvider: { mock })
        let auth = AuthService(session: .shared, apiBaseURLProvider: { "http://test.invalid" })
        auth.isAuthenticated = true

        await appState.syncLocaleToBackend(skipAuthCheck: false, authService: auth)

        XCTAssertEqual(calls.values, ["pl"])
    }

    /// Login-path entry point: ``skipAuthCheck: true`` MUST persist
    /// even when ``isAuthenticated`` is still false (the flip happens
    /// only after the persist returns, see ``AuthService.login``).
    func testSyncLocaleSkipAuthCheckTrueCallsAPIClientEvenWhenLoggedOut() async {
        let mock = MockAPIClient()
        let calls = CallRecorder()
        mock.updateDefaultLanguageHandler = { lang in
            calls.record(lang)
        }
        let (appState, _) = makeAppState(locale: .pl, apiClientProvider: { mock })
        let auth = AuthService(session: .shared, apiBaseURLProvider: { "http://test.invalid" })
        auth.isAuthenticated = false

        await appState.syncLocaleToBackend(skipAuthCheck: true, authService: auth)

        XCTAssertEqual(calls.values, ["pl"])
    }

    /// ``.appStateLocaleDidPersist`` is suppressed on backend error.
    func testLocalePersistNotificationSuppressedOnError() async {
        let failingMock = MockAPIClient()
        failingMock.updateDefaultLanguageHandler = { _ in
            throw APIError.invalidResponse
        }
        let (failingState, _) = makeAppState(locale: .pl, apiClientProvider: { failingMock })
        let auth = AuthService(session: .shared, apiBaseURLProvider: { "http://test.invalid" })
        auth.isAuthenticated = true

        let receivedFailure = NotificationCounter()
        let failureObserver = NotificationCenter.default.addObserver(
            forName: .appStateLocaleDidPersist,
            object: failingState,
            queue: nil
        ) { _ in receivedFailure.increment() }
        defer { NotificationCenter.default.removeObserver(failureObserver) }

        await failingState.syncLocaleToBackend(skipAuthCheck: false, authService: auth)

        XCTAssertEqual(receivedFailure.value, 0)
    }

    /// Same-locale assignment is a no-op: it does NOT cancel an
    /// in-flight sync or schedule a redundant network call.
    func testSameLocaleAssignmentIsNoOp() async {
        let mock = MockAPIClient()
        let calls = CallRecorder()
        mock.updateDefaultLanguageHandler = { lang in
            calls.record(lang)
        }
        let (appState, _) = makeAppState(locale: .pl, apiClientProvider: { mock })
        appState.locale = .pl
        await Task.yield()
        XCTAssertEqual(calls.values, [], "Reassigning the same locale must not trigger a backend persist.")
    }

    /// ``.appStateLocaleDidPersist`` fires on success with the
    /// persisted language in ``userInfo``.
    func testLocalePersistNotificationFiresOnSuccessWithLanguage() async {
        let successMock = MockAPIClient()
        successMock.updateDefaultLanguageHandler = { _ in }
        let (successState, _) = makeAppState(locale: .pl, apiClientProvider: { successMock })
        let auth = AuthService(session: .shared, apiBaseURLProvider: { "http://test.invalid" })
        auth.isAuthenticated = true

        let captured = NotificationCapture()
        let observer = NotificationCenter.default.addObserver(
            forName: .appStateLocaleDidPersist,
            object: successState,
            queue: nil
        ) { note in
            captured.record(language: note.userInfo?["language"] as? String)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await successState.syncLocaleToBackend(skipAuthCheck: false, authService: auth)
        await Task.yield()

        XCTAssertEqual(captured.languages, ["pl"])
    }
}

private final class CallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    func record(_ value: String) {
        lock.withLock { storage.append(value) }
    }
    var values: [String] {
        lock.withLock { storage }
    }
}

private final class NotificationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() {
        lock.withLock { count += 1 }
    }
    var value: Int {
        lock.withLock { count }
    }
}

private final class NotificationCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String?] = []
    func record(language: String?) {
        lock.withLock { storage.append(language) }
    }
    var languages: [String?] {
        lock.withLock { storage }
    }
}
