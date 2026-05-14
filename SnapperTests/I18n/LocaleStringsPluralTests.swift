import XCTest
@testable import Snapper

/// Covers ``LocaleStrings.localizedPlural(_:count:in:)`` — the
/// bundle-backed plural lookup. Currently exercises the fallback path
/// (key returned when no plural variation is found). Once Phase B.2
/// adds plural keys (``home.openPositions.count`` etc) to the catalog,
/// additional table-driven boundary tests covering PL CLDR cases
/// (n=1, n=2, n=12/13/14 boundary, n=22, n=25) activate against the
/// real compiled ``.xcstrings`` bundle.
final class LocaleStringsPluralTests: XCTestCase {

    func testMissingKeyReturnsKey() {
        let result = LocaleStrings.localizedPlural(
            "nonexistent.plural.key",
            count: 5,
            in: .en
        )
        XCTAssertEqual(result, "nonexistent.plural.key")
    }

    func testMissingKeyReturnsKeyForPolish() {
        let result = LocaleStrings.localizedPlural(
            "another.missing.key",
            count: 12,
            in: .pl
        )
        XCTAssertEqual(result, "another.missing.key")
    }

    func testZeroCountStillReturnsKeyOnMiss() {
        let result = LocaleStrings.localizedPlural(
            "yet.another.missing",
            count: 0,
            in: .en
        )
        XCTAssertEqual(result, "yet.another.missing")
    }

    func testNegativeCountStillReturnsKeyOnMiss() {
        let result = LocaleStrings.localizedPlural(
            "negative.count.miss",
            count: -1,
            in: .pl
        )
        XCTAssertEqual(result, "negative.count.miss")
    }
}
