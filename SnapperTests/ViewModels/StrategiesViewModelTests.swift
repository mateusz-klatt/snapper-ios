import XCTest
@testable import Snapper

private struct StrategiesUnexpectedError: Error {}

@MainActor
final class StrategiesViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() {
        mockAPI = nil
        super.tearDown()
    }

    private func makeViewModel() -> StrategiesViewModel {
        return StrategiesViewModel(api: mockAPI)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeStrategy(
        publicId: String,
        name: String = "strategy_macd_btc",
        running: Bool = true,
        enabled: Bool = true
    ) -> StrategyProcess {
        return StrategyProcess(
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            name: name,
            running: running,
            enabled: enabled,
            mode: "paper"
        )
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.strategies.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
    }

    func testLoadHappyPathPopulatesStrategies() async {
        let viewModel = makeViewModel()
        let strategy = makeStrategy(publicId: "s-1")
        mockAPI.fetchStrategiesHandler = { [strategy] }
        await viewModel.load()
        XCTAssertEqual(viewModel.strategies.count, 1)
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadFailureSetsTypedLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchStrategiesHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertTrue(viewModel.strategies.isEmpty)
        guard case .httpError(let code) = viewModel.loadError else {
            return XCTFail("Expected httpError, got \(String(describing: viewModel.loadError))")
        }
        XCTAssertEqual(code, 503)
    }

    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        let viewModel = makeViewModel()
        mockAPI.fetchStrategiesHandler = { throw StrategiesUnexpectedError() }
        await viewModel.load()
        guard case .invalidResponse = viewModel.loadError else {
            return XCTFail("Expected invalidResponse fallback, got \(String(describing: viewModel.loadError))")
        }
    }

    func testLoadClearsPreviousError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchStrategiesHandler = { throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.loadError)

        let strategy = makeStrategy(publicId: "s-1")
        mockAPI.fetchStrategiesHandler = { [strategy] }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.strategies.count, 1)
    }

    func testLoadFailurePreservesCachedData() async {
        let viewModel = makeViewModel()
        let strategy = makeStrategy(publicId: "s-1")
        mockAPI.fetchStrategiesHandler = { [strategy] }
        await viewModel.load()
        XCTAssertEqual(viewModel.strategies.count, 1)

        mockAPI.fetchStrategiesHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertEqual(viewModel.strategies.count, 1, "Cached list must survive a failed refresh")
        XCTAssertNotNil(viewModel.loadError)
    }

    func testSortedStrategiesAreNameOrdered() async {
        let viewModel = makeViewModel()
        let strategies = [
            makeStrategy(publicId: "s-z", name: "strategy_zeta"),
            makeStrategy(publicId: "s-a", name: "strategy_alpha"),
            makeStrategy(publicId: "s-m", name: "strategy_mike"),
        ]
        mockAPI.fetchStrategiesHandler = { strategies }
        await viewModel.load()
        XCTAssertEqual(
            viewModel.sortedStrategies.map(\.name),
            ["strategy_alpha", "strategy_mike", "strategy_zeta"]
        )
    }
}
