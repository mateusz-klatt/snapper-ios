import XCTest
@testable import Snapper

/// Covers ``LocaleStrings.localizedRawValue(_:namespace:in:)`` — the
/// raw-String table lookup used by ``NotificationPrefsViewModel`` etc
/// for API-rawValue display values.
final class LocaleStringsRawValueLookupTests: XCTestCase {

    func testReturnsRawValueWhenKeyMissingFromCatalog() {
        let result = LocaleStrings.localizedRawValue(
            "nonexistent_raw_value",
            namespace: "test.missing.namespace",
            in: .en
        )
        XCTAssertEqual(result, "nonexistent_raw_value")
    }

    func testReturnsRawValueWhenNamespaceMissingFromCatalog() {
        let result = LocaleStrings.localizedRawValue(
            "buy",
            namespace: "definitely.not.a.real.namespace",
            in: .pl
        )
        XCTAssertEqual(result, "buy")
    }

    func testRawValueWithSnakeCasePreserved() {
        let result = LocaleStrings.localizedRawValue(
            "order_fill_full",
            namespace: "test.missing.namespace",
            in: .en
        )
        XCTAssertEqual(result, "order_fill_full")
    }

    func testRawValueWithSnakeCasePreservedForPL() {
        let result = LocaleStrings.localizedRawValue(
            "critical_system_error",
            namespace: "test.missing.namespace",
            in: .pl
        )
        XCTAssertEqual(result, "critical_system_error")
    }
}
