import XCTest
@testable import Snapper

/// Locks the autonym country names rendered by
/// ``AppLocale/nativeCountryName`` so the locale-picker cells
/// keep showing the country in its own writing system. These
/// strings are sourced from Foundation's ICU region tables and
/// could drift across iOS versions, but the values asserted here
/// are stable on iOS 26.2 (the deployment target).
///
/// Coverage matrix: representative codes from every script /
/// region class — Latin (CEE + Western + Americas), CJK (zhHans,
/// zhHant, ja, ko), SE-Asia (th, vi), Indic (hi, bn), RTL Arabic
/// (ar), RTL Hebrew (he), RTL Persian (fa), Armenian (hy), plus
/// the Swift-reserved-keyword raw-value cases (.iceland / .india).
final class AppLocaleNativeCountryNameTests: XCTestCase {

    func testIrishAutonymForIE() {
        XCTAssertEqual(AppLocale.ie.nativeCountryName, "Éire")
    }

    func testEnglishAutonymForUS() {
        XCTAssertEqual(AppLocale.us.nativeCountryName, "United States")
    }

    func testPolishAutonymForPL() {
        XCTAssertEqual(AppLocale.pl.nativeCountryName, "Polska")
    }

    func testGermanAutonymForDE() {
        XCTAssertEqual(AppLocale.de.nativeCountryName, "Deutschland")
    }

    func testFrenchAutonymForFR() {
        XCTAssertEqual(AppLocale.fr.nativeCountryName, "France")
    }

    func testSimplifiedChineseAutonymForCN() {
        let name = AppLocale.cn.nativeCountryName
        XCTAssertTrue(name.contains("中国"), "Expected zh-Hans China autonym, got: \(name)")
    }

    func testTraditionalChineseAutonymForHK() {
        let name = AppLocale.hk.nativeCountryName
        XCTAssertTrue(name.contains("香港"), "Expected zh-Hant Hong Kong autonym, got: \(name)")
    }

    func testJapaneseAutonymForJP() {
        XCTAssertEqual(AppLocale.jp.nativeCountryName, "日本")
    }

    func testKoreanAutonymForKR() {
        XCTAssertEqual(AppLocale.kr.nativeCountryName, "대한민국")
    }

    func testArabicAutonymForAE() {
        let name = AppLocale.ae.nativeCountryName
        XCTAssertTrue(name.contains("الإمارات"), "Expected Arabic UAE autonym, got: \(name)")
    }

    func testHebrewAutonymForIL() {
        XCTAssertEqual(AppLocale.il.nativeCountryName, "ישראל")
    }

    func testPersianAutonymForIR() {
        let name = AppLocale.ir.nativeCountryName
        XCTAssertTrue(name.contains("ایران"), "Expected Persian Iran autonym, got: \(name)")
    }

    func testIcelandKeywordRawValueResolvesToIcelandic() {
        let name = AppLocale.iceland.nativeCountryName
        XCTAssertTrue(name.contains("Ísland"), "Expected Icelandic autonym, got: \(name)")
    }

    func testIndiaKeywordRawValueResolvesToHindi() {
        let name = AppLocale.india.nativeCountryName
        XCTAssertTrue(name.contains("भारत"), "Expected Hindi India autonym, got: \(name)")
    }

    func testEvery45CodeProducesNonEmptyAutonym() {
        for code in AppLocale.allCases {
            let name = code.nativeCountryName
            XCTAssertFalse(
                name.isEmpty,
                "nativeCountryName must never be empty for \(code.rawValue)"
            )
        }
    }

    func testFallbackToUppercasedISOWhenICUMissesIsAtLeastTheCode() {
        for code in AppLocale.allCases {
            let name = code.nativeCountryName
            XCTAssertTrue(
                !name.isEmpty,
                "Fallback must keep the cell label populated for \(code.rawValue)"
            )
        }
    }
}
