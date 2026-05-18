import XCTest
@testable import Snapper

/// Tests for the locale-default → effective-convention resolver.
final class FinancialColorPreferenceTests: XCTestCase {

    func testAutoFlipForChineseLocaleResolvesToRisingRed() {
        XCTAssertEqual(
            resolveFinancialColorConvention(preference: .auto, locale: .cn),
            .risingRed
        )
        XCTAssertEqual(
            resolveFinancialColorConvention(preference: .auto, locale: .hk),
            .risingRed
        )
        XCTAssertEqual(
            resolveFinancialColorConvention(preference: .auto, locale: .jp),
            .risingRed
        )
        XCTAssertEqual(
            resolveFinancialColorConvention(preference: .auto, locale: .kr),
            .risingRed
        )
    }

    func testAutoStaysGreenForWesternLocales() {
        for locale in AppLocale.allCases where !autoRisingRedLocales.contains(locale) {
            XCTAssertEqual(
                resolveFinancialColorConvention(preference: .auto, locale: locale),
                .risingGreen,
                "Locale \(locale.rawValue) should default to rising-green"
            )
        }
    }

    func testExplicitRisingRedWinsOverWesternLocale() {
        XCTAssertEqual(
            resolveFinancialColorConvention(preference: .risingRed, locale: .us),
            .risingRed
        )
        XCTAssertEqual(
            resolveFinancialColorConvention(preference: .risingRed, locale: .pl),
            .risingRed
        )
    }

    func testExplicitRisingGreenWinsOverAsianLocale() {
        XCTAssertEqual(
            resolveFinancialColorConvention(preference: .risingGreen, locale: .cn),
            .risingGreen
        )
        XCTAssertEqual(
            resolveFinancialColorConvention(preference: .risingGreen, locale: .jp),
            .risingGreen
        )
    }

    func testAutoRisingRedLocalesIsTheCanonicalFourSet() {
        XCTAssertEqual(autoRisingRedLocales.count, 4)
        XCTAssertTrue(autoRisingRedLocales.contains(.cn))
        XCTAssertTrue(autoRisingRedLocales.contains(.hk))
        XCTAssertTrue(autoRisingRedLocales.contains(.jp))
        XCTAssertTrue(autoRisingRedLocales.contains(.kr))
    }

    func testStorageKeyMatchesWebContract() {
        XCTAssertEqual(financialColorPreferenceStorageKey, "snapper-financial-color-preference")
    }

    func testEnumRawValuesMatchWebContract() {
        XCTAssertEqual(FinancialColorPreference.auto.rawValue, "auto")
        XCTAssertEqual(FinancialColorPreference.risingRed.rawValue, "rising-red")
        XCTAssertEqual(FinancialColorPreference.risingGreen.rawValue, "rising-green")
    }
}
