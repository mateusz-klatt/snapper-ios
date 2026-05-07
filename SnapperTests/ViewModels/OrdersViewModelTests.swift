import XCTest
@testable import Snapper

/// Async / instance-state tests for `OrdersViewModel`.
///
/// Pure-helper coverage (filter / isOpen / shouldShow*) lives in
/// `Views/OrdersViewTests.swift` and exercises the static surface
/// (the existing test contract). The tests here drive the live VM
/// through real async branches: parallel `async let` load happy
/// path / partial failure paths, submit + cancel happy + failure,
/// derived collections + `resolvedWallet` reactivity.
@MainActor
final class OrdersViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
        let suiteName = "OrdersViewModelTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        appState = AppState(userDefaults: userDefaults)
    }

    override func tearDown() {
        mockAPI = nil
        appState = nil
        super.tearDown()
    }
    private func makeViewModel() -> OrdersViewModel {
        return OrdersViewModel(api: mockAPI, appState: appState)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeOrder(
        publicId: String,
        status: String = "open",
        walletPublicId: String? = nil,
        instrument: String = "BTCUSD",
        side: String = "buy",
        orderType: String = "limit",
        size: Double = 1.0,
        price: Double? = 50000.0,
        exchange: String = "kraken",
        createdAtOffset: TimeInterval = 0,
        planPublicId: String? = nil
    ) -> OrderStatus {
        return OrderData(
            type: "order_data",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-orders-test",
            topic: nil,
            exchangeOrderId: nil,
            clientOrderId: "cli-\(publicId)",
            instrument: instrument,
            exchange: exchange,
            mode: nil,
            side: side,
            status: status,
            orderType: orderType,
            size: size,
            filledSize: 0.0,
            price: price,
            averagePrice: nil,
            reason: nil,
            timeInForce: nil,
            error: nil,
            createdAt: Self.baseTimestamp.addingTimeInterval(createdAtOffset),
            updatedAt: nil,
            leverage: nil,
            reduceOnly: nil,
            walletPublicId: walletPublicId,
            operatorPublicId: nil,
            userPublicId: nil,
            planPublicId: planPublicId
        )
    }

    private func makeExecution(
        publicId: String,
        walletPublicId: String? = nil,
        instrument: String = "BTCUSD",
        side: String = "buy",
        exchange: String = "kraken"
    ) -> ExecutionRecord {
        return ExecutionData(
            type: "execution_data",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-orders-test",
            topic: nil,
            tradeId: nil,
            exchangeOrderId: nil,
            clientOrderId: "cli-\(publicId)",
            instrument: instrument,
            exchange: exchange,
            side: side,
            size: 1.0,
            price: 50000.0,
            lastSize: 1.0,
            lastPrice: 50000.0,
            fee: 0.1,
            feeAsset: "USD",
            status: "filled",
            executedAt: Self.baseTimestamp,
            walletPublicId: walletPublicId,
            operatorPublicId: nil,
            userPublicId: nil,
            liquidityRole: nil
        )
    }

    private func makeWallet(
        publicId: String,
        label: String = "main",
        isPaper: Bool = false
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
                side: "buy",
                totalQuantity: 1,
                filledQuantity: 0,
                createdAt: Self.baseTimestamp,
                createdVia: "ios",
                walletPublicId: "wallet-1",
                operatorPublicId: nil,
                params: [:],
                positionCyclePublicId: nil,
                parentPlanPublicId: nil,
                lastError: nil,
                idempotencyKey: nil
            )
        )
    }
    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.orders.isEmpty)
        XCTAssertTrue(viewModel.executions.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.submitError)
    }
    func testLoadHappyPathPopulatesOrdersAndExecutions() async {
        let viewModel = makeViewModel()
        let order = makeOrder(publicId: "ord-1")
        let execution = makeExecution(publicId: "exec-1")
        mockAPI.fetchOrdersHandler = { [order] }
        mockAPI.fetchExecutionsHandler = { [execution] }
        await viewModel.load()
        XCTAssertEqual(viewModel.orders.count, 1)
        XCTAssertEqual(viewModel.executions.count, 1)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// Partial-failure: orders fail but executions succeed → both
    /// state slots reflect what succeeded; errorMessage stamps from
    /// the orders failure so the user knows something went wrong.
    func testLoadPartialFailureOrdersFailExecutionsSucceed() async {
        let viewModel = makeViewModel()
        mockAPI.fetchOrdersHandler = { throw APIError.httpError(503) }
        let execution = makeExecution(publicId: "exec-1")
        mockAPI.fetchExecutionsHandler = { [execution] }
        await viewModel.load()
        XCTAssertTrue(viewModel.orders.isEmpty)
        XCTAssertEqual(viewModel.executions.count, 1)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    /// Partial-failure: orders succeed but executions fail → the
    /// Fills tab silently dropping its data was the v0.2.0 PR #2
    /// regression; now the error must surface.
    func testLoadPartialFailureExecutionsFailOrdersSucceed() async {
        let viewModel = makeViewModel()
        let order = makeOrder(publicId: "ord-1")
        mockAPI.fetchOrdersHandler = { [order] }
        mockAPI.fetchExecutionsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertEqual(viewModel.orders.count, 1)
        XCTAssertTrue(viewModel.executions.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testLoadBothFailuresStampsErrorMessage() async {
        let viewModel = makeViewModel()
        mockAPI.fetchOrdersHandler = { throw APIError.httpError(500) }
        mockAPI.fetchExecutionsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertTrue(viewModel.orders.isEmpty)
        XCTAssertTrue(viewModel.executions.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    func testSubmitNewOrderSuccessTriggersReload() async {
        let viewModel = makeViewModel()
        let order = makeOrder(publicId: "ord-fresh")
        mockAPI.fetchOrdersHandler = { [order] }
        mockAPI.fetchExecutionsHandler = { [] }
        let plan = makeExecutionPlan()
        mockAPI.createOrderHandler = { _ in plan }
        let body = CreateOrderBody(
            instrument: "BTC-USD",
            instrumentPublicId: "inst-1",
            exchange: "kraken",
            mode: "live",
            side: "buy",
            orderType: "market",
            quantity: 1,
            price: nil,
            stopPrice: nil,
            timeInForce: "GTC",
            postOnly: false,
            leverage: nil,
            reduceOnly: false,
            walletPublicId: "wallet-1",
            operatorPublicId: nil,
            idempotencyKey: "k-1",
            aiReviewPublicId: nil
        )
        let result = await viewModel.submitNewOrder(body: body)
        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.orders.count, 1, "Successful submit triggers a reload")
        XCTAssertNil(viewModel.submitError)
    }

    func testSubmitNewOrderFailureStampsSubmitError() async {
        let viewModel = makeViewModel()
        mockAPI.createOrderHandler = { _ in throw APIError.httpError(422) }
        let body = CreateOrderBody(
            instrument: "BTC-USD",
            instrumentPublicId: "inst-1",
            exchange: "kraken",
            mode: "live",
            side: "buy",
            orderType: "market",
            quantity: 1,
            price: nil,
            stopPrice: nil,
            timeInForce: "GTC",
            postOnly: false,
            leverage: nil,
            reduceOnly: false,
            walletPublicId: "wallet-1",
            operatorPublicId: nil,
            idempotencyKey: "k-1",
            aiReviewPublicId: nil
        )
        let result = await viewModel.submitNewOrder(body: body)
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.submitError, "Couldn't submit the order. Try again.")
    }
    func testSubmitCancelSuccessTriggersReload() async {
        let viewModel = makeViewModel()
        let order = makeOrder(publicId: "ord-1", status: "filled", planPublicId: "plan-1")
        mockAPI.fetchOrdersHandler = { [order] }
        mockAPI.fetchExecutionsHandler = { [] }
        let plan = makeExecutionPlan()
        mockAPI.cancelOrderHandler = { _, _ in plan }
        await viewModel.submitCancel(order: makeOrder(publicId: "ord-1", planPublicId: "plan-1"))
        XCTAssertEqual(viewModel.orders.count, 1, "Reload populates orders after cancel")
        XCTAssertNil(viewModel.submitError)
    }

    func testSubmitCancelWithoutPlanPublicIdSetsError() async {
        let viewModel = makeViewModel()
        await viewModel.submitCancel(order: makeOrder(publicId: "ord-no-plan"))
        XCTAssertEqual(viewModel.submitError, "This order has no execution plan to cancel.")
    }

    func testSubmitCancelFailureStampsError() async {
        let viewModel = makeViewModel()
        mockAPI.cancelOrderHandler = { _, _ in throw APIError.httpError(409) }
        await viewModel.submitCancel(order: makeOrder(publicId: "ord-1", planPublicId: "plan-1"))
        XCTAssertEqual(viewModel.submitError, "Couldn't cancel the order. Try again.")
    }
    func testFilteredOpenScopesByWallet() {
        let viewModel = makeViewModel()
        appState.selectedWalletPublicId = "w-A"
        viewModel.orders = [
            makeOrder(publicId: "ord-A", status: "open", walletPublicId: "w-A"),
            makeOrder(publicId: "ord-B", status: "open", walletPublicId: "w-B"),
            makeOrder(publicId: "ord-system", status: "open", walletPublicId: nil),
            makeOrder(publicId: "ord-filled", status: "filled", walletPublicId: "w-A"),
        ]
        let open = viewModel.filteredOpen
        XCTAssertEqual(open.count, 2, "Wallet A's open + nil-walletId system row")
        XCTAssertTrue(open.contains { $0.publicId == "ord-A" })
        XCTAssertTrue(open.contains { $0.publicId == "ord-system" })
    }

    func testFilteredRecentSortsAndCaps() {
        let viewModel = makeViewModel()
        viewModel.orders = (0..<60).map { i in
            makeOrder(
                publicId: "ord-\(i)",
                createdAtOffset: TimeInterval(i)
            )
        }
        let recent = viewModel.filteredRecent
        XCTAssertEqual(recent.count, 50, "Recent caps at 50")
        XCTAssertEqual(recent.first?.publicId, "ord-59", "Newest first")
    }

    func testFilteredFillsScopesByWallet() {
        let viewModel = makeViewModel()
        appState.selectedWalletPublicId = "w-A"
        viewModel.executions = [
            makeExecution(publicId: "exec-A", walletPublicId: "w-A"),
            makeExecution(publicId: "exec-B", walletPublicId: "w-B"),
            makeExecution(publicId: "exec-system", walletPublicId: nil),
        ]

        let fills = viewModel.filteredFills

        XCTAssertEqual(fills.count, 2)
        XCTAssertTrue(fills.contains { $0.publicId == "exec-A" })
        XCTAssertTrue(fills.contains { $0.publicId == "exec-system" })
    }

    func testDerivedExchangesUniquesAndPreservesOrder() {
        let viewModel = makeViewModel()
        viewModel.orders = [
            makeOrder(publicId: "ord-1", exchange: "kraken"),
            makeOrder(publicId: "ord-2", exchange: "binance"),
        ]
        viewModel.executions = [
            makeExecution(publicId: "exec-1", exchange: "kraken"),
            makeExecution(publicId: "exec-2", exchange: "kucoin"),
        ]
        XCTAssertEqual(viewModel.derivedExchanges, ["kraken", "binance", "kucoin"])
    }

    func testDerivedExchangesFallsBackToKrakenWhenEmpty() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.derivedExchanges, ["kraken"])
    }
    func testResolvedWalletReturnsNilWhenNoSelection() {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.resolvedWallet)
    }

    func testResolvedWalletReturnsNilWhenSelectionMissesAvailable() {
        let viewModel = makeViewModel()
        appState.selectedWalletPublicId = "w-missing"
        appState.availableWallets = [makeWallet(publicId: "w-other")]
        XCTAssertNil(viewModel.resolvedWallet)
    }

    func testResolvedWalletFindsMatchingWallet() {
        let viewModel = makeViewModel()
        appState.selectedWalletPublicId = "w-1"
        appState.availableWallets = [
            makeWallet(publicId: "w-2"),
            makeWallet(publicId: "w-1", label: "matched"),
        ]
        XCTAssertEqual(viewModel.resolvedWallet?.publicId, "w-1")
        XCTAssertEqual(viewModel.resolvedWallet?.label, "matched")
    }

    func testResolvedWalletMatchesWhenSelectedWalletIsFirstInCache() {
        let viewModel = makeViewModel()
        appState.selectedWalletPublicId = "w-1"
        appState.availableWallets = [
            makeWallet(publicId: "w-1", label: "first"),
            makeWallet(publicId: "w-2"),
        ]

        XCTAssertEqual(viewModel.resolvedWallet?.publicId, "w-1")
        XCTAssertEqual(viewModel.resolvedWallet?.label, "first")
    }

    /// Pre-existing non-nil ``lastOrderEvent`` at observation-start
    /// time must NOT fire a redundant load — the View's own
    /// ``viewModel?.load()`` already covered the initial fetch in
    /// the same `.task` body. ``.dropFirst()`` skips the published
    /// replay so observation only triggers on post-start changes.
    func testLiveReloadDoesNotFireOnObservationStart() async throws {
        let viewModel = makeViewModel()
        let state = WSState()
        state.lastOrderEvent = OrderEventData.fixture()
        let counter = OrdersLiveReloadCallCounter()
        mockAPI.fetchOrdersHandler = { await counter.increment(); return [] }
        mockAPI.fetchExecutionsHandler = { return [] }

        viewModel.startObservingLiveUpdates(from: state)
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "observation start must not fire load on the replayed value")
        viewModel.stopObservingLiveUpdates()
    }

    /// Post-start mutation of ``lastOrderEvent`` triggers a
    /// debounced load within ~250ms + tolerance.
    ///
    /// The 100ms warm-up sleep before the mutation gives the
    /// observation tasks time to start their `for await` loops on
    /// the `.values` async sequence — without it, the
    /// `dropFirst()` skip can race against the assignment and miss
    /// the change entirely.
    func testLiveReloadFiresOnPostStartChange() async throws {
        let viewModel = makeViewModel()
        let state = WSState()
        viewModel.startObservingLiveUpdates(from: state)
        try await Task.sleep(nanoseconds: 100_000_000)
        let counter = OrdersLiveReloadCallCounter()
        mockAPI.fetchOrdersHandler = { await counter.increment(); return [] }
        mockAPI.fetchExecutionsHandler = { return [] }

        state.lastOrderEvent = OrderEventData.fixture()
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertGreaterThanOrEqual(count, 1)
        viewModel.stopObservingLiveUpdates()
    }

    /// Burst of 5 frames within 50ms coalesces to a single REST
    /// reload via the 250ms debounce.
    func testLiveReloadCoalescesBurst() async throws {
        let viewModel = makeViewModel()
        let state = WSState()
        viewModel.startObservingLiveUpdates(from: state)
        try await Task.sleep(nanoseconds: 100_000_000)
        let counter = OrdersLiveReloadCallCounter()
        mockAPI.fetchOrdersHandler = { await counter.increment(); return [] }
        mockAPI.fetchExecutionsHandler = { return [] }

        for i in 0..<5 {
            state.lastOrderEvent = OrderEventData.fixture(clientOrderId: "burst-\(i)")
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 1, "burst should coalesce to exactly one reload")
        viewModel.stopObservingLiveUpdates()
    }

    /// ``stopObservingLiveUpdates`` cancels a pending debounced
    /// reload before it fires.
    func testStopObservingCancelsPendingReload() async throws {
        let viewModel = makeViewModel()
        let state = WSState()
        viewModel.startObservingLiveUpdates(from: state)
        try await Task.sleep(nanoseconds: 100_000_000)
        let counter = OrdersLiveReloadCallCounter()
        mockAPI.fetchOrdersHandler = { await counter.increment(); return [] }
        mockAPI.fetchExecutionsHandler = { return [] }

        state.lastOrderEvent = OrderEventData.fixture()
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.stopObservingLiveUpdates()
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "pending debounced load must be cancelled by stop")
    }

    /// ``startObservingLiveUpdates`` is self-cleaning — calling it
    /// while a prior observation is in flight cancels the old tasks
    /// before installing new ones. After restart, mutations to the
    /// PRIOR ``WSState`` instance must NOT fire reload.
    func testRestartCleansUpPriorObservation() async throws {
        let viewModel = makeViewModel()
        let stateA = WSState()
        let stateB = WSState()
        viewModel.startObservingLiveUpdates(from: stateA)
        viewModel.startObservingLiveUpdates(from: stateB)
        try await Task.sleep(nanoseconds: 100_000_000)
        let counter = OrdersLiveReloadCallCounter()
        mockAPI.fetchOrdersHandler = { await counter.increment(); return [] }
        mockAPI.fetchExecutionsHandler = { return [] }

        stateA.lastOrderEvent = OrderEventData.fixture(clientOrderId: "should-not-fire")
        try await Task.sleep(nanoseconds: 500_000_000)
        let countAfterA = await counter.value
        XCTAssertEqual(countAfterA, 0, "stateA observation should be torn down after restart")

        stateB.lastOrderEvent = OrderEventData.fixture(clientOrderId: "should-fire")
        try await Task.sleep(nanoseconds: 500_000_000)
        let countAfterB = await counter.value
        XCTAssertGreaterThanOrEqual(countAfterB, 1, "stateB observation should be active")
        viewModel.stopObservingLiveUpdates()
    }
}

private actor OrdersLiveReloadCallCounter {
    var value: Int = 0
    func increment() { value += 1 }
}
