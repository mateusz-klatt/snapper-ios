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
            planPublicId: planPublicId,
            pairedGroupId: nil,
            pairedGroupSize: nil,
            pairedGroupIndex: nil,
            pairedGroupPolicy: nil
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
            liquidityRole: nil,
            pairedGroupId: nil,
            pairedGroupSize: nil,
            pairedGroupIndex: nil,
            pairedGroupPolicy: nil
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

    private func beginNewOrder(
        on viewModel: OrdersViewModel
    ) throws -> OrdersViewModel.NewOrderPresentation {
        appState.availableWallets = [makeWallet(publicId: "wallet-1")]
        appState.selectedWalletPublicId = "wallet-1"
        return try XCTUnwrap(viewModel.beginNewOrderPresentation())
    }

    private func makeOrderBody(idempotencyKey: String = "attempt-A") -> CreateOrderBody {
        return CreateOrderBody(
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
            idempotencyKey: idempotencyKey,
            aiReviewPublicId: nil
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
    func testSubmitNewOrderSuccessTriggersReload() async throws {
        let viewModel = makeViewModel()
        let presentation = try beginNewOrder(on: viewModel)
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
        let result = await viewModel.submitNewOrder(body: body, presentationID: presentation.id)
        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.orders.count, 1, "Successful submit triggers a reload")
        XCTAssertNil(viewModel.submitError)
        XCTAssertNil(viewModel.newOrderPresentation)
    }

    func testSubmitNewOrderFailureStampsSubmitError() async throws {
        let viewModel = makeViewModel()
        let presentation = try beginNewOrder(on: viewModel)
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
        let result = await viewModel.submitNewOrder(body: body, presentationID: presentation.id)
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.submitError, "Couldn't submit the order. Try again.")
        XCTAssertEqual(viewModel.newOrderPresentation?.id, presentation.id)
    }

    /// Given A is awaiting its API response and B has opened after A was dismissed,
    /// when A fails, B must remain open without inheriting A's submit error.
    func testDismissedSubmissionCannotSetErrorOnNewPresentation() async throws {
        try await assertStaleCreateCompletion(fails: true, currentError: nil, cancelOriginal: false)
    }

    /// Given B already has its own visible error, when an older A request fails,
    /// then B's exact error and presentation remain owned by B.
    func testDismissedSubmissionCannotReplaceCurrentPresentationError() async throws {
        try await assertStaleCreateCompletion(
            fails: true, currentError: "Current presentation B error", cancelOriginal: false
        )
    }

    /// Given an API ignores A's cancellation and B opens, when A later succeeds,
    /// then its completion cannot reload shared state, clear B's error or dismiss B.
    func testCancelledSuccessfulSubmissionCannotReloadOrDismissNewPresentation() async throws {
        try await assertStaleCreateCompletion(
            fails: false, currentError: "Current presentation B error", cancelOriginal: true
        )
    }

    private func assertStaleCreateCompletion(
        fails: Bool, currentError: String?, cancelOriginal: Bool
    ) async throws {
        let viewModel = makeViewModel()
        let first = try beginNewOrder(on: viewModel)
        let body = makeOrderBody()
        let plan = makeExecutionPlan()
        let gate = OrdersSubmissionGate()
        let reloads = OrdersLiveReloadCallCounter()
        mockAPI.createOrderHandler = { _ in
            await gate.markStartedAndWait()
            if fails { throw APIError.httpError(422) }
            return plan
        }
        mockAPI.fetchOrdersHandler = { await reloads.increment(); return [] }
        mockAPI.fetchExecutionsHandler = { [] }
        let pending = Task { await viewModel.submitNewOrder(body: body, presentationID: first.id) }
        await gate.awaitStarted()
        if cancelOriginal { pending.cancel() }
        viewModel.endNewOrderPresentation(id: first.id)
        let second = try beginNewOrder(on: viewModel)
        viewModel.submitError = currentError
        viewModel.endNewOrderPresentation(id: first.id)
        XCTAssertEqual(viewModel.newOrderPresentation?.id, second.id)
        XCTAssertNotEqual(first.id, second.id)
        await gate.release()
        let result = await pending.value
        let reloadCount = await reloads.value
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.newOrderPresentation?.id, second.id)
        XCTAssertEqual(viewModel.submitError, currentError)
        XCTAssertEqual(reloadCount, 0)
    }

    /// Given A has succeeded but its reload remains suspended, when B opens before
    /// those fetches finish, then A publishes neither list state nor dismissal into B.
    func testDismissedSubmissionReloadCannotPublishIntoNewPresentation() async throws {
        let viewModel = makeViewModel()
        let first = try beginNewOrder(on: viewModel)
        let body = makeOrderBody()
        let plan = makeExecutionPlan()
        let oldOrder = makeOrder(publicId: "old-A")
        let oldExecution = makeExecution(publicId: "old-A-execution")
        let gate = OrdersSubmissionGate()
        mockAPI.createOrderHandler = { _ in plan }
        mockAPI.fetchOrdersHandler = {
            await gate.markStartedAndWait()
            return [oldOrder]
        }
        mockAPI.fetchExecutionsHandler = { [oldExecution] }
        let pending = Task { await viewModel.submitNewOrder(body: body, presentationID: first.id) }
        await gate.awaitStarted()
        viewModel.endNewOrderPresentation(id: first.id)
        let second = try beginNewOrder(on: viewModel)
        viewModel.orders = [makeOrder(publicId: "current-B")]
        viewModel.executions = [makeExecution(publicId: "current-B-execution")]
        viewModel.errorMessage = "Current B load error"
        viewModel.submitError = "Current B submit error"
        viewModel.isLoading = true
        await gate.release()
        let result = await pending.value
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.newOrderPresentation?.id, second.id)
        XCTAssertEqual(viewModel.orders.map(\.publicId), ["current-B"])
        XCTAssertEqual(viewModel.executions.map(\.publicId), ["current-B-execution"])
        XCTAssertEqual(viewModel.errorMessage, "Current B load error")
        XCTAssertEqual(viewModel.submitError, "Current B submit error")
        XCTAssertTrue(viewModel.isLoading)
    }

    /// Given A's callbacks are retained after B replaces it, when A tries to submit
    /// or dismiss, then no API request is made and B's current state is preserved.
    func testStalePresentationCannotStartRequestOrDismissCurrentPresentation() async throws {
        let viewModel = makeViewModel()
        let first = try beginNewOrder(on: viewModel)
        viewModel.endNewOrderPresentation(id: first.id)
        let second = try beginNewOrder(on: viewModel)
        viewModel.submitError = "Current B submit error"
        let calls = OrdersLiveReloadCallCounter()
        let plan = makeExecutionPlan()
        mockAPI.createOrderHandler = { _ in await calls.increment(); return plan }
        let result = await viewModel.submitNewOrder(body: makeOrderBody(), presentationID: first.id)
        viewModel.endNewOrderPresentation(id: first.id)
        let callCount = await calls.value
        XCTAssertFalse(result)
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(viewModel.newOrderPresentation?.id, second.id)
        XCTAssertEqual(viewModel.submitError, "Current B submit error")
    }

    /// Given a selected wallet and venue, when selection changes after opening a sheet,
    /// then its original snapshot stays fixed and a replacement gets a fresh lifetime.
    func testNewOrderPresentationFreezesWalletAndVenue() throws {
        let viewModel = makeViewModel()
        let first = try beginNewOrder(on: viewModel)
        appState.availableWallets = [makeWallet(publicId: "wallet-2", isPaper: true)]
        appState.selectedWalletPublicId = "wallet-2"
        viewModel.orders = [makeOrder(publicId: "other-venue", exchange: "binance")]
        XCTAssertEqual(first.walletPublicId, "wallet-1")
        XCTAssertFalse(first.walletIsPaper)
        XCTAssertEqual(first.exchanges, ["kraken"])
        let second = try XCTUnwrap(viewModel.beginNewOrderPresentation())
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(second.walletPublicId, "wallet-2")
        XCTAssertTrue(second.walletIsPaper)
        XCTAssertEqual(second.exchanges, ["binance"])
    }

    /// Given no selected wallet resolves, when presentation begins, then no sheet lifetime is created.
    func testNewOrderPresentationRequiresResolvedWallet() {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.beginNewOrderPresentation())
        XCTAssertNil(viewModel.newOrderPresentation)
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

/// Deterministic API suspension that deliberately ignores caller cancellation.
private actor OrdersSubmissionGate {
    private var started = false
    private var released = false
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func markStartedAndWait() async {
        started = true
        for waiter in startedWaiters { waiter.resume() }
        startedWaiters.removeAll()
        if released { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func awaitStarted() async {
        if started { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }

    func release() {
        released = true
        for waiter in releaseWaiters { waiter.resume() }
        releaseWaiters.removeAll()
    }
}
