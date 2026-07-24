import XCTest
@testable import Snapper

@MainActor
final class SignalsViewTests: XCTestCase {

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSignal(
        publicId: String,
        side: String = "buy",
        strength: Double = 0.75,
        walletPublicId: String? = "wallet-1"
    ) -> TradingSignal {
        return SignalData(
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            instrument: "BTC-USD",
            exchange: "kraken",
            side: side,
            strength: strength,
            reason: "reason",
            price: 100.0,
            strategyName: "momentum",
            firedAt: Self.baseTimestamp,
            walletPublicId: walletPublicId
        )
    }

    func testWalletMatchesPolicyMirrorsPositionsView() {
        XCTAssertTrue(SignalsViewModel.walletMatches(rowWalletId: nil, selected: nil))
        XCTAssertTrue(SignalsViewModel.walletMatches(rowWalletId: nil, selected: "wallet-a"))
        XCTAssertTrue(SignalsViewModel.walletMatches(rowWalletId: "wallet-a", selected: nil))
        XCTAssertTrue(SignalsViewModel.walletMatches(rowWalletId: "wallet-a", selected: "wallet-a"))
        XCTAssertFalse(SignalsViewModel.walletMatches(rowWalletId: "wallet-b", selected: "wallet-a"))
    }

    func testFilterRespectsWalletScope() {
        let mine = makeSignal(publicId: "s-a", walletPublicId: "wallet-a")
        let other = makeSignal(publicId: "s-b", walletPublicId: "wallet-b")
        let orphan = makeSignal(publicId: "s-orphan", walletPublicId: nil)
        let scoped = SignalsViewModel.filter(
            signals: [mine, other, orphan],
            selectedWalletPublicId: "wallet-a"
        )
        XCTAssertEqual(Set(scoped.map(\.publicId)), Set(["s-a", "s-orphan"]))
    }

    func testFilterPassesThroughWhenNoWalletSelected() {
        let mine = makeSignal(publicId: "s-a", walletPublicId: "wallet-a")
        let other = makeSignal(publicId: "s-b", walletPublicId: "wallet-b")
        let unscoped = SignalsViewModel.filter(
            signals: [mine, other],
            selectedWalletPublicId: nil
        )
        XCTAssertEqual(unscoped.count, 2)
    }

    func testShouldShowLoadErrorWhenEmptyAndLoadFailed() {
        XCTAssertTrue(
            SignalsViewModel.shouldShowLoadError(
                filteredCount: 0,
                loadError: .httpError(503),
                isLoading: false
            )
        )
    }

    func testShouldNotShowLoadErrorWhenListNonEmpty() {
        XCTAssertFalse(
            SignalsViewModel.shouldShowLoadError(
                filteredCount: 4,
                loadError: .invalidResponse,
                isLoading: false
            )
        )
    }

    func testShouldNotShowLoadErrorWhileLoading() {
        XCTAssertFalse(
            SignalsViewModel.shouldShowLoadError(
                filteredCount: 0,
                loadError: .invalidResponse,
                isLoading: true
            )
        )
    }

    func testShouldNotShowLoadErrorWhenNoError() {
        XCTAssertFalse(
            SignalsViewModel.shouldShowLoadError(
                filteredCount: 0,
                loadError: nil,
                isLoading: false
            )
        )
    }

    func testSideClassificationIsCaseInsensitive() {
        XCTAssertTrue(SignalsViewModel.isBuy("buy"))
        XCTAssertTrue(SignalsViewModel.isBuy("BUY"))
        XCTAssertFalse(SignalsViewModel.isBuy("sell"))
        XCTAssertTrue(SignalsViewModel.isSell("sell"))
        XCTAssertTrue(SignalsViewModel.isSell("Sell"))
        XCTAssertFalse(SignalsViewModel.isSell("buy"))
    }

    /// The row badge resolves three ways: a malformed / unexpected side
    /// must fall to ``.other`` (neutral rendering) instead of being
    /// mislabelled as a sell, keeping the badge consistent with how the
    /// summary tiles count buys and sells.
    func testSideThreeWayClassificationFallsBackToOther() {
        XCTAssertEqual(SignalsViewModel.side(for: "buy"), .buy)
        XCTAssertEqual(SignalsViewModel.side(for: "SELL"), .sell)
        XCTAssertEqual(SignalsViewModel.side(for: "hold"), .other)
        XCTAssertEqual(SignalsViewModel.side(for: ""), .other)
    }

    func testStatsForEmptyListIsAllZero() {
        XCTAssertEqual(
            SignalsViewModel.stats(for: []),
            SignalStats(total: 0, buy: 0, sell: 0, averageStrength: 0.0)
        )
    }

    func testStatsCountsSidesAndAveragesStrength() {
        let signals = [
            makeSignal(publicId: "s-1", side: "buy", strength: 0.8),
            makeSignal(publicId: "s-2", side: "sell", strength: 0.6),
            makeSignal(publicId: "s-3", side: "buy", strength: 0.4),
        ]
        let stats = SignalsViewModel.stats(for: signals)
        XCTAssertEqual(stats.total, 3)
        XCTAssertEqual(stats.buy, 2)
        XCTAssertEqual(stats.sell, 1)
        XCTAssertEqual(stats.averageStrength, 0.6, accuracy: 0.0001)
    }

    /// Threshold boundaries mirror the web client exactly: 0.8 / 0.6 /
    /// 0.4 are inclusive lower bounds for strong / medium / weak.
    func testStrengthTierThresholds() {
        XCTAssertEqual(SignalsViewModel.strengthTier(1.0), .strong)
        XCTAssertEqual(SignalsViewModel.strengthTier(0.8), .strong)
        XCTAssertEqual(SignalsViewModel.strengthTier(0.79), .medium)
        XCTAssertEqual(SignalsViewModel.strengthTier(0.6), .medium)
        XCTAssertEqual(SignalsViewModel.strengthTier(0.59), .weak)
        XCTAssertEqual(SignalsViewModel.strengthTier(0.4), .weak)
        XCTAssertEqual(SignalsViewModel.strengthTier(0.39), .veryWeak)
        XCTAssertEqual(SignalsViewModel.strengthTier(0.0), .veryWeak)
    }

    func testStrengthTierLocalizationKeys() {
        XCTAssertEqual(SignalStrengthTier.strong.localizationKey, "signals.strength.strong")
        XCTAssertEqual(SignalStrengthTier.medium.localizationKey, "signals.strength.medium")
        XCTAssertEqual(SignalStrengthTier.weak.localizationKey, "signals.strength.weak")
        XCTAssertEqual(SignalStrengthTier.veryWeak.localizationKey, "signals.strength.veryWeak")
    }

    private func makeFullSignal(
        instrument: String = "BTC-USD",
        exchange: String = "kraken",
        side: String = "buy",
        strength: Double = 0.75,
        reason: String = "breakout",
        price: Double? = 100.0,
        strategyName: String? = "momentum"
    ) -> TradingSignal {
        return SignalData(
            sequenceId: 1,
            publicId: "s-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            instrument: instrument,
            exchange: exchange,
            side: side,
            strength: strength,
            reason: reason,
            price: price,
            strategyName: strategyName,
            firedAt: Self.baseTimestamp,
            walletPublicId: "wallet-1"
        )
    }

    /// ``nil`` selection admits every row; a named selection matches only
    /// an exact ``strategyName`` and never a ``nil`` / empty one.
    func testStrategyMatchesTruthTable() {
        XCTAssertTrue(SignalsViewModel.strategyMatches(strategyName: "momentum", selectedStrategy: nil))
        XCTAssertTrue(SignalsViewModel.strategyMatches(strategyName: nil, selectedStrategy: nil))
        XCTAssertTrue(SignalsViewModel.strategyMatches(strategyName: "momentum", selectedStrategy: "momentum"))
        XCTAssertFalse(SignalsViewModel.strategyMatches(strategyName: "reversion", selectedStrategy: "momentum"))
        XCTAssertFalse(SignalsViewModel.strategyMatches(strategyName: nil, selectedStrategy: "momentum"))
        XCTAssertFalse(SignalsViewModel.strategyMatches(strategyName: "", selectedStrategy: "momentum"))
    }

    func testApplyStrategyFilterNilSelectionPassesThrough() {
        let signals = [
            makeFullSignal(strategyName: "momentum"),
            makeFullSignal(strategyName: "reversion"),
        ]
        XCTAssertEqual(
            SignalsViewModel.applyStrategyFilter(signals, selectedStrategy: nil).count,
            2
        )
    }

    func testApplyStrategyFilterNamedKeepsOnlyMatching() {
        let momentum = makeFullSignal(strategyName: "momentum")
        let reversion = makeFullSignal(strategyName: "reversion")
        let orphan = makeFullSignal(strategyName: nil)
        let filtered = SignalsViewModel.applyStrategyFilter(
            [momentum, reversion, orphan],
            selectedStrategy: "momentum"
        )
        XCTAssertEqual(filtered.map(\.strategyName), ["momentum"])
    }

    /// A selection naming a strategy absent from the data yields an empty
    /// list, never a crash.
    func testApplyStrategyFilterAbsentStrategyIsEmpty() {
        let signals = [makeFullSignal(strategyName: "momentum")]
        XCTAssertTrue(
            SignalsViewModel.applyStrategyFilter(signals, selectedStrategy: "ghost").isEmpty
        )
    }

    /// Distinct names in first-appearance order, deduped, with ``nil`` and
    /// empty strategy names dropped.
    func testDistinctStrategiesOrderDedupeAndDropsNilEmpty() {
        let signals = [
            makeFullSignal(strategyName: "momentum"),
            makeFullSignal(strategyName: "reversion"),
            makeFullSignal(strategyName: "momentum"),
            makeFullSignal(strategyName: nil),
            makeFullSignal(strategyName: ""),
            makeFullSignal(strategyName: "breakout"),
        ]
        XCTAssertEqual(
            SignalsViewModel.distinctStrategies(from: signals),
            ["momentum", "reversion", "breakout"]
        )
    }

    func testDistinctStrategiesEmptyForNoNamedStrategies() {
        let signals = [
            makeFullSignal(strategyName: nil),
            makeFullSignal(strategyName: ""),
        ]
        XCTAssertTrue(SignalsViewModel.distinctStrategies(from: signals).isEmpty)
    }

    /// The filter control shows when options exist OR a selection is
    /// active. The options-empty-but-selection-active case is the one
    /// that keeps a retained selection clearable after a reload into
    /// rows with no named strategies.
    func testShouldShowStrategyFilterTruthTable() {
        XCTAssertFalse(SignalsViewModel.shouldShowStrategyFilter(hasStrategyOptions: false, hasSelection: false))
        XCTAssertTrue(SignalsViewModel.shouldShowStrategyFilter(hasStrategyOptions: true, hasSelection: false))
        XCTAssertTrue(SignalsViewModel.shouldShowStrategyFilter(hasStrategyOptions: false, hasSelection: true))
        XCTAssertTrue(SignalsViewModel.shouldShowStrategyFilter(hasStrategyOptions: true, hasSelection: true))
    }

    /// RFC-4180 escaping: quote only when a field carries a comma, double
    /// quote, CR, or LF; double any embedded quote; pass everything else
    /// (including non-ASCII) through unchanged.
    func testCsvFieldQuotingTruthTable() {
        XCTAssertEqual(SignalsViewModel.csvField("plain"), "plain")
        XCTAssertEqual(SignalsViewModel.csvField(""), "")
        XCTAssertEqual(SignalsViewModel.csvField("a,b"), "\"a,b\"")
        XCTAssertEqual(SignalsViewModel.csvField("a\"b"), "\"a\"\"b\"")
        XCTAssertEqual(SignalsViewModel.csvField("a\nb"), "\"a\nb\"")
        XCTAssertEqual(SignalsViewModel.csvField("a\rb"), "\"a\rb\"")
        XCTAssertEqual(SignalsViewModel.csvField("a,\"\nb"), "\"a,\"\"\nb\"")
        XCTAssertEqual(SignalsViewModel.csvField("héllo €"), "héllo €")
    }

    func testCsvHeaderStableColumnIds() {
        XCTAssertEqual(
            SignalsViewModel.csvHeader,
            ["instrument", "exchange", "side", "strength", "strategy", "price", "reason", "fired_at"]
        )
    }

    func testExportFilenameIsDeterministic() {
        XCTAssertEqual(SignalsViewModel.exportFilename, "signals.csv")
    }

    /// ISO-8601 UTC with millisecond precision and a ``Z`` suffix,
    /// matching the web export's ``toISOString()``.
    func testCsvTimestampIso8601Utc() {
        XCTAssertEqual(
            SignalsViewModel.csvTimestamp(Self.baseTimestamp),
            "2023-11-14T22:13:20.000Z"
        )
    }

    /// An empty signal set exports the header row alone, with no trailing
    /// record separator.
    func testCsvEmptySetIsHeaderOnly() {
        XCTAssertEqual(
            SignalsViewModel.csv(for: []),
            "instrument,exchange,side,strength,strategy,price,reason,fired_at"
        )
    }

    func testCsvSingleRowExactOutput() {
        let signal = makeFullSignal(reason: "breakout", price: 100.0, strategyName: "momentum")
        let expected = [
            "instrument,exchange,side,strength,strategy,price,reason,fired_at",
            "BTC-USD,kraken,buy,0.75,momentum,100.0,breakout,2023-11-14T22:13:20.000Z",
        ].joined(separator: "\r\n")
        XCTAssertEqual(SignalsViewModel.csv(for: [signal]), expected)
    }

    /// ``nil`` price and ``nil`` strategy both render as empty fields.
    func testCsvNilPriceAndStrategyBecomeEmptyFields() {
        let signal = makeFullSignal(price: nil, strategyName: nil)
        let line = SignalsViewModel.csv(for: [signal]).components(separatedBy: "\r\n")[1]
        XCTAssertEqual(line, "BTC-USD,kraken,buy,0.75,,,breakout,2023-11-14T22:13:20.000Z")
    }

    /// A reason containing a comma, quote, and newline is RFC-4180 quoted;
    /// non-ASCII content survives round-trip.
    func testCsvQuotesReasonWithSpecialCharsAndKeepsUnicode() {
        let signal = makeFullSignal(reason: "buy, \"now\"\nunité", strategyName: "momentum")
        let line = SignalsViewModel.csv(for: [signal]).components(separatedBy: "\r\n")[1]
        XCTAssertEqual(
            line,
            "BTC-USD,kraken,buy,0.75,momentum,100.0,\"buy, \"\"now\"\"\nunité\",2023-11-14T22:13:20.000Z"
        )
    }

    func testCsvMultipleRowsSeparatedByCrlf() {
        let signals = [
            makeFullSignal(instrument: "BTC-USD", strategyName: "momentum"),
            makeFullSignal(instrument: "ETH-USD", strategyName: "reversion"),
        ]
        let lines = SignalsViewModel.csv(for: signals).components(separatedBy: "\r\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[1].hasPrefix("BTC-USD,"))
        XCTAssertTrue(lines[2].hasPrefix("ETH-USD,"))
    }
}
