import XCTest
@testable import Snapper

/// Non-``APIError`` error used to drive the ``load()`` fallback branch
/// that maps any non-typed failure to ``APIError.invalidResponse``.
private struct SignalsUnexpectedError: Error {}

@MainActor
final class SignalsViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
        let suiteName = "SignalsViewModelTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        appState = AppState(userDefaults: userDefaults)
    }

    override func tearDown() {
        mockAPI = nil
        appState = nil
        super.tearDown()
    }

    private func makeViewModel() -> SignalsViewModel {
        return SignalsViewModel(api: mockAPI, appState: appState)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSignal(
        publicId: String,
        side: String = "buy",
        strength: Double = 0.75,
        price: Double? = 100.0,
        strategyName: String? = "momentum",
        walletPublicId: String? = "wallet-1",
        reason: String = "breakout",
        instrument: String = "BTC-USD",
        exchange: String = "kraken"
    ) -> TradingSignal {
        return SignalData(
            type: nil,
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            instrument: instrument,
            exchange: exchange,
            side: side,
            strength: strength,
            reason: reason,
            price: price,
            strategyName: strategyName,
            firedAt: Self.baseTimestamp,
            walletPublicId: walletPublicId,
            operatorPublicId: nil,
            userPublicId: nil,
            aiReviewPublicId: nil,
            aiReviewDispatchVersion: nil,
            pairedGroupId: nil,
            pairedGroupSize: nil,
            pairedGroupIndex: nil,
            pairedGroupPolicy: nil,
            pairedGroupKey: nil,
            origin: nil,
            replayWindowStart: nil,
            replayWindowEnd: nil
        )
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.signals.isEmpty)
        XCTAssertTrue(viewModel.filteredSignals.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.stats, SignalStats(total: 0, buy: 0, sell: 0, averageStrength: 0.0))
    }

    func testLoadHappyPathPopulatesSignals() async {
        let viewModel = makeViewModel()
        let signal = makeSignal(publicId: "s-1")
        mockAPI.fetchSignalsHandler = { [signal] }
        await viewModel.load()
        XCTAssertEqual(viewModel.signals.count, 1)
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadFailureSetsTypedLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchSignalsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertTrue(viewModel.signals.isEmpty)
        guard case .httpError(let code) = viewModel.loadError else {
            return XCTFail("Expected httpError, got \(String(describing: viewModel.loadError))")
        }
        XCTAssertEqual(code, 503)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// Any non-``APIError`` failure must be normalised to
    /// ``APIError.invalidResponse`` so the View's error branch always
    /// has a typed error to render.
    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        let viewModel = makeViewModel()
        mockAPI.fetchSignalsHandler = { throw SignalsUnexpectedError() }
        await viewModel.load()
        guard case .invalidResponse = viewModel.loadError else {
            return XCTFail("Expected invalidResponse fallback, got \(String(describing: viewModel.loadError))")
        }
    }

    /// A successful reload after a prior failure clears the stale error
    /// so the recovered list is not masked by an error banner.
    func testLoadClearsPreviousError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchSignalsHandler = { throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.loadError)

        let signal = makeSignal(publicId: "s-1")
        mockAPI.fetchSignalsHandler = { [signal] }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.signals.count, 1)
    }

    func testFilteredSignalsAppliesWalletScope() async {
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = makeViewModel()
        let mine = makeSignal(publicId: "s-mine", walletPublicId: "wallet-1")
        let other = makeSignal(publicId: "s-other", walletPublicId: "wallet-2")
        let orphan = makeSignal(publicId: "s-orphan", walletPublicId: nil)
        mockAPI.fetchSignalsHandler = { [mine, other, orphan] }
        await viewModel.load()
        XCTAssertEqual(Set(viewModel.filteredSignals.map(\.publicId)), Set(["s-mine", "s-orphan"]))
    }

    /// The summary tiles read from the wallet-scoped list, not the raw
    /// fetch — a signal from another wallet must not inflate the counts.
    func testStatsReflectWalletScopedList() async {
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = makeViewModel()
        let buyStrong = makeSignal(publicId: "s-1", side: "buy", strength: 0.9, walletPublicId: "wallet-1")
        let sellMid = makeSignal(publicId: "s-2", side: "sell", strength: 0.5, walletPublicId: "wallet-1")
        let otherWallet = makeSignal(publicId: "s-3", side: "buy", strength: 0.1, walletPublicId: "wallet-2")
        mockAPI.fetchSignalsHandler = { [buyStrong, sellMid, otherWallet] }
        await viewModel.load()
        let stats = viewModel.stats
        XCTAssertEqual(stats.total, 2)
        XCTAssertEqual(stats.buy, 1)
        XCTAssertEqual(stats.sell, 1)
        XCTAssertEqual(stats.averageStrength, 0.7, accuracy: 0.0001)
    }

    private func makeWebSocketManager() -> WebSocketManager {
        return WebSocketManager(
            authService: FakeAuthService(nextToken: "t"),
            taskFactory: FakeWebSocketTaskFactory(task: FakeWebSocketTask()),
            sleeper: FakeSleeper()
        )
    }

    /// A `signal` pulse arriving after the startup reconciliation settles
    /// triggers exactly one additional debounced ``load()``.
    func testLiveSignalPulseTriggersOneReload() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = SignalsReloadCounter()
        mockAPI.fetchSignalsHandler = { await counter.increment(); return [] }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 500_000_000)
        let baseline = await counter.value
        manager.state.lastSignalAt = Date()
        try await Task.sleep(nanoseconds: 500_000_000)

        let after = await counter.value
        XCTAssertEqual(after, baseline + 1, "one signal pulse triggers exactly one reload")
        viewModel.stopObservingLiveUpdates(token: token)
    }

    /// Stopping observation before the debounce fires leaves no pending
    /// reload.
    func testStopLeavesNoPendingReload() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = SignalsReloadCounter()
        mockAPI.fetchSignalsHandler = { await counter.increment(); return [] }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 100_000_000)
        manager.state.lastSignalAt = Date()
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.stopObservingLiveUpdates(token: token)
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "stop before the debounce window must cancel the pending reload")
    }

    /// R-A2: cancelling the enclosing task while the initial ``load()`` is
    /// suspended must, via the view's post-load ``Task.isCancelled`` guard,
    /// prevent observation from starting — so no startup reconciliation
    /// reload fires. Replicates the view's `.task` flow with a gated load.
    func testCancellationDuringSuspendedLoadPreventsObservation() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = SignalsReloadCounter()
        let loadGate = SignalsLoadGate()
        mockAPI.fetchSignalsHandler = {
            await loadGate.wait()
            await counter.increment()
            return []
        }

        let task = Task { @MainActor in
            await viewModel.load()
            if Task.isCancelled { return }
            _ = viewModel.startObservingLiveUpdates(from: manager)
        }
        try await Task.sleep(nanoseconds: 150_000_000)
        task.cancel()
        await loadGate.release()
        _ = await task.value
        try await Task.sleep(nanoseconds: 600_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 1, "cancellation during load must block observation start (no reconciliation reload)")
    }

    func testSelectedStrategyDefaultsToNil() {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.selectedStrategy)
    }

    /// The strategy options derive from the wallet-scoped signals, in
    /// first-appearance order, so the picker offers only strategies whose
    /// rows are actually visible for the selected wallet.
    func testAvailableStrategiesAreWalletScopedAndOrdered() async {
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = makeViewModel()
        let rows = [
            makeSignal(publicId: "s-1", strategyName: "momentum", walletPublicId: "wallet-1"),
            makeSignal(publicId: "s-2", strategyName: "reversion", walletPublicId: "wallet-1"),
            makeSignal(publicId: "s-3", strategyName: "momentum", walletPublicId: "wallet-1"),
            makeSignal(publicId: "s-4", strategyName: "other-wallet", walletPublicId: "wallet-2"),
        ]
        mockAPI.fetchSignalsHandler = { rows }
        await viewModel.load()
        XCTAssertEqual(viewModel.availableStrategies, ["momentum", "reversion"])
    }

    /// The filtered list composes the wallet scope with the strategy
    /// selection.
    func testFilteredSignalsComposesWalletAndStrategy() async {
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = makeViewModel()
        let rows = [
            makeSignal(publicId: "s-mom", strategyName: "momentum", walletPublicId: "wallet-1"),
            makeSignal(publicId: "s-rev", strategyName: "reversion", walletPublicId: "wallet-1"),
            makeSignal(publicId: "s-other", strategyName: "momentum", walletPublicId: "wallet-2"),
        ]
        mockAPI.fetchSignalsHandler = { rows }
        await viewModel.load()
        viewModel.selectedStrategy = "momentum"
        XCTAssertEqual(viewModel.filteredSignals.map(\.publicId), ["s-mom"])
    }

    /// The selection persists across a reload. When fresh data still
    /// carries the strategy the filter continues to apply; when it does
    /// not, the filtered list is empty (no crash) while the selection is
    /// retained.
    func testSelectionSurvivesReloadAndAbsentStrategyYieldsEmpty() async {
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = makeViewModel()
        let first = [makeSignal(publicId: "s-1", strategyName: "momentum", walletPublicId: "wallet-1")]
        mockAPI.fetchSignalsHandler = { first }
        await viewModel.load()
        viewModel.selectedStrategy = "momentum"
        XCTAssertEqual(viewModel.filteredSignals.map(\.publicId), ["s-1"])

        let second = [makeSignal(publicId: "s-2", strategyName: "momentum", walletPublicId: "wallet-1")]
        mockAPI.fetchSignalsHandler = { second }
        await viewModel.load()
        XCTAssertEqual(viewModel.selectedStrategy, "momentum")
        XCTAssertEqual(viewModel.filteredSignals.map(\.publicId), ["s-2"])

        let third = [makeSignal(publicId: "s-3", strategyName: "reversion", walletPublicId: "wallet-1")]
        mockAPI.fetchSignalsHandler = { third }
        await viewModel.load()
        XCTAssertEqual(viewModel.selectedStrategy, "momentum")
        XCTAssertTrue(viewModel.filteredSignals.isEmpty)
    }

    /// A retained selection that survives a reload into rows carrying
    /// only nil / empty strategy names leaves the options empty, yet the
    /// filter control must stay visible so the stale selection can be
    /// cleared back to "all" — otherwise the rows are filtered out with
    /// no escape.
    func testFilterStaysVisibleWhenRetainedSelectionHasNoOptions() async {
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = makeViewModel()
        let named = [makeSignal(publicId: "s-1", strategyName: "momentum", walletPublicId: "wallet-1")]
        mockAPI.fetchSignalsHandler = { named }
        await viewModel.load()
        viewModel.selectedStrategy = "momentum"
        XCTAssertTrue(viewModel.showsStrategyFilter)

        let unnamed = [makeSignal(publicId: "s-2", strategyName: nil, walletPublicId: "wallet-1")]
        mockAPI.fetchSignalsHandler = { unnamed }
        await viewModel.load()
        XCTAssertTrue(viewModel.availableStrategies.isEmpty)
        XCTAssertEqual(viewModel.selectedStrategy, "momentum")
        XCTAssertTrue(viewModel.filteredSignals.isEmpty)
        XCTAssertTrue(viewModel.showsStrategyFilter, "menu must remain so a stale selection can be cleared")
    }

    /// With no selection and no named strategies the filter control is
    /// hidden (nothing to filter by).
    func testFilterHiddenWhenNoOptionsAndNoSelection() async {
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.showsStrategyFilter)
        let unnamed = [makeSignal(publicId: "s-1", strategyName: nil, walletPublicId: "wallet-1")]
        mockAPI.fetchSignalsHandler = { unnamed }
        await viewModel.load()
        XCTAssertFalse(viewModel.showsStrategyFilter)
    }

    /// An entirely empty dataset leaves the export non-exportable — the
    /// control is rendered whenever the view model exists and driven to
    /// disabled by ``canExport``, never hidden.
    func testCanExportFalseOnEmptyDataset() async {
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.canExport)
        let empty: [TradingSignal] = []
        mockAPI.fetchSignalsHandler = { empty }
        await viewModel.load()
        XCTAssertTrue(viewModel.walletScopedSignals.isEmpty)
        XCTAssertFalse(viewModel.canExport)
    }

    /// Stats follow the strategy-filtered list, matching the web summary
    /// tiles which recompute when the filter changes.
    func testStatsFollowStrategyFilter() async {
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = makeViewModel()
        let rows = [
            makeSignal(publicId: "s-1", side: "buy", strength: 0.9, strategyName: "momentum", walletPublicId: "wallet-1"),
            makeSignal(publicId: "s-2", side: "sell", strength: 0.5, strategyName: "reversion", walletPublicId: "wallet-1"),
        ]
        mockAPI.fetchSignalsHandler = { rows }
        await viewModel.load()
        viewModel.selectedStrategy = "momentum"
        XCTAssertEqual(viewModel.stats, SignalStats(total: 1, buy: 1, sell: 0, averageStrength: 0.9))
    }

    /// The export is disabled while there are no filtered rows and
    /// enabled once the filter admits at least one.
    func testCanExportReflectsFilteredRows() async {
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.canExport)
        let rows = [makeSignal(publicId: "s-1", strategyName: "momentum", walletPublicId: "wallet-1")]
        mockAPI.fetchSignalsHandler = { rows }
        await viewModel.load()
        XCTAssertTrue(viewModel.canExport)
        viewModel.selectedStrategy = "ghost"
        XCTAssertFalse(viewModel.canExport)
    }
}

private actor SignalsReloadCounter {
    var value: Int = 0
    func increment() { value += 1 }
}

/// Gate that suspends the first ``wait()`` until ``release()``. Models a
/// slow / suspended initial load so a test can cancel the enclosing task
/// mid-load deterministically.
private actor SignalsLoadGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
