import SwiftUI
import XCTest
@testable import Snapper

@MainActor
final class AccountsViewTests: XCTestCase {

    private var appState: AppState!

    override func setUp() {
        super.setUp()
        let suiteName = "AccountsViewTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        appState = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["en-US"] }
        )
    }

    override func tearDown() {
        appState = nil
        super.tearDown()
    }

    func testNumberFormattingUsesTwoToEightFractionDigits() {
        XCTAssertEqual(AccountCard.formatNumber(12, locale: appState.locale), "12.00")
        XCTAssertEqual(AccountCard.formatNumber(12.123456789, locale: appState.locale), "12.12345679")
    }

    func testPnLFormattingShowsPlusOnlyForGain() {
        XCTAssertEqual(AccountCard.formatPnL(2.5, locale: appState.locale), "+2.50")
        XCTAssertEqual(AccountCard.formatPnL(0, locale: appState.locale), "0.00")
        XCTAssertEqual(AccountCard.formatPnL(-2.5, locale: appState.locale), "-2.50")
    }

    func testTimestampFormattingProducesLocalizedDateAndTime() {
        let formatted = AccountCard.formatTimestamp(
            Date(timeIntervalSince1970: 1_700_000_000),
            locale: appState.locale
        )

        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("2023"))
    }

    func testModeLabelLocalizesKnownValuesAndPassesUnknownThrough() {
        XCTAssertEqual(AccountCard.modeLabel("live", appState: appState), "Live")
        XCTAssertEqual(AccountCard.modeLabel("paper", appState: appState), "Paper")
        XCTAssertEqual(AccountCard.modeLabel("future_mode", appState: appState), "future_mode")
        XCTAssertEqual(AccountCard.modeLabel(nil, appState: appState), "N/A")
    }

    func testSideLabelLocalizesKnownValuesAndPassesUnknownThrough() {
        XCTAssertEqual(AccountCard.sideLabel("buy", appState: appState), "Buy")
        XCTAssertEqual(AccountCard.sideLabel("sell", appState: appState), "Sell")
        XCTAssertEqual(AccountCard.sideLabel("flat", appState: appState), "flat")
    }

    func testPnLColorHandlesGainLossAndZero() {
        XCTAssertEqual(AccountCard.pnlColor(1, appState: appState), Color.financialRising(for: appState))
        XCTAssertEqual(AccountCard.pnlColor(-1, appState: appState), Color.financialFalling(for: appState))
        XCTAssertEqual(AccountCard.pnlColor(0, appState: appState), Color.secondary)
    }

    func testTruthBannerAppearsForAnyNonAuthoritativeRow() {
        let live = AccountTruth(
            clientEffectiveStatus: "observed",
            isAuthoritative: true,
            authorityExpired: false,
            pollingStalled: false
        )
        let stale = AccountTruth(
            clientEffectiveStatus: "stale",
            isAuthoritative: false,
            authorityExpired: true,
            pollingStalled: false
        )

        XCTAssertFalse(AccountsView.shouldShowTruthBanner([]))
        XCTAssertFalse(AccountsView.shouldShowTruthBanner([live]))
        XCTAssertTrue(AccountsView.shouldShowTruthBanner([live, stale]))
    }
}
