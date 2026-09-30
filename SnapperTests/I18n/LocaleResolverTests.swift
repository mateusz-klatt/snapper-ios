import XCTest
@testable import Snapper

/// Unit tests for ``LocaleResolver`` preference parsing and stored
/// selection precedence. Language cases use literal tag arrays;
/// persistence cases use isolated UserDefaults suites.
final class LocaleResolverTests: XCTestCase {

    func testEmptyArrayResolvesToDefault() {
        XCTAssertEqual(LocaleResolver.resolveFromPreferredLanguages([]), .ie)
    }

    func testFirstSupportedLanguageWins_PLBeforeUS() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["pl-PL", "en-US"]),
            .pl
        )
    }

    func testFirstSupportedLanguageWins_USBeforePL() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["en-US", "pl-PL"]),
            .us
        )
    }

    func testUnsupportedRegionPreservesSupportedLanguage() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["en-GB"]),
            .us
        )
    }

    func testChineseLanguageScriptAndRegionResolveTogether() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["zh-Hans-CN"]),
            .cn
        )
    }

    func testUnsupportedLanguageFallsThroughToDefault() {
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

    func testCountryDoesNotReplaceRequestedLanguage() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["en-PL"]),
            .us
        )
    }

    func testLanguageOnlyPreferencesDoNotBecomeCountryCodes() {
        let cases: [(String, AppLocale)] = [
            ("en", .us), ("ga", .ie), ("my", .mm), ("ms", .my),
            ("ja", .jp), ("ar", .ae), ("he", .il), ("hi", .india),
            ("fil", .ph), ("sw", .ke), ("uk", .ua), ("el", .gr)
        ]
        for (tag, expected) in cases {
            XCTAssertEqual(LocaleResolver.resolveFromPreferredLanguages([tag]), expected, tag)
        }
    }

    func testChineseExplicitScriptWinsOverRegionAndRegionSuppliesMissingScript() {
        let cases: [(String, AppLocale)] = [
            ("zh", .cn), ("zh-Hant", .hk), ("zh-Hans", .cn),
            ("zh-Hant-TW", .hk), ("zh-TW", .hk), ("zh-HK", .hk),
            ("zh-MO", .hk), ("zh-Hans-HK", .cn), ("zh-Hant-CN", .hk)
        ]
        for (tag, expected) in cases {
            XCTAssertEqual(LocaleResolver.resolveFromPreferredLanguages([tag]), expected, tag)
        }
    }

    func testAvailableVariantsAndLegacyAliasesResolveConsistently() {
        let cases: [(String, AppLocale)] = [
            ("pt", .br), ("pt-PT", .br), ("no", .no), ("nb-NO", .no),
            ("sr", .rs), ("sr-Latn", .rs), ("sr-Cyrl", .rs),
            ("iw-IL", .il), ("in-ID", .id), ("tl-PH", .ph), ("EN-gb", .us)
        ]
        for (tag, expected) in cases {
            XCTAssertEqual(LocaleResolver.resolveFromPreferredLanguages([tag]), expected, tag)
        }
    }

    func testEveryCatalogLanguageResolvesToItsOwnCatalog() {
        for language in CatalogLanguage.allCases {
            let resolved = LocaleResolver.resolveFromPreferredLanguages([language.rawValue])
            XCTAssertEqual(resolved.catalogLanguage, language, language.rawValue)
        }
    }

    func testUnsupportedLanguageDoesNotSelectItsRegionBeforeNextPreference() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["nn-NO", "xx-PL", "ja-JP", "en-US"]),
            .jp
        )
    }

    func testExtensionsAndMalformedSeparatorsDoNotSelectAnotherCountry() {
        XCTAssertEqual(LocaleResolver.resolveFromPreferredLanguages(["en-u-rg-plzzzz"]), .us)
        XCTAssertEqual(LocaleResolver.resolveFromPreferredLanguages(["en-x-pl"]), .us)
        XCTAssertEqual(LocaleResolver.resolveFromPreferredLanguages(["pl--PL", "ja"]), .jp)
        XCTAssertEqual(LocaleResolver.resolveFromPreferredLanguages(["", "ar"]), .ae)
    }

    func testIcelandResolvesFromTag() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["is-IS"]),
            .iceland
        )
    }

    func testIndiaResolvesFromTag() {
        XCTAssertEqual(
            LocaleResolver.resolveFromPreferredLanguages(["hi-IN"]),
            .india
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
