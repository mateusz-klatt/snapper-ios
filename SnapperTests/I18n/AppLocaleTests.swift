import XCTest
@testable import Snapper

/// Locks the structural invariants of ``AppLocale``: count, row
/// layout, RTL set, default, and the regional-indicator flag
/// emoji composition, including the raw ``is`` / ``in`` country
/// codes whose enum cases use non-keyword names.
final class AppLocaleTests: XCTestCase {

    func testCountIs45() {
        XCTAssertEqual(AppLocale.allCases.count, 45)
    }

    func testEachRowHas15Elements() {
        XCTAssertEqual(AppLocale.row1.count, 15)
        XCTAssertEqual(AppLocale.row2.count, 15)
        XCTAssertEqual(AppLocale.row3.count, 15)
    }

    func testRowsConcatenateToAllCases() {
        let combined = AppLocale.row1 + AppLocale.row2 + AppLocale.row3
        XCTAssertEqual(combined.count, 45)
        XCTAssertEqual(Set(combined).count, 45)
        XCTAssertEqual(combined.map(\.rawValue), AppLocale.allCases.map(\.rawValue))
    }

    func testDefaultLocaleIsIE() {
        XCTAssertEqual(AppLocale.defaultLocale, .ie)
    }

    func testIdentifiableIdMatchesRawValue() {
        XCTAssertEqual(AppLocale.pl.id, "pl")
        XCTAssertEqual(AppLocale.iceland.id, "is")
        XCTAssertEqual(AppLocale.india.id, "in")
    }

    func testRTLSetIsAeIlIr() {
        XCTAssertTrue(AppLocale.ae.isRTL)
        XCTAssertTrue(AppLocale.il.isRTL)
        XCTAssertTrue(AppLocale.ir.isRTL)
        XCTAssertFalse(AppLocale.us.isRTL)
        XCTAssertFalse(AppLocale.pl.isRTL)
        XCTAssertFalse(AppLocale.ie.isRTL)
        let rtl = AppLocale.allCases.filter(\.isRTL)
        XCTAssertEqual(rtl.count, 3)
    }

    func testFlagEmojiSampledCodes() {
        XCTAssertEqual(AppLocale.ie.flagEmoji, "🇮🇪")
        XCTAssertEqual(AppLocale.us.flagEmoji, "🇺🇸")
        XCTAssertEqual(AppLocale.pl.flagEmoji, "🇵🇱")
        XCTAssertEqual(AppLocale.de.flagEmoji, "🇩🇪")
        XCTAssertEqual(AppLocale.cn.flagEmoji, "🇨🇳")
        XCTAssertEqual(AppLocale.ae.flagEmoji, "🇦🇪")
    }

    /// Regression for the Swift-reserved-keyword ISO codes: both
    /// raw values resolve into the regional-indicator pair the same
    /// way as any other code.
    func testFlagEmojiKeywordRawValueCodes() {
        XCTAssertEqual(AppLocale.iceland.flagEmoji, "🇮🇸")
        XCTAssertEqual(AppLocale.india.flagEmoji, "🇮🇳")
    }
}
