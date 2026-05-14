import XCTest
@testable import Snapper

/// Locale-specific tests for ``AppState``. The existing
/// ``AppStateTests`` (wallet selection) stays untouched and
/// continues to validate the signature with default
/// ``preferredLanguagesProvider``.
@MainActor
final class AppStateLocaleTests: XCTestCase {

    private static let localeKey = "snapper-locale"

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "test.AppStateLocaleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testEmptyDefaultsEmptyPreferredFallsBackToIE() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { [] }
        )
        XCTAssertEqual(state.locale, .ie)
    }

    func testEmptyDefaultsPLPreferredResolvesToPL() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["pl-PL"] }
        )
        XCTAssertEqual(state.locale, .pl)
    }

    func testStoredValueTakesPrecedence() {
        let defaults = makeIsolatedDefaults()
        defaults.set("pl", forKey: Self.localeKey)
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["en-US"] }
        )
        XCTAssertEqual(state.locale, .pl)
    }

    func testInvalidStoredValueFallsThroughToPreferredLanguages() {
        let defaults = makeIsolatedDefaults()
        defaults.set("xx", forKey: Self.localeKey)
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["pl-PL"] }
        )
        XCTAssertEqual(state.locale, .pl)
    }

    func testSettingLocalePersistsToDefaults() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { [] }
        )
        state.locale = .pl
        XCTAssertEqual(defaults.string(forKey: Self.localeKey), "pl")
    }

    func testRoundTripPersistence() {
        let defaults = makeIsolatedDefaults()
        let writer = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { [] }
        )
        writer.locale = .pl
        writer.locale = .ie
        XCTAssertEqual(defaults.string(forKey: Self.localeKey), "ie")
        let reader = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["en-US"] }
        )
        XCTAssertEqual(reader.locale, .ie)
    }

    func testIcelandCodePersistsCorrectly() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { [] }
        )
        state.locale = .iceland
        XCTAssertEqual(defaults.string(forKey: Self.localeKey), "is")
    }

    func testIndiaCodePersistsCorrectly() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { [] }
        )
        state.locale = .india
        XCTAssertEqual(defaults.string(forKey: Self.localeKey), "in")
    }

    func testDefaultInitSignatureStillWorks() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(userDefaults: defaults)
        XCTAssertNotNil(state.locale)
    }
}
