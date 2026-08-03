import XCTest
@testable import Snapper

private struct BacktestsUnexpectedError: Error {}

@MainActor
final class BacktestsViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() {
        mockAPI = nil
        super.tearDown()
    }

    private func makeViewModel() -> BacktestsViewModel {
        return BacktestsViewModel(api: mockAPI)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeBacktest(
        publicId: String,
        status: String = "completed"
    ) -> BacktestRunData {
        return BacktestRunData(
            type: nil,
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            walletPublicId: "wallet-1",
            strategyName: "momentum",
            strategyParams: nil,
            instrumentPublicId: "inst-1",
            instrument: "BTC-USD",
            exchange: "kraken",
            timeframe: "1h",
            startDate: Self.baseTimestamp,
            endDate: Self.baseTimestamp,
            initialCash: 10_000,
            status: status,
            executionMode: nil,
            fillModel: nil,
            slippageBps: nil,
            commissionBps: nil,
            configHash: nil,
            targetExecutionExchange: nil,
            startedAt: nil,
            completedAt: nil,
            error: nil
        )
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.backtests.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
    }

    func testLoadHappyPathPopulatesBacktests() async {
        let viewModel = makeViewModel()
        let run = makeBacktest(publicId: "b-1")
        mockAPI.fetchBacktestsHandler = { [run] }
        await viewModel.load()
        XCTAssertEqual(viewModel.backtests.count, 1)
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadFailureSetsTypedLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchBacktestsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertTrue(viewModel.backtests.isEmpty)
        guard case .httpError(let code) = viewModel.loadError else {
            return XCTFail("Expected httpError, got \(String(describing: viewModel.loadError))")
        }
        XCTAssertEqual(code, 503)
    }

    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        let viewModel = makeViewModel()
        mockAPI.fetchBacktestsHandler = { throw BacktestsUnexpectedError() }
        await viewModel.load()
        guard case .invalidResponse = viewModel.loadError else {
            return XCTFail("Expected invalidResponse fallback, got \(String(describing: viewModel.loadError))")
        }
    }

    func testLoadClearsPreviousError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchBacktestsHandler = { throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.loadError)

        let run = makeBacktest(publicId: "b-1")
        mockAPI.fetchBacktestsHandler = { [run] }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.backtests.count, 1)
    }

    /// A failed refresh keeps the cached list and records the error;
    /// ``shouldShowLoadError`` then suppresses the full-screen error.
    func testLoadFailurePreservesCachedData() async {
        let viewModel = makeViewModel()
        let run = makeBacktest(publicId: "b-1")
        mockAPI.fetchBacktestsHandler = { [run] }
        await viewModel.load()
        XCTAssertEqual(viewModel.backtests.count, 1)

        mockAPI.fetchBacktestsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertEqual(viewModel.backtests.count, 1, "Cached list must survive a failed refresh")
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertFalse(
            BacktestsViewModel.shouldShowLoadError(
                count: viewModel.backtests.count,
                loadError: viewModel.loadError,
                isLoading: viewModel.isLoading
            )
        )
    }
}
