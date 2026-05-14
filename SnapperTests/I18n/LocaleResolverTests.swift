import XCTest
@testable import Snapper

/// Pure-function unit tests for ``LocaleResolver``. No UserDefaults,
/// no AppState construction — exercises ``resolveFromPreferredLanguages``
/// directly with literal tag arrays.
final class LocaleResolverTests: XCTestCase {

    func testEmptyArrayResolvesToDefault() {
        XCTAssertEqual(LocaleResolver.resolveFromPreferredLanguages([]), .ie)
    }

    func testFirstValidRegionWins_PLBeforeUS() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["pl-PL", "en-US"]),
            .pl
        )
    }

    func testFirstValidRegionWins_USBeforePL() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["en-US", "pl-PL"]),
            .us
        )
    }

    func testUnsupportedRegionFallsThroughToDefault() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["en-GB"]),
            .ie
        )
    }

    func testThreePartTagWalksRegionInReverse() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["zh-Hans-CN"]),
            .cn
        )
    }

    func testNoValidRegionInTagFallsThrough() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["xx-YY"]),
            .ie
        )
    }

    func testUnderscoreSeparatorIsSupported() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["en_US"]),
            .us
        )
    }

    func testUppercasedRegionStillResolves() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["en-PL"]),
            .pl
        )
    }

    func testBacktickedISResolvesFromTag() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["is-IS"]),
            .`is`
        )
    }

    func testBacktickedINResolvesFromTag() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["hi-IN"]),
            .`in`
        )
    }

    func testStoredValueTakesPrecedenceOverPreferredLanguages() {
        let suite = "test.LocaleResolverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("pl", forKey: "snapper-locale")
        XCTAssertEqual(
            LocaleResolver.resolveInitialLocale(
                userDefaults: defaults,
                preferredLanguages: ["en-US"],
                localeKey: "snapper-locale"
            ),
            .pl
        )
    }

    func testInvalidStoredValueFallsThroughToPreferredLanguages() {
        let suite = "test.LocaleResolverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("xx", forKey: "snapper-locale")
        XCTAssertEqual(
            LocaleResolver.resolveInitialLocale(
                userDefaults: defaults,
                preferredLanguages: ["pl-PL"],
                localeKey: "snapper-locale"
            ),
            .pl
        )
    }

    func testEmptyDefaultsEmptyPreferredFallsThroughToDefault() {
        let suite = "test.LocaleResolverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        XCTAssertEqual(
            LocaleResolver.resolveInitialLocale(
                userDefaults: defaults,
                preferredLanguages: [],
                localeKey: "snapper-locale"
            ),
            .ie
        )
    }
}
