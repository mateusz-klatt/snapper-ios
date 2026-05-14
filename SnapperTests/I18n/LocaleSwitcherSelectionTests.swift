import XCTest
@testable import Snapper

/// State-mutation tests that mirror what ``LocaleSwitcher``'s
/// ``onSelect`` closure does: assign ``appState.locale = code``
/// and verify the change persists to UserDefaults + cooperates
/// with ``LocaleEnvironmentResolver`` for RTL flips. Does NOT
/// render the SwiftUI body; the popover-dismiss flow is exercised
/// by manual Simulator smoke (per the repo pattern).
@MainActor
final class LocaleSwitcherSelectionTests: XCTestCase {

    private static let localeKey = "snapper-locale"

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "test.LocaleSwitcherSelectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testSelectingPLPersistsToDefaults() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { [] }
        )
        XCTAssertEqual(state.locale, .ie)
        state.locale = .pl
        XCTAssertEqual(defaults.string(forKey: Self.localeKey), "pl")
    }

    func testSelectingIcelandPersistsCorrectly() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { [] }
        )
        state.locale = .iceland
        XCTAssertEqual(defaults.string(forKey: Self.localeKey), "is")
    }

    func testSelectingRTLCodeChangesEnvironmentLayoutDirection() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { [] }
        )
        XCTAssertEqual(LocaleEnvironmentResolver.layoutDirection(for: state.locale), .leftToRight)
        state.locale = .ae
        XCTAssertEqual(LocaleEnvironmentResolver.layoutDirection(for: state.locale), .rightToLeft)
    }

    func testSelectingLTRCodeRestoresLeftToRight() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { [] }
        )
        state.locale = .ae
        XCTAssertEqual(LocaleEnvironmentResolver.layoutDirection(for: state.locale), .rightToLeft)
        state.locale = .ie
        XCTAssertEqual(LocaleEnvironmentResolver.layoutDirection(for: state.locale), .leftToRight)
    }

    func testSelectingSameCodeIsAHarmlessNoOp() {
        let defaults = makeIsolatedDefaults()
        let state = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { [] }
        )
        state.locale = .pl
        state.locale = .pl
        XCTAssertEqual(defaults.string(forKey: Self.localeKey), "pl")
        XCTAssertEqual(state.locale, .pl)
    }
}
