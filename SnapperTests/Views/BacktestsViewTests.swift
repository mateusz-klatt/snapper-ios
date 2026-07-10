import XCTest
@testable import Snapper

@MainActor
final class BacktestsViewTests: XCTestCase {

    func testShouldShowLoadErrorWhenEmptyAndLoadFailed() {
        XCTAssertTrue(BacktestsViewModel.shouldShowLoadError(count: 0, loadError: .httpError(503), isLoading: false))
    }

    func testShouldNotShowLoadErrorWhenListNonEmpty() {
        XCTAssertFalse(BacktestsViewModel.shouldShowLoadError(count: 2, loadError: .invalidResponse, isLoading: false))
    }

    func testShouldNotShowLoadErrorWhileLoading() {
        XCTAssertFalse(BacktestsViewModel.shouldShowLoadError(count: 0, loadError: .invalidResponse, isLoading: true))
    }

    func testShouldNotShowLoadErrorWhenNoError() {
        XCTAssertFalse(BacktestsViewModel.shouldShowLoadError(count: 0, loadError: nil, isLoading: false))
    }

    /// Every backend status maps to its tier; case-insensitive; an
    /// unexpected value falls to ``.unknown``.
    func testStatusTierMapping() {
        XCTAssertEqual(BacktestsViewModel.statusTier("pending"), .pending)
        XCTAssertEqual(BacktestsViewModel.statusTier("running"), .running)
        XCTAssertEqual(BacktestsViewModel.statusTier("COMPLETED"), .completed)
        XCTAssertEqual(BacktestsViewModel.statusTier("failed"), .failed)
        XCTAssertEqual(BacktestsViewModel.statusTier("cancelled"), .cancelled)
        XCTAssertEqual(BacktestsViewModel.statusTier("queued"), .unknown)
        XCTAssertEqual(BacktestsViewModel.statusTier(""), .unknown)
    }

    func testStatusTierLocalizationKeys() {
        XCTAssertEqual(BacktestStatusTier.pending.localizationKey, "backtests.status.pending")
        XCTAssertEqual(BacktestStatusTier.running.localizationKey, "backtests.status.running")
        XCTAssertEqual(BacktestStatusTier.completed.localizationKey, "backtests.status.completed")
        XCTAssertEqual(BacktestStatusTier.failed.localizationKey, "backtests.status.failed")
        XCTAssertEqual(BacktestStatusTier.cancelled.localizationKey, "backtests.status.cancelled")
        XCTAssertEqual(BacktestStatusTier.unknown.localizationKey, "backtests.status.unknown")
    }
}
