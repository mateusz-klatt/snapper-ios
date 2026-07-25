import XCTest
@testable import Snapper

private struct PnlUnexpectedError: Error {}

/// Arguments captured from each ``fetchPnlSeries`` call — the handler
/// closure is ``@Sendable`` so it cannot capture a plain test-local
/// ``var``. Also records the call count for one-fetch assertions.
private struct PnlFetchArgs: Sendable {
    let walletPublicId: String
    let mode: String
    let granularity: String
    let from: Date
    let to: Date
    let valuationCcy: String
}

private final class ArgsRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [PnlFetchArgs] = []
    func record(_ args: PnlFetchArgs) { lock.withLock { calls.append(args) } }
    var count: Int { lock.withLock { calls.count } }
    var last: PnlFetchArgs? { lock.withLock { calls.last } }
}

/// One-shot async gate used to interleave two loads deterministically.
private final class AsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false
    func wait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if isOpen {
                lock.unlock()
                continuation.resume()
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }
    func open() {
        lock.lock()
        isOpen = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.withLock { value += 1; return value } }
}

@MainActor
final class PnlTimelineViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    private static let base = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() {
        mockAPI = nil
        super.tearDown()
    }

    private func makeAppState() -> AppState {
        return AppState(userDefaults: UserDefaults(suiteName: "pnl-\(UUID().uuidString)")!)
    }

    private func makeWallet(publicId: String = "wallet-1", isPaper: Bool = false) -> WalletInfo {
        return WalletInfo(
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.base,
            sessionId: "session-1",
            label: "Main",
            isPaper: isPaper
        )
    }

    private func makePoint(
        net: Double? = 12.0,
        status: PnlValuationStatus = .complete
    ) -> PnlTimelinePointData {
        return PnlTimelinePointData(
            pointTime: Self.base,
            realizedPnl: 10.0,
            feePnl: -0.5,
            accrualPnl: 0.0,
            unrealizedPnl: 2.5,
            netPnl: net,
            equity: nil,
            cash: nil,
            positionValue: nil,
            drawdown: nil,
            valuationStatus: status,
            incompletenessReasons: [],
            perInstrument: [],
            attribution: []
        )
    }

    private func makeSeries(points: [PnlTimelinePointData]) -> PnlSeriesData {
        return PnlSeriesData(
            sequenceId: 1,
            publicId: "pnl-1",
            timestamp: Self.base,
            sessionId: "session-1",
            walletPublicId: "wallet-1",
            mode: "live",
            granularity: "1h",
            valuationCcy: "USD",
            fromTime: Self.base,
            toTime: Self.base,
            asOf: Self.base,
            markSource: "finalized_1m_candle_close",
            rateSources: [],
            calcVersion: "5A.13",
            equityCoverage: PnlEquityCoverageData(
                sampled: false,
                venueScope: nil,
                externalFlowsAdjusted: nil,
                completeMinutes: 0,
                firstMinute: nil,
                lastMinute: nil,
                sampleCalcVersion: nil
            ),
            /// #184 regenerated ``PnlSeriesData`` with a REQUIRED
            /// ``execution_history``. The uncorrected default keeps every
            /// existing expectation about these fixtures intact.
            executionHistory: PnlExecutionHistoryData(status: .asRecorded, corrections: []),
            points: points
        )
    }

    private func selectedAppState(isPaper: Bool = false) -> AppState {
        let appState = makeAppState()
        appState.availableWallets = [makeWallet(isPaper: isPaper)]
        appState.selectedWalletPublicId = "wallet-1"
        return appState
    }

    func testInitialStateIsEmpty() {
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: makeAppState())
        XCTAssertNil(viewModel.data)
        XCTAssertNil(viewModel.freshData)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.window, .h24)
        XCTAssertEqual(viewModel.granularity, .m1)
        XCTAssertEqual(viewModel.valuationCcy, "USD")
    }

    func testLoadHappyPathPopulatesData() async {
        let series = makeSeries(points: [makePoint()])
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in series }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: selectedAppState())
        await viewModel.load()
        XCTAssertEqual(viewModel.points.count, 1)
        XCTAssertEqual(viewModel.freshData?.points.first?.netPnl, 12.0)
        XCTAssertNil(viewModel.loadError)
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadWithoutWalletClearsDataAndSkipsFetch() async {
        let series = makeSeries(points: [makePoint()])
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in series }
        let appState = makeAppState()
        appState.selectedWalletPublicId = nil
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: appState)
        await viewModel.load()
        XCTAssertNil(viewModel.data)
        XCTAssertNil(viewModel.freshData)
        XCTAssertNil(viewModel.loadError)
    }

    func testLoadDerivesPaperModeFromWalletCache() async {
        let recorder = ArgsRecorder()
        let series = makeSeries(points: [makePoint()])
        mockAPI.fetchPnlSeriesHandler = { wallet, mode, granularity, from, to, ccy in
            recorder.record(PnlFetchArgs(
                walletPublicId: wallet, mode: mode, granularity: granularity,
                from: from, to: to, valuationCcy: ccy
            ))
            return series
        }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: selectedAppState(isPaper: true))
        await viewModel.load()
        XCTAssertEqual(recorder.last?.mode, "paper")
    }

    func testLoadFetchesWalletsWhenModeNotCached() async {
        let recorder = ArgsRecorder()
        let series = makeSeries(points: [makePoint()])
        mockAPI.fetchPnlSeriesHandler = { wallet, mode, granularity, from, to, ccy in
            recorder.record(PnlFetchArgs(
                walletPublicId: wallet, mode: mode, granularity: granularity,
                from: from, to: to, valuationCcy: ccy
            ))
            return series
        }
        let paperWallet = makeWallet(isPaper: true)
        mockAPI.fetchWalletsHandler = { [paperWallet] }
        let appState = makeAppState()
        appState.selectedWalletPublicId = "wallet-1"
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: appState)
        await viewModel.load()
        XCTAssertEqual(recorder.last?.mode, "paper")
        XCTAssertEqual(appState.availableWallets.count, 1)
        XCTAssertNil(viewModel.loadError)
    }

    func testFetchArgumentsPinInclusiveBoundsAndReanchor() async throws {
        let recorder = ArgsRecorder()
        let series = makeSeries(points: [makePoint()])
        mockAPI.fetchPnlSeriesHandler = { wallet, mode, granularity, from, to, ccy in
            recorder.record(PnlFetchArgs(
                walletPublicId: wallet, mode: mode, granularity: granularity,
                from: from, to: to, valuationCcy: ccy
            ))
            return series
        }
        let anchor0 = Date(timeIntervalSince1970: 10_000_000)
        var clock = anchor0
        let viewModel = PnlTimelineViewModel(
            api: mockAPI,
            appState: selectedAppState(isPaper: true),
            now: { clock }
        )
        await viewModel.load()
        let first = try XCTUnwrap(recorder.last)
        XCTAssertEqual(first.mode, "paper")
        XCTAssertEqual(first.granularity, "1m")
        XCTAssertEqual(first.valuationCcy, "USD")
        XCTAssertEqual(first.to, anchor0)
        XCTAssertEqual(first.from, anchor0.addingTimeInterval(-PnlTimelineWindow.h24.duration))

        clock = anchor0.addingTimeInterval(3_600)
        viewModel.window = .d7
        await viewModel.load()
        let second = try XCTUnwrap(recorder.last)
        XCTAssertEqual(second.to, clock, "Window change re-anchors to the new now()")
        XCTAssertEqual(second.from, clock.addingTimeInterval(-PnlTimelineWindow.d7.duration))
        XCTAssertEqual(second.granularity, "5m", "d7 window coarsens 1m to 5m")
    }

    func testSingleFetchPerLoad() async {
        let recorder = ArgsRecorder()
        let series = makeSeries(points: [makePoint()])
        mockAPI.fetchPnlSeriesHandler = { wallet, mode, granularity, from, to, ccy in
            recorder.record(PnlFetchArgs(
                walletPublicId: wallet, mode: mode, granularity: granularity,
                from: from, to: to, valuationCcy: ccy
            ))
            return series
        }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: selectedAppState())
        await viewModel.load()
        XCTAssertEqual(recorder.count, 1, "One load must issue exactly one fetch")
    }

    func testLoadKeyIsDistinctPerControl() {
        let base = PnlTimelineLoadKey(wallet: "w", window: .h24, granularity: .m1, valuationCcy: "USD")
        XCTAssertEqual(base, PnlTimelineLoadKey(wallet: "w", window: .h24, granularity: .m1, valuationCcy: "USD"))
        XCTAssertNotEqual(base, PnlTimelineLoadKey(wallet: "w", window: .d7, granularity: .m1, valuationCcy: "USD"))
        XCTAssertNotEqual(base, PnlTimelineLoadKey(wallet: "w", window: .h24, granularity: .m5, valuationCcy: "USD"))
        XCTAssertNotEqual(base, PnlTimelineLoadKey(wallet: "w", window: .h24, granularity: .m1, valuationCcy: "EUR"))
        XCTAssertNotEqual(base, PnlTimelineLoadKey(wallet: "x", window: .h24, granularity: .m1, valuationCcy: "USD"))
        XCTAssertNotEqual(base, PnlTimelineLoadKey(wallet: nil, window: .h24, granularity: .m1, valuationCcy: "USD"))
    }

    func testLoadFailureSetsTypedLoadError() async {
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in throw APIError.serverError("budget exceeded") }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: selectedAppState())
        await viewModel.load()
        XCTAssertNil(viewModel.freshData)
        guard case .serverError(let detail) = viewModel.currentError else {
            return XCTFail("Expected serverError, got \(String(describing: viewModel.currentError))")
        }
        XCTAssertEqual(detail, "budget exceeded")
    }

    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in throw PnlUnexpectedError() }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: selectedAppState())
        await viewModel.load()
        guard case .invalidResponse = viewModel.currentError else {
            return XCTFail("Expected invalidResponse fallback, got \(String(describing: viewModel.currentError))")
        }
    }

    func testCancellationDoesNotSurfaceAnError() async {
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in throw CancellationError() }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: selectedAppState())
        await viewModel.load()
        XCTAssertNil(viewModel.loadError, "A cancellation must not become a load error")
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadClearsPreviousError() async {
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: selectedAppState())
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.currentError)

        let series = makeSeries(points: [makePoint()])
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in series }
        await viewModel.load()
        XCTAssertNil(viewModel.currentError)
        XCTAssertEqual(viewModel.points.count, 1)
    }

    func testSameKeyRefreshFailureKeepsDataAndSurfacesInlineError() async {
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: selectedAppState())
        let series = makeSeries(points: [makePoint()])
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in series }
        await viewModel.load()
        XCTAssertNotNil(viewModel.freshData)

        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in throw APIError.serverError("work budget") }
        await viewModel.load()
        XCTAssertEqual(viewModel.points.count, 1, "Cached series survives a same-parameters refresh failure")
        guard case .serverError(let detail) = viewModel.currentError else {
            return XCTFail("Expected inline serverError, got \(String(describing: viewModel.currentError))")
        }
        XCTAssertEqual(detail, "work budget")
        XCTAssertFalse(
            PnlTimelineViewModel.shouldShowLoadError(
                hasData: viewModel.freshData != nil,
                loadError: viewModel.currentError,
                isLoading: viewModel.isLoading
            )
        )
    }

    func testStaleDataHiddenAfterParameterChange() async {
        let appState = selectedAppState()
        let usdSeries = makeSeries(points: [makePoint(net: 1.0)])
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in usdSeries }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: appState)
        await viewModel.load()
        XCTAssertNotNil(viewModel.freshData)

        viewModel.valuationCcy = "EUR"
        XCTAssertNil(viewModel.freshData, "The USD payload must not be shown for an EUR request")
        XCTAssertTrue(viewModel.points.isEmpty)
        XCTAssertNil(viewModel.currentError)

        let eurSeries = makeSeries(points: [makePoint(net: 2.0), makePoint(net: 3.0)])
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in eurSeries }
        await viewModel.load()
        XCTAssertEqual(viewModel.points.count, 2)
        XCTAssertNotNil(viewModel.freshData)
    }

    func testStaleErrorHiddenAfterParameterChange() async {
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: selectedAppState())
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in throw APIError.serverError("boom") }
        await viewModel.load()
        XCTAssertNotNil(viewModel.currentError)

        viewModel.valuationCcy = "EUR"
        XCTAssertNil(viewModel.currentError, "An error for the USD request must not apply to the EUR request")
    }

    func testStaleLoadDoesNotOverwriteNewerData() async {
        let appState = selectedAppState()
        let seriesA = makeSeries(points: [makePoint(net: 1.0)])
        let seriesB = makeSeries(points: [makePoint(net: 2.0)])
        let gate = AsyncGate()
        let firstStarted = AsyncGate()
        let counter = CallCounter()
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in
            if counter.next() == 1 {
                firstStarted.open()
                await gate.wait()
                return seriesA
            }
            return seriesB
        }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: appState)
        let first = Task { await viewModel.load() }
        await firstStarted.wait()
        await viewModel.load()
        gate.open()
        await first.value
        XCTAssertEqual(viewModel.data?.points.first?.netPnl, 2.0, "The newer load must own the committed data")
        XCTAssertNil(viewModel.loadError)
    }

    func testEmptyPointsRefreshFailureStillSurfacesInlineError() async {
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: selectedAppState())
        let emptySeries = makeSeries(points: [])
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in emptySeries }
        await viewModel.load()
        XCTAssertNotNil(viewModel.freshData, "An empty-points payload is still fresh data")
        XCTAssertTrue(viewModel.points.isEmpty)

        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in throw APIError.serverError("empty window budget") }
        await viewModel.load()
        XCTAssertNotNil(viewModel.freshData, "Empty cached data is retained on a same-key refresh failure")
        guard case .serverError(let detail) = viewModel.currentError else {
            return XCTFail("Expected inline serverError over empty data, got \(String(describing: viewModel.currentError))")
        }
        XCTAssertEqual(detail, "empty window budget")
    }

    func testUnresolvedWalletErrorIsUniquelyKeyed() async {
        let appState = makeAppState()
        appState.selectedWalletPublicId = "wallet-A"
        mockAPI.fetchWalletsHandler = { throw APIError.httpError(403) }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: appState)
        await viewModel.load()
        XCTAssertNotNil(viewModel.currentError, "The unresolved wallet-A request surfaces an error")

        appState.selectedWalletPublicId = "wallet-B"
        XCTAssertNil(viewModel.currentError, "wallet-A's error must not leak onto the uncached wallet-B request")
    }

    func testObsoleteWalletResolutionDoesNotOverwriteNewerCache() async {
        let appState = makeAppState()
        appState.selectedWalletPublicId = "wallet-1"
        let walletOld = makeWallet(isPaper: false)
        let walletNew = makeWallet(isPaper: true)
        let series = makeSeries(points: [makePoint()])
        let gate = AsyncGate()
        let firstStarted = AsyncGate()
        let counter = CallCounter()
        mockAPI.fetchWalletsHandler = {
            if counter.next() == 1 {
                firstStarted.open()
                await gate.wait()
                return [walletOld]
            }
            return [walletNew]
        }
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in series }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: appState)
        let first = Task { await viewModel.load() }
        await firstStarted.wait()
        await viewModel.load()
        gate.open()
        await first.value
        XCTAssertEqual(appState.availableWallets.count, 1)
        XCTAssertEqual(
            appState.availableWallets.first?.isPaper, true,
            "The newer wallet resolution wins; the obsolete one must not overwrite the cache"
        )
    }

    func testCancelledCurrentGenerationClearsLoadingWithoutCommit() async {
        let appState = selectedAppState()
        let series = makeSeries(points: [makePoint()])
        let gate = AsyncGate()
        let started = AsyncGate()
        mockAPI.fetchPnlSeriesHandler = { _, _, _, _, _, _ in
            started.open()
            await gate.wait()
            return series
        }
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: appState)
        let task = Task { await viewModel.load() }
        await started.wait()
        task.cancel()
        gate.open()
        await task.value
        XCTAssertFalse(viewModel.isLoading, "A cancelled current-generation load must clear isLoading")
        XCTAssertNil(viewModel.data, "No data is committed when the current generation was cancelled")
        XCTAssertNil(viewModel.loadError, "A cancellation is never surfaced as an error")
        XCTAssertNil(viewModel.freshData)
    }

    func testWindowChangeReanchorsAndCoarsens() {
        var clock = Date(timeIntervalSince1970: 1_000)
        let viewModel = PnlTimelineViewModel(
            api: mockAPI,
            appState: makeAppState(),
            now: { clock }
        )
        XCTAssertEqual(viewModel.anchor, Date(timeIntervalSince1970: 1_000))
        clock = Date(timeIntervalSince1970: 5_000)
        viewModel.window = .d30
        XCTAssertEqual(viewModel.anchor, Date(timeIntervalSince1970: 5_000))
        XCTAssertEqual(viewModel.granularity, .h1, "d30 window must coarsen 1m to at least 1h")
    }

    func testWindowChangeNeverFinerThanCurrent() {
        let viewModel = PnlTimelineViewModel(api: mockAPI, appState: makeAppState())
        viewModel.granularity = .d1
        viewModel.window = .d7
        XCTAssertEqual(viewModel.granularity, .d1, "A coarser manual pick must not be reset finer")
    }

    func testDefaultGranularityTruthTable() {
        XCTAssertEqual(PnlTimelineViewModel.defaultGranularity(for: .h24, current: .m1), .m1)
        XCTAssertEqual(PnlTimelineViewModel.defaultGranularity(for: .h24, current: .d1), .d1)
        XCTAssertEqual(PnlTimelineViewModel.defaultGranularity(for: .d7, current: .m1), .m5)
        XCTAssertEqual(PnlTimelineViewModel.defaultGranularity(for: .d7, current: .h1), .h1)
        XCTAssertEqual(PnlTimelineViewModel.defaultGranularity(for: .d30, current: .m1), .h1)
        XCTAssertEqual(PnlTimelineViewModel.defaultGranularity(for: .d30, current: .m5), .h1)
        XCTAssertEqual(PnlTimelineViewModel.defaultGranularity(for: .d90, current: .h1), .h1)
        XCTAssertEqual(PnlTimelineViewModel.defaultGranularity(for: .d90, current: .d1), .d1)
    }

    func testWindowDurations() {
        XCTAssertEqual(PnlTimelineWindow.h24.duration, 24 * 60 * 60)
        XCTAssertEqual(PnlTimelineWindow.d7.duration, 7 * 24 * 60 * 60)
        XCTAssertEqual(PnlTimelineWindow.d30.duration, 30 * 24 * 60 * 60)
        XCTAssertEqual(PnlTimelineWindow.d90.duration, 90 * 24 * 60 * 60)
    }

    func testGranularityWireValues() {
        XCTAssertEqual(PnlTimelineGranularity.m1.wireValue, "1m")
        XCTAssertEqual(PnlTimelineGranularity.m5.wireValue, "5m")
        XCTAssertEqual(PnlTimelineGranularity.h1.wireValue, "1h")
        XCTAssertEqual(PnlTimelineGranularity.d1.wireValue, "1d")
    }

    func testModeString() {
        XCTAssertEqual(PnlTimelineViewModel.modeString(isPaper: true), "paper")
        XCTAssertEqual(PnlTimelineViewModel.modeString(isPaper: false), "live")
    }

    func testShouldShowLoadError() {
        XCTAssertFalse(PnlTimelineViewModel.shouldShowLoadError(hasData: false, loadError: nil, isLoading: false))
        XCTAssertFalse(PnlTimelineViewModel.shouldShowLoadError(hasData: false, loadError: .invalidResponse, isLoading: true))
        XCTAssertFalse(PnlTimelineViewModel.shouldShowLoadError(hasData: true, loadError: .invalidResponse, isLoading: false))
        XCTAssertTrue(PnlTimelineViewModel.shouldShowLoadError(hasData: false, loadError: .invalidResponse, isLoading: false))
    }
}
