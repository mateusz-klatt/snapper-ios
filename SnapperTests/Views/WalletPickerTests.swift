import XCTest
@testable import Snapper

@MainActor
final class WalletPickerTests: XCTestCase {

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    /// Construct a minimal ``WalletInfo`` for picker label assertions.
    /// Generated envelope fields (sequence_id, timestamp, session_id)
    /// are filled with placeholders — the picker only cares about
    /// ``publicId``, ``label`` and ``isPaper``.
    private func makeWallet(
        publicId: String,
        label: String,
        isPaper: Bool
    ) -> WalletInfo {
        return WalletInfo(
            type: "wallet_info",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            label: label,
            description: nil,
            isPaper: isPaper
        )
    }

    func testCurrentLabelDerivation() {
        let live = makeWallet(publicId: "p-1", label: "default", isPaper: false)
        let paper = makeWallet(publicId: "p-2", label: "default-paper", isPaper: true)

        XCTAssertEqual(
            WalletPickerViewModel.currentLabel(wallets: [], selected: nil),
            "Loading wallets..."
        )
        XCTAssertEqual(
            WalletPickerViewModel.currentLabel(wallets: [live, paper], selected: nil),
            "Select wallet"
        )
        XCTAssertEqual(
            WalletPickerViewModel.currentLabel(wallets: [live, paper], selected: "p-1"),
            "default"
        )
        XCTAssertEqual(
            WalletPickerViewModel.currentLabel(wallets: [live, paper], selected: "p-2"),
            "default-paper (paper)"
        )
        XCTAssertEqual(
            WalletPickerViewModel.currentLabel(wallets: [live, paper], selected: "missing"),
            "Select wallet",
            "Stale or invalid selection must fall back to the empty-selection prompt."
        )
    }

    func testWalletDisplayNamePaperSuffix() {
        let live = makeWallet(publicId: "p-3", label: "firm", isPaper: false)
        let paper = makeWallet(publicId: "p-4", label: "firm", isPaper: true)

        XCTAssertEqual(WalletPickerViewModel.walletDisplayName(live), "firm")
        XCTAssertEqual(
            WalletPickerViewModel.walletDisplayName(paper),
            "firm (paper)",
            "Paper wallets must surface the (paper) suffix to mirror backend (label, is_paper) disambiguation."
        )
    }

    /// Surface-load-errors branch (PR #2): when the wallet fetch
    /// fails before any wallet is cached, the menu opens to a
    /// "couldn't load" prompt with retry instead of an empty
    /// list of selectable rows.
    func testShouldShowLoadErrorWhenEmptyAndFailed() {
        XCTAssertTrue(
            WalletPickerViewModel.shouldShowLoadError(
                wallets: [],
                loadError: .invalidResponse
            )
        )
    }

    /// Cached wallets keep the menu functional even after a refresh
    /// blip — the picker stays usable and the next successful load
    /// clears the error.
    func testShouldNotShowLoadErrorWhenWalletsCached() {
        let cached = makeWallet(publicId: "p-cache", label: "main", isPaper: false)
        XCTAssertFalse(
            WalletPickerViewModel.shouldShowLoadError(
                wallets: [cached],
                loadError: .httpError(503)
            )
        )
    }

    func testShouldNotShowLoadErrorWhenNoError() {
        XCTAssertFalse(
            WalletPickerViewModel.shouldShowLoadError(
                wallets: [],
                loadError: nil
            )
        )
    }

    /// Toolbar capsule label — the failure mode label collapses to
    /// a short prompt so the user sees an actionable signal instead
    /// of a stuck "Loading wallets…" string after the fetch settled
    /// with an error.
    func testCurrentLabelFallsBackToWalletsUnavailableOnError() {
        XCTAssertEqual(
            WalletPickerViewModel.currentLabel(
                wallets: [],
                selected: nil,
                loadError: .httpError(503)
            ),
            "Wallets unavailable"
        )
    }
}
