import XCTest
@testable import Snapper

/// Tests for ``LocaleStrings.render`` — Phase D in-app alert
/// re-localization (catalog lookup + positional arg substitution).
final class LocaleStringsRenderTests: XCTestCase {

    func testEnglishRenderSubstitutesPositionalArgs() {
        let result = LocaleStrings.render(
            "alerts.body.order_fill_full",
            in: .en,
            args: ["BUY", "100", "BTCUSD", "50000.00", "Kraken"]
        )
        XCTAssertEqual(
            result,
            "BUY 100 BTCUSD @ $50000.00 filled on Kraken"
        )
    }

    func testPolishRenderUsesPolishTemplate() {
        let result = LocaleStrings.render(
            "alerts.body.order_fill_full",
            in: .pl,
            args: ["BUY", "100", "BTCUSD", "50000.00", "Kraken"]
        )
        XCTAssertTrue(result.contains("zrealizowane na Kraken"))
        XCTAssertFalse(result.contains("%@"))
    }

    /// ``%lld`` in the xcstrings ``critical_system_error`` body
    /// template must be normalized to ``%@`` so a wire-shape
    /// ``String`` arg can substitute without ``String(format:)`` ever
    /// being asked to interpret the string pointer as ``long long``.
    func testLLDPlaceholderNormalizesToStringFormat() {
        let result = LocaleStrings.render(
            "alerts.body.critical_system_error",
            in: .en,
            args: ["executor", "kraken", "warning", "3"]
        )
        XCTAssertTrue(result.contains("3"))
        XCTAssertFalse(result.contains("%lld"))
        XCTAssertFalse(result.contains("%@"))
    }

    func testEmptyArgsListReturnsRawTemplate() {
        let result = LocaleStrings.render(
            "alerts.title.order_fill_full",
            in: .en,
            args: []
        )
        XCTAssertEqual(result, "Order filled")
    }

    /// Catalog miss should round-trip the key so the caller can
    /// detect (key == result) and fall back to the server-rendered
    /// ``alert.title``/``body``.
    func testCatalogMissReturnsKeyAsSignal() {
        let result = LocaleStrings.render(
            "alerts.title.does_not_exist",
            in: .pl,
            args: []
        )
        XCTAssertEqual(result, "alerts.title.does_not_exist")
    }
}
