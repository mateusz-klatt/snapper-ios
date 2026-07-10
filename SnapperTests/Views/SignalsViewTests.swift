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
}
