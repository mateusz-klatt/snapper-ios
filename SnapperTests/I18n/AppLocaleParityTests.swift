import XCTest
@testable import Snapper

/// Value-level parity between iOS ``AppLocale`` and the web v3
/// locale identity model at ``frontend/src/i18n/types.ts``. The
/// expected raw-value array is hardcoded from web ROW_1 + ROW_2 +
/// ROW_3 concatenated in order; updating one platform's set
/// without the other causes this test to fail on the next run.
///
/// Not a runtime cross-fetch — pure equality on a frozen array,
/// so the test is hermetic and fast.
final class AppLocaleParityTests: XCTestCase {

    private static let expectedOrder: [String] = [
        "ie", "us", "pl", "de", "fr", "es", "it", "nl", "br", "se",
        "no", "dk", "fi", "is", "gr",
        "cn", "hk", "jp", "kr", "th", "vn", "ph", "my", "id", "mm",
        "in", "bd", "ke", "ae", "il",
        "cz", "sk", "hu", "ro", "ua", "ru", "lt", "lv", "hr", "rs",
        "ba", "al", "tr", "ir", "am",
    ]

    private static let expectedRTL: [String] = ["ae", "il", "ir"]

    func testAllCasesMatchWebOrder() {
        XCTAssertEqual(AppLocale.allCases.map(\.rawValue), Self.expectedOrder)
    }

    func testRow1Order() {
        XCTAssertEqual(AppLocale.row1.map(\.rawValue), Array(Self.expectedOrder[0..<15]))
    }

    func testRow2Order() {
        XCTAssertEqual(AppLocale.row2.map(\.rawValue), Array(Self.expectedOrder[15..<30]))
    }

    func testRow3Order() {
        XCTAssertEqual(AppLocale.row3.map(\.rawValue), Array(Self.expectedOrder[30..<45]))
    }

    func testRTLSetMatchesWeb() {
        let rtl = AppLocale.allCases.filter(\.isRTL).map(\.rawValue).sorted()
        XCTAssertEqual(rtl, Self.expectedRTL.sorted())
    }
}
