import XCTest
@testable import Snapper

@MainActor
final class StrategiesViewTests: XCTestCase {

    func testShouldShowLoadErrorWhenEmptyAndLoadFailed() {
        XCTAssertTrue(StrategiesViewModel.shouldShowLoadError(count: 0, loadError: .httpError(503), isLoading: false))
    }

    func testShouldNotShowLoadErrorWhenListNonEmpty() {
        XCTAssertFalse(StrategiesViewModel.shouldShowLoadError(count: 2, loadError: .invalidResponse, isLoading: false))
    }

    func testShouldNotShowLoadErrorWhileLoading() {
        XCTAssertFalse(StrategiesViewModel.shouldShowLoadError(count: 0, loadError: .invalidResponse, isLoading: true))
    }

    func testShouldNotShowLoadErrorWhenNoError() {
        XCTAssertFalse(StrategiesViewModel.shouldShowLoadError(count: 0, loadError: nil, isLoading: false))
    }

    func testRunningLabelKey() {
        XCTAssertEqual(StrategiesViewModel.runningLabelKey(true), "strategies.status.running")
        XCTAssertEqual(StrategiesViewModel.runningLabelKey(false), "strategies.status.stopped")
    }

    /// The display name drops a ``strategy_`` prefix and upper-cases each
    /// underscore segment; names without the prefix are still segmented,
    /// and a would-be-empty result falls back to the raw name.
    func testDisplayName() {
        XCTAssertEqual(StrategiesViewModel.displayName(for: "strategy_macd_btc"), "MACD BTC")
        XCTAssertEqual(StrategiesViewModel.displayName(for: "macd_rsi"), "MACD RSI")
        XCTAssertEqual(StrategiesViewModel.displayName(for: "simple"), "SIMPLE")
        XCTAssertEqual(StrategiesViewModel.displayName(for: "strategy_"), "strategy_")
    }
}
