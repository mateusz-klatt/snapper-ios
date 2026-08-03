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
            type: nil,
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            name: name,
            running: running,
            enabled: enabled,
            mode: "paper",
            strategyClass: nil,
            coordinator: nil,
            coordinatorLabel: nil,
            managedRemotely: nil
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

    private func makeWebSocketManager() -> WebSocketManager {
        return WebSocketManager(
            authService: FakeAuthService(nextToken: "t"),
            taskFactory: FakeWebSocketTaskFactory(task: FakeWebSocketTask()),
            sleeper: FakeSleeper()
        )
    }

    private func makeListEvent() -> StrategyListEventData {
        return StrategyListEventData(
            type: "strategy_list_event",
            sequenceId: 1,
            publicId: "sle-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            strategyClasses: ["MacdStrategy"],
            snapshotAt: Self.baseTimestamp
        )
    }

    /// A `strategy_list_event` arriving after the startup reconciliation
    /// settles triggers exactly one additional debounced ``load()``.
    func testLiveStrategyListEventTriggersOneReload() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = StrategiesReloadCounter()
        mockAPI.fetchStrategiesHandler = { await counter.increment(); return [] }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 500_000_000)
        let baseline = await counter.value
        manager.state.lastStrategyList = makeListEvent()
        try await Task.sleep(nanoseconds: 500_000_000)

        let after = await counter.value
        XCTAssertEqual(after, baseline + 1, "one strategy_list_event triggers exactly one reload")
        viewModel.stopObservingLiveUpdates(token: token)
    }

    /// Stopping observation before the debounce fires leaves no pending
    /// reload.
    func testStopLeavesNoPendingReload() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = StrategiesReloadCounter()
        mockAPI.fetchStrategiesHandler = { await counter.increment(); return [] }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 100_000_000)
        manager.state.lastStrategyList = makeListEvent()
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.stopObservingLiveUpdates(token: token)
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "stop before the debounce window must cancel the pending reload")
    }
}

private actor StrategiesReloadCounter {
    var value: Int = 0
    func increment() { value += 1 }
}
