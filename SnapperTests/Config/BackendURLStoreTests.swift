import XCTest
@testable import Snapper

/// Tests for ``BackendURLStore`` — covers canonicalize() validation
/// branches + override persistence roundtrip + invalid-on-launch
/// recovery.
///
/// Tests inject ephemeral ``UserDefaults(suiteName:)`` so they never
/// leak into the shared store used by other tests or by real app
/// launches.
final class BackendURLStoreTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suiteName = "snapper.test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults = nil
        super.tearDown()
    }

    // MARK: - canonicalize

    func testCanonicalizeAcceptsBareHTTPSURL() {
        let url = BackendURLStore.canonicalize("https://api.example.com")
        XCTAssertEqual(url?.absoluteString, "https://api.example.com")
    }

    func testCanonicalizeTrimsWhitespace() {
        let url = BackendURLStore.canonicalize("   https://api.example.com   ")
        XCTAssertEqual(url?.absoluteString, "https://api.example.com")
    }

    func testCanonicalizeLowercasesSchemeAndHost() {
        let url = BackendURLStore.canonicalize("HTTPS://API.EXAMPLE.COM")
        XCTAssertEqual(url?.absoluteString, "https://api.example.com")
    }

    func testCanonicalizeAcceptsExplicitPort() {
        let url = BackendURLStore.canonicalize("https://api.example.com:8443")
        XCTAssertEqual(url?.absoluteString, "https://api.example.com:8443")
    }

    func testCanonicalizeStripsTrailingSlash() {
        let url = BackendURLStore.canonicalize("https://api.example.com/")
        XCTAssertEqual(url?.absoluteString, "https://api.example.com")
    }

    func testCanonicalizeRejectsPath() {
        let url = BackendURLStore.canonicalize("https://api.example.com/api")
        XCTAssertNil(url)
    }

    func testCanonicalizeRejectsQuery() {
        let url = BackendURLStore.canonicalize("https://api.example.com?foo=bar")
        XCTAssertNil(url)
    }

    func testCanonicalizeRejectsFragment() {
        let url = BackendURLStore.canonicalize("https://api.example.com#frag")
        XCTAssertNil(url)
    }

    func testCanonicalizeRejectsUserInfo() {
        let url = BackendURLStore.canonicalize("https://user:pass@api.example.com")
        XCTAssertNil(url)
    }

    func testCanonicalizeRejectsWebsocketScheme() {
        let url = BackendURLStore.canonicalize("ws://api.example.com")
        XCTAssertNil(url)
    }

    func testCanonicalizeRejectsSecureWebsocketScheme() {
        let url = BackendURLStore.canonicalize("wss://api.example.com")
        XCTAssertNil(url)
    }

    func testCanonicalizeRejectsFTPScheme() {
        let url = BackendURLStore.canonicalize("ftp://api.example.com")
        XCTAssertNil(url)
    }

    func testCanonicalizeRejectsEmptyString() {
        XCTAssertNil(BackendURLStore.canonicalize(""))
        XCTAssertNil(BackendURLStore.canonicalize("   "))
    }

    func testCanonicalizeRejectsBareScheme() {
        XCTAssertNil(BackendURLStore.canonicalize("https://"))
    }

    func testCanonicalizeRejectsMissingScheme() {
        XCTAssertNil(BackendURLStore.canonicalize("api.example.com"))
    }

    func testCanonicalizeAcceptsHTTPLocalhostInDebug() {
        #if DEBUG
        let url = BackendURLStore.canonicalize("http://localhost:8000")
        XCTAssertEqual(url?.absoluteString, "http://localhost:8000")
        #else
        let url = BackendURLStore.canonicalize("http://localhost:8000")
        XCTAssertNil(url, "Release build must reject http:// (App Store ATS)")
        #endif
    }

    func testCanonicalizeAcceptsIPHostInDebug() {
        #if DEBUG
        let url = BackendURLStore.canonicalize("http://127.0.0.1:8000")
        XCTAssertEqual(url?.absoluteString, "http://127.0.0.1:8000")
        #else
        let url = BackendURLStore.canonicalize("http://127.0.0.1:8000")
        XCTAssertNil(url, "Release build must reject http:// (App Store ATS)")
        #endif
    }

    func testCanonicalizeRejectsHTTPNonLoopbackInDebug() {
        // http:// against a non-loopback host must be rejected even in
        // DEBUG builds — only localhost / 127.x / ::1 get the http exception.
        #if DEBUG
        XCTAssertNil(BackendURLStore.canonicalize("http://staging.example.com"))
        XCTAssertNil(BackendURLStore.canonicalize("http://192.168.1.1"))
        #endif
    }

    func testCanonicalizeAcceptsIPHostHTTPSInRelease() {
        let url = BackendURLStore.canonicalize("https://10.0.0.5:8443")
        XCTAssertEqual(url?.absoluteString, "https://10.0.0.5:8443")
    }

    // MARK: - override persistence

    func testFreshStoreWithNoOverrideReturnsBundledURL() {
        let store = BackendURLStore(userDefaults: defaults)
        XCTAssertEqual(store.currentEffectiveURL(), store.bundledBaseURL())
        XCTAssertFalse(store.hasOverride())
    }

    func testSaveOverridePersistsToUserDefaults() {
        let store = BackendURLStore(userDefaults: defaults)
        let override = URL(string: "https://api.example.com")!
        store.saveOverride(override)

        XCTAssertEqual(store.currentEffectiveURL(), override)
        XCTAssertTrue(store.hasOverride())
        XCTAssertEqual(
            defaults.string(forKey: BackendURLStore.userDefaultsKey),
            "https://api.example.com"
        )
    }

    func testClearOverrideRemovesPersistenceAndRevertsToBundled() {
        let store = BackendURLStore(userDefaults: defaults)
        let override = URL(string: "https://api.example.com")!
        store.saveOverride(override)
        store.clearOverride()

        XCTAssertEqual(store.currentEffectiveURL(), store.bundledBaseURL())
        XCTAssertFalse(store.hasOverride())
        XCTAssertNil(defaults.string(forKey: BackendURLStore.userDefaultsKey))
    }

    func testClearOverrideIsIdempotent() {
        let store = BackendURLStore(userDefaults: defaults)
        store.clearOverride()
        store.clearOverride()
        XCTAssertEqual(store.currentEffectiveURL(), store.bundledBaseURL())
    }

    func testInitLoadsValidPersistedOverride() {
        defaults.set("https://api.example.com", forKey: BackendURLStore.userDefaultsKey)
        let store = BackendURLStore(userDefaults: defaults)
        XCTAssertEqual(store.currentEffectiveURL().absoluteString, "https://api.example.com")
        XCTAssertTrue(store.hasOverride())
    }

    func testInitClearsCorruptPersistedOverride() {
        defaults.set("not a valid url with spaces", forKey: BackendURLStore.userDefaultsKey)
        let store = BackendURLStore(userDefaults: defaults)
        XCTAssertFalse(store.hasOverride())
        XCTAssertNil(defaults.string(forKey: BackendURLStore.userDefaultsKey))
        XCTAssertEqual(store.currentEffectiveURL(), store.bundledBaseURL())
    }

    func testInitClearsPersistedOverrideThatFailsCurrentPolicyRules() {
        defaults.set("https://api.example.com/api/v1", forKey: BackendURLStore.userDefaultsKey)
        let store = BackendURLStore(userDefaults: defaults)
        XCTAssertFalse(store.hasOverride())
        XCTAssertNil(defaults.string(forKey: BackendURLStore.userDefaultsKey))
    }

    func testSaveOverrideThenReinitReadsItBack() {
        let store1 = BackendURLStore(userDefaults: defaults)
        let override = URL(string: "https://api.example.com")!
        store1.saveOverride(override)

        let store2 = BackendURLStore(userDefaults: defaults)
        XCTAssertEqual(store2.currentEffectiveURL(), override)
        XCTAssertTrue(store2.hasOverride())
    }

    func testCurrentEffectiveURLReadableFromSendableContext() async {
        let store = BackendURLStore(userDefaults: defaults)
        let override = URL(string: "https://api.example.com")!
        store.saveOverride(override)

        let result: URL = await Task.detached(priority: .userInitiated) {
            return store.currentEffectiveURL()
        }.value

        XCTAssertEqual(result, override)
    }
}
