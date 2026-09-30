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
            "BUY 100 BTCUSD @ 50000.00 filled on Kraken"
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

    func testCurrencyQualifiedFillPreservesPrecisionAndDoesNotInventDollars() {
        let result = LocaleStrings.render(
            "alerts.body.order_fill_full_quoted",
            in: .en,
            args: ["SELL", "0.125", "ETHBTC", "0.000012345678 BTC", "Kraken"]
        )
        XCTAssertEqual(result, "SELL 0.125 ETHBTC @ 0.000012345678 BTC filled on Kraken")
        XCTAssertFalse(result.contains("$"))
    }

    func testQuotedFillRendersCurrencyAndLocalizedSideInEveryCatalogLanguage() {
        for language in CatalogLanguage.allCases {
            let result = LocaleStrings.render(
                "alerts.body.order_fill_full_quoted",
                in: language,
                args: ["SELL", "0.125", "ETHBTC", "0.000012345678 BTC", "Kraken"]
            )
            let side = LocaleStrings.localized("alerts.argument.side.sell", in: language)
            XCTAssertNotEqual(side, "alerts.argument.side.sell", language.rawValue)
            XCTAssertTrue(result.contains(side), language.rawValue)
            XCTAssertTrue(result.contains("0.000012345678 BTC"), language.rawValue)
            XCTAssertTrue(result.contains("ETHBTC"), language.rawValue)
            XCTAssertTrue(result.contains("Kraken"), language.rawValue)
            XCTAssertFalse(result.contains("$"), language.rawValue)
            XCTAssertFalse(result.contains("%@"), language.rawValue)
        }
    }

    func testKnownSideTokensLocalizeForEachOrderBody() {
        let keys = [
            "alerts.body.order_fill_full", "alerts.body.order_fill_full_quoted",
            "alerts.body.order_rejected", "alerts.body.margin_warning",
            "alerts.body.order_unknown", "alerts.body.order_unknown_unresolved"
        ]
        let translatedSide = LocaleStrings.localized("alerts.argument.side.buy", in: .pl)
        XCTAssertNotEqual(translatedSide, "alerts.argument.side.buy")
        for key in keys {
            let args = key.contains("order_fill_full")
                ? ["bUy", "1", "BTCPLN", "12.345 PLN", "Kraken"]
                : ["bUy", "1", "BTCPLN", "venue reason"]
            let result = LocaleStrings.render(key, in: .pl, args: args)
            XCTAssertTrue(result.contains(translatedSide), key)
            XCTAssertFalse(result.contains("bUy"), key)
        }
    }

    func testKnownFallbackReasonsLocalizeWithoutChangingWireArguments() {
        let keys = [
            "alerts.body.order_rejected", "alerts.body.margin_warning",
            "alerts.body.order_unknown", "alerts.body.order_unknown_unresolved"
        ]
        let reasons = [
            ("Unknown Reason", "alerts.argument.reason.unknown"),
            ("AMBIGUOUS VENUE RESPONSE", "alerts.argument.reason.ambiguous")
        ]
        for key in keys {
            for (reason, argumentKey) in reasons {
                let args = ["SELL", "1", "BTCPLN", reason]
                let result = LocaleStrings.render(key, in: .pl, args: args)
                let expected = LocaleStrings.localized(argumentKey, in: .pl)
                XCTAssertNotEqual(expected, argumentKey)
                XCTAssertTrue(result.contains(expected), key)
                XCTAssertFalse(result.contains(reason), key)
                XCTAssertEqual(args[0], "SELL")
                XCTAssertEqual(args[3], reason)
            }
        }
    }

    func testUnknownTokensAndFreeformVenueReasonsRemainVerbatim() {
        let reason = "BUY warning: unknown reason supplied by venue"
        let result = LocaleStrings.render(
            "alerts.body.order_rejected",
            in: .pl,
            args: ["HOLD", "1", "BTCPLN", reason]
        )
        XCTAssertTrue(result.contains("HOLD"))
        XCTAssertTrue(result.contains(reason))
    }

    func testCriticalStatusLocalizesOnlyTheStatusArgument() {
        for status in ["HEALTHY", "Warning", "error"] {
            let result = LocaleStrings.render(
                "alerts.body.critical_system_error",
                in: .pl,
                args: ["BUY", "unknown reason", status, "3"]
            )
            let argumentKey = "alerts.argument.status.\(status.lowercased())"
            let expected = LocaleStrings.localized(argumentKey, in: .pl)
            XCTAssertNotEqual(expected, argumentKey)
            XCTAssertTrue(result.contains(expected))
            XCTAssertTrue(result.contains("BUY/unknown reason"))
            XCTAssertTrue(result.contains("3"))
        }
    }

    func testUnresolvedOrderKeepsTheSafetyWarning() {
        for key in ["alerts.body.order_unknown", "alerts.body.order_unknown_unresolved"] {
            let result = LocaleStrings.render(
                key,
                in: .en,
                args: ["BUY", "1", "BTCPLN", "ambiguous venue response"]
            )
            XCTAssertTrue(result.contains("do not assume the position is closed"), key)
            XCTAssertFalse(result.contains("%@"), key)
        }
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
