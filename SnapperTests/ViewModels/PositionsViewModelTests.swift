import XCTest
@testable import Snapper

@MainActor
final class PositionsViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
        let suiteName = "PositionsViewModelTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        appState = AppState(userDefaults: userDefaults)
    }

    override func tearDown() {
        mockAPI = nil
        appState = nil
        super.tearDown()
    }

    private func makeViewModel() -> PositionsViewModel {
        return PositionsViewModel(api: mockAPI, appState: appState)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makePosition(
        publicId: String,
        instrument: String = "BTCUSD",
        instrumentPublicId: String? = "inst-1",
        walletPublicId: String? = "wallet-1",
        quantity: Double = 1.0,
        averagePrice: Double = 50000.0,
        unrealizedPnl: Double = 100.0,
        positionCyclePublicId: String? = "cycle-1",
        exchange: String = "kraken",
        mode: String? = "live"
    ) -> PositionSnapshot {
        return PositionData(
            type: "position_data",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            instrument: instrument,
            instrumentPublicId: instrumentPublicId,
            exchange: exchange,
            mode: mode,
            quantity: quantity,
            averagePrice: averagePrice,
            unrealizedPnl: unrealizedPnl,
            realizedPnl: 0,
            markPrice: nil,
            markedAt: nil,
            sourceVenueEventId: nil,
            positionCyclePublicId: positionCyclePublicId,
            walletPublicId: walletPublicId
        )
    }

    private func makeExecutionPlan() -> ExecutionPlanResponse {
        return ExecutionPlanResponse(
            type: "execution_plan_response",
            sequenceId: 1,
            publicId: "plan-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            payload: ExecutionPlanData(
                type: "execution_plan_data",
                sequenceId: 1,
                publicId: "plan-1",
                timestamp: Self.baseTimestamp,
                sessionId: "session-test",
                topic: nil,
                planType: "manual",
                status: "submitted",
                instrumentPublicId: "inst-1",
                exchange: "kraken",
                mode: "live",
                side: "sell",
                totalQuantity: 1,
                filledQuantity: 0,
                createdAt: Self.baseTimestamp,
                createdVia: "ios",
                walletPublicId: "wallet-1",
                operatorPublicId: nil,
                params: [:],
                positionCyclePublicId: "cycle-1",
                parentPlanPublicId: nil,
                lastError: nil,
                idempotencyKey: nil
            )
        )
    }
    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.positions.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
        XCTAssertNil(viewModel.submitError)
    }
    func testLoadHappyPathPopulatesPositions() async {
        let viewModel = makeViewModel()
        let pos = makePosition(publicId: "p-1")
        mockAPI.fetchPositionsHandler = { [pos] }
        await viewModel.load()
        XCTAssertEqual(viewModel.positions.count, 1)
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadFailureSetsLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchPositionsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertTrue(viewModel.positions.isEmpty)
        guard case .httpError(let code) = viewModel.loadError else {
            XCTFail("Expected APIError.httpError; got \(String(describing: viewModel.loadError))")
            return
        }
        XCTAssertEqual(code, 503)
    }

    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        struct UnexpectedError: Error {}
        let viewModel = makeViewModel()
        mockAPI.fetchPositionsHandler = { throw UnexpectedError() }
        await viewModel.load()
        guard case .invalidResponse = viewModel.loadError else {
            XCTFail("Expected APIError.invalidResponse; got \(String(describing: viewModel.loadError))")
            return
        }
    }

    func testLoadClearsLoadErrorOnRecovery() async {
        let viewModel = makeViewModel()
        mockAPI.fetchPositionsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.loadError)
        let pos = makePosition(publicId: "p-1")
        mockAPI.fetchPositionsHandler = { [pos] }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError)
    }
    func testSubmitMarketReduceSuccessTriggersReload() async {
        let viewModel = makeViewModel()
        let pos = makePosition(publicId: "p-1")
        mockAPI.fetchPositionsHandler = { [pos] }
        let plan = makeExecutionPlan()
        mockAPI.createOrderHandler = { _ in plan }
        let result = await viewModel.submitMarketReduce(position: pos, quantity: 0.5)
        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.positions.count, 1, "Reload populates after submit")
        XCTAssertNil(viewModel.submitError)
    }

    func testSubmitMarketReduceFailsWithMissingIds() async {
        let viewModel = makeViewModel()
        let pos = makePosition(publicId: "p-1", instrumentPublicId: nil)
        let result = await viewModel.submitMarketReduce(position: pos, quantity: 0.5)
        XCTAssertFalse(result)
        XCTAssertTrue(viewModel.submitError?.contains("missing") == true)
    }

    func testSubmitMarketReduceAPIFailureStampsError() async {
        let viewModel = makeViewModel()
        let pos = makePosition(publicId: "p-1")
        mockAPI.createOrderHandler = { _ in throw APIError.httpError(422) }
        let result = await viewModel.submitMarketReduce(position: pos, quantity: 0.5)
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.submitError, "Couldn't submit the order. Try again.")
    }
    func testSubmitBracketSuccessTriggersReload() async {
        let viewModel = makeViewModel()
        let pos = makePosition(publicId: "p-1")
        mockAPI.fetchPositionsHandler = { [pos] }
        let plan = makeExecutionPlan()
        mockAPI.createBracketHandler = { _ in plan }
        let result = await viewModel.submitBracket(
            position: pos,
            slPrice: 49000,
            tpPrice: 51000,
            idempotencyKey: "bk-1"
        )
        XCTAssertTrue(result)
        XCTAssertNil(viewModel.submitError)
    }

    func testSubmitBracketFailsWithoutCycleId() async {
        let viewModel = makeViewModel()
        let pos = makePosition(publicId: "p-1", positionCyclePublicId: nil)
        let result = await viewModel.submitBracket(
            position: pos,
            slPrice: 49000,
            tpPrice: nil,
            idempotencyKey: "bk-1"
        )
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.submitError, "Position has no active cycle to attach a bracket to.")
    }

    func testSubmitBracketAPIFailureStampsError() async {
        let viewModel = makeViewModel()
        let pos = makePosition(publicId: "p-1")
        mockAPI.createBracketHandler = { _ in throw APIError.httpError(422) }
        let result = await viewModel.submitBracket(
            position: pos,
            slPrice: 49000,
            tpPrice: nil,
            idempotencyKey: "bk-1"
        )
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.submitError, "Couldn't attach bracket. Try again.")
    }
    func testSubmitTrailingStopSuccess() async {
        let viewModel = makeViewModel()
        let pos = makePosition(publicId: "p-1")
        mockAPI.fetchPositionsHandler = { [pos] }
        let plan = makeExecutionPlan()
        mockAPI.createTrailingStopHandler = { _ in plan }
        let result = await viewModel.submitTrailingStop(
            position: pos,
            trailingPct: 1.5,
            minLockPct: 0.5,
            idempotencyKey: "ts-1"
        )
        XCTAssertTrue(result)
        XCTAssertNil(viewModel.submitError)
    }

    func testSubmitTrailingStopFailsWithoutCycleId() async {
        let viewModel = makeViewModel()
        let pos = makePosition(publicId: "p-1", positionCyclePublicId: nil)
        let result = await viewModel.submitTrailingStop(
            position: pos,
            trailingPct: 1.5,
            minLockPct: nil,
            idempotencyKey: "ts-1"
        )
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.submitError, "Position has no active cycle to attach a trailing stop to.")
    }

    func testSubmitTrailingStopAPIFailureStampsError() async {
        let viewModel = makeViewModel()
        let pos = makePosition(publicId: "p-1")
        mockAPI.createTrailingStopHandler = { _ in throw APIError.httpError(422) }
        let result = await viewModel.submitTrailingStop(
            position: pos,
            trailingPct: 1.5,
            minLockPct: nil,
            idempotencyKey: "ts-1"
        )
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.submitError, "Couldn't attach trailing stop. Try again.")
    }
    func testFilteredPositionsScopesByWallet() {
        let viewModel = makeViewModel()
        appState.selectedWalletPublicId = "w-A"
        viewModel.positions = [
            makePosition(publicId: "p-A", walletPublicId: "w-A"),
            makePosition(publicId: "p-B", walletPublicId: "w-B"),
            makePosition(publicId: "p-system", walletPublicId: nil),
        ]
        let filtered = viewModel.filteredPositions
        XCTAssertEqual(filtered.count, 2, "Wallet A's row + nil-walletId system row")
        XCTAssertTrue(filtered.contains { $0.publicId == "p-A" })
        XCTAssertTrue(filtered.contains { $0.publicId == "p-system" })
    }

    func testFilteredPositionsPassesAllWhenNoSelection() {
        let viewModel = makeViewModel()
        viewModel.positions = [
            makePosition(publicId: "p-A", walletPublicId: "w-A"),
            makePosition(publicId: "p-B", walletPublicId: "w-B"),
        ]
        XCTAssertEqual(viewModel.filteredPositions.count, 2)
    }

    /// Pre-existing non-nil ``lastExecution`` at observation-start
    /// time must NOT fire a redundant load.
    func testLiveReloadDoesNotFireOnObservationStart() async throws {
        let viewModel = makeViewModel()
        let state = WSState()
        state.lastExecution = ExecutionData.fixture()
        let counter = PositionsLiveReloadCallCounter()
        mockAPI.fetchPositionsHandler = { await counter.increment(); return [] }

        viewModel.startObservingLiveUpdates(from: state)
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "observation start must not fire load on the replayed value")
        viewModel.stopObservingLiveUpdates()
    }

    /// Post-start mutation of ``lastExecution`` triggers a debounced
    /// load. 100ms warm-up before the mutation lets the observation
    /// task install its `for await` loop on the `.values` async
    /// sequence before the dropFirst-skipped value lands.
    func testLiveReloadFiresOnPostStartChange() async throws {
        let viewModel = makeViewModel()
        let state = WSState()
        viewModel.startObservingLiveUpdates(from: state)
        try await Task.sleep(nanoseconds: 100_000_000)
        let counter = PositionsLiveReloadCallCounter()
        mockAPI.fetchPositionsHandler = { await counter.increment(); return [] }

        state.lastExecution = ExecutionData.fixture()
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertGreaterThanOrEqual(count, 1)
        viewModel.stopObservingLiveUpdates()
    }

    /// ``stopObservingLiveUpdates`` cancels a pending debounced
    /// reload before it fires.
    func testStopObservingCancelsPendingReload() async throws {
        let viewModel = makeViewModel()
        let state = WSState()
        viewModel.startObservingLiveUpdates(from: state)
        try await Task.sleep(nanoseconds: 100_000_000)
        let counter = PositionsLiveReloadCallCounter()
        mockAPI.fetchPositionsHandler = { await counter.increment(); return [] }

        state.lastExecution = ExecutionData.fixture()
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.stopObservingLiveUpdates()
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "pending debounced load must be cancelled by stop")
    }
}

private actor PositionsLiveReloadCallCounter {
    var value: Int = 0
    func increment() { value += 1 }
}
