import XCTest
@testable import Snapper

@MainActor
final class MarketDataViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!
    private var webSocketManager: WebSocketManager!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
        /// Default empty cached-candles response — the metrics fetch
        /// migrated from ``fetchCandles`` to ``fetchCachedCandles``,
        /// so every test that exercises ``selectInstrument`` (which
        /// triggers ``fetchChartAndMetrics``) needs this handler
        /// stubbed. Tests that care about specific cache state
        /// override per-test.
        mockAPI.fetchCachedCandlesHandler = { _, _, _, _ in
            return Self.makeEmptyCachedCandlesResponse()
        }
        webSocketManager = WebSocketManager(
            authService: FakeAuthService(nextToken: "test-token"),
            taskFactory: FakeWebSocketTaskFactory(task: FakeWebSocketTask()),
            sleeper: FakeSleeper()
        )
    }

    nonisolated private static func makeEmptyCachedCandlesResponse() -> CachedCandlesResponse {
        return makeCachedCandlesResponse(isWarm: true, sampleCount: 0, source: "cache")
    }

    /// Parametrised builder for ``CachedCandlesResponse`` so the
    /// chart-cache vs metrics ownership tests can stub each
    /// timeframe branch with distinct cache-state metadata.
    nonisolated private static func makeCachedCandlesResponse(
        isWarm: Bool,
        sampleCount: Int,
        source: String
    ) -> CachedCandlesResponse {
        return CachedCandlesResponse(
            type: "cached_candles_response",
            sequenceId: 1,
            publicId: "cached-stub",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            sessionId: "session-test",
            topic: nil,
            payload: CachedCandlesPayload(
                candles: [],
                sampleCount: sampleCount,
                isWarm: isWarm,
                source: source
            )
        )
    }

    override func tearDown() {
        mockAPI = nil
        webSocketManager = nil
        super.tearDown()
    }

    private func makeViewModel() -> MarketDataViewModel {
        return MarketDataViewModel(api: mockAPI, webSocketManager: webSocketManager)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeInstrument(
        symbol: String,
        exchange: String = "kraken",
        publicId: String? = nil
    ) -> InstrumentDetailData {
        return InstrumentDetailData(
            type: "instrument_detail_data",
            sequenceId: 1,
            publicId: publicId ?? "inst-\(symbol)",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            instrumentPublicId: "instpid-\(symbol)",
            symbolPublicId: "sympid-\(symbol)",
            symbol: symbol,
            exchange: exchange,
            canTrade: true,
            canMarketData: true,
            instrumentResolved: true,
            instrumentKind: "spot",
            expiryAt: nil
        )
    }

    func testDefaultTimeframeIsOneMinute() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.selectedTimeframe, .oneMinute)
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.selectedExchange)
        XCTAssertNil(viewModel.selectedInstrument)
        XCTAssertTrue(viewModel.exchanges.isEmpty)
        XCTAssertTrue(viewModel.instruments.isEmpty)
        XCTAssertTrue(viewModel.candles.isEmpty)
        XCTAssertFalse(viewModel.isReady)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
    }

    func testLoadExchangesPicksKrakenWhenAvailable() async {
        mockAPI.fetchExchangesHandler = { ["binance", "kraken", "coinbase"] }
        mockAPI.fetchInstrumentsHandler = { _ in [] }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertEqual(viewModel.selectedExchange, "kraken")
        XCTAssertEqual(viewModel.exchanges, ["binance", "kraken", "coinbase"])
    }

    func testLoadExchangesFallsBackToFirstWhenNoKraken() async {
        mockAPI.fetchExchangesHandler = { ["binance", "coinbase"] }
        mockAPI.fetchInstrumentsHandler = { _ in [] }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertEqual(viewModel.selectedExchange, "binance")
    }

    func testLoadExchangesEmptyListLeavesSelectionNil() async {
        mockAPI.fetchExchangesHandler = { [] }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertNil(viewModel.selectedExchange)
        XCTAssertTrue(viewModel.exchanges.isEmpty)
    }

    func testLoadExchangesApiErrorSetsLoadError() async {
        mockAPI.fetchExchangesHandler = { throw APIError.serverError("offline") }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertNil(viewModel.selectedExchange)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadExchangesServerErrorSetsLoadError() async {
        struct GenericError: Error {}
        mockAPI.fetchExchangesHandler = { throw GenericError() }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testAutoPickPrefersBTCUSDOverBTCUSDPerp() async {
        let perp = makeInstrument(symbol: "BTC-USD-PERP", exchange: "kraken")
        let spot = makeInstrument(symbol: "BTC-USD", exchange: "kraken")
        let alt = makeInstrument(symbol: "ETH-USD", exchange: "kraken")
        mockAPI.fetchExchangesHandler = { ["kraken"] }
        mockAPI.fetchInstrumentsHandler = { _ in [perp, alt, spot] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "BTC-USD")
    }

    func testAutoPickFallsBackToBTCUSDPerpWhenNoBTCUSD() async {
        let perp = makeInstrument(symbol: "BTC-USD-PERP", exchange: "kraken")
        let alt = makeInstrument(symbol: "ETH-USD", exchange: "kraken")
        mockAPI.fetchExchangesHandler = { ["kraken"] }
        mockAPI.fetchInstrumentsHandler = { _ in [alt, perp] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "BTC-USD-PERP")
    }

    func testAutoPickFallsBackToFirstWhenNeitherBTCAvailable() async {
        let alt1 = makeInstrument(symbol: "ETH-USD", exchange: "kraken")
        let alt2 = makeInstrument(symbol: "SOL-USD", exchange: "kraken")
        mockAPI.fetchExchangesHandler = { ["kraken"] }
        mockAPI.fetchInstrumentsHandler = { _ in [alt1, alt2] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "ETH-USD")
    }

    func testAutoPickNoOpWhenInstrumentsListEmpty() async {
        mockAPI.fetchExchangesHandler = { ["kraken"] }
        mockAPI.fetchInstrumentsHandler = { _ in [] }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertEqual(viewModel.selectedExchange, "kraken")
        XCTAssertNil(viewModel.selectedInstrument)
    }

    private func makeInstrumentWithMarketData(
        symbol: String,
        exchange: String = "kraken",
        canMarketData: Bool
    ) -> InstrumentDetailData {
        return InstrumentDetailData(
            type: "instrument_detail_data",
            sequenceId: 1,
            publicId: "inst-\(symbol)",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            instrumentPublicId: "instpid-\(symbol)",
            symbolPublicId: "sympid-\(symbol)",
            symbol: symbol,
            exchange: exchange,
            canTrade: true,
            canMarketData: canMarketData,
            instrumentResolved: true,
            instrumentKind: "spot",
            expiryAt: nil
        )
    }

    func testAutoPickIgnoresInstrumentsWithoutMarketData() async {
        let noMD = makeInstrumentWithMarketData(symbol: "BTC-USD", canMarketData: false)
        let withMD = makeInstrument(symbol: "ETH-USD", exchange: "kraken")
        mockAPI.fetchExchangesHandler = { ["kraken"] }
        mockAPI.fetchInstrumentsHandler = { _ in [noMD, withMD] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "ETH-USD")
    }

    func testSelectExchangeClearsInstrumentAndReloads() async {
        let btc = makeInstrument(symbol: "BTC-USD", exchange: "kraken")
        let eth = makeInstrument(symbol: "ETH-USD", exchange: "binance")
        mockAPI.fetchExchangesHandler = { ["kraken", "binance"] }
        mockAPI.fetchInstrumentsHandler = { exchange in
            return exchange == "kraken" ? [btc] : [eth]
        }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "BTC-USD")
        await viewModel.selectExchange("binance")
        XCTAssertEqual(viewModel.selectedExchange, "binance")
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "ETH-USD")
    }

    func testSelectInstrumentResetsCandlesAndMetrics() async {
        let btc = makeInstrument(symbol: "BTC-USD", exchange: "kraken")
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        let viewModel = makeViewModel()
        await viewModel.selectInstrument(btc)
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "BTC-USD")
        XCTAssertEqual(viewModel.metrics, .empty)
        XCTAssertTrue(viewModel.candles.isEmpty)
        XCTAssertFalse(viewModel.showInstrumentPicker)
    }

    func testSelectTimeframeWhenNoInstrumentJustUpdatesField() async {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.selectedTimeframe, .oneMinute)
        await viewModel.selectTimeframe(.fifteenMinutes)
        XCTAssertEqual(viewModel.selectedTimeframe, .fifteenMinutes)
        XCTAssertNil(viewModel.selectedInstrument)
    }

    func testSelectTimeframeWithInstrumentUpdatesField() async {
        let btc = makeInstrument(symbol: "BTC-USD", exchange: "kraken")
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        let viewModel = makeViewModel()
        await viewModel.selectInstrument(btc)
        await viewModel.selectTimeframe(.fifteenMinutes)
        XCTAssertEqual(viewModel.selectedTimeframe, .fifteenMinutes)
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "BTC-USD")
    }

    func testStopClearsObservationTasks() {
        let viewModel = makeViewModel()
        viewModel.stop()
        XCTAssertFalse(viewModel.isLoading)
    }

    func testInstrumentFilterDropsCanMarketDataFalse() async {
        let falseMD = makeInstrumentWithMarketData(symbol: "FAKE-USD", canMarketData: false)
        mockAPI.fetchExchangesHandler = { ["kraken"] }
        mockAPI.fetchInstrumentsHandler = { _ in [falseMD] }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertTrue(viewModel.instruments.isEmpty)
        XCTAssertNil(viewModel.selectedInstrument)
    }

    nonisolated private static func makeRelatedResponse(
        exchange: String,
        symbol: String,
        description: String = "Test description."
    ) -> RelatedInstrumentsResponse {
        return RelatedInstrumentsResponse(
            type: "related_instruments_response",
            sequenceId: 1,
            publicId: "related-\(symbol)",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            sessionId: "session-test",
            topic: nil,
            payload: RelatedInstrumentsPayloadData(
                selected: RelatedInstrumentsSelected(
                    exchange: exchange,
                    nativeSymbol: symbol
                ),
                underlying: RelatedInstrumentsUnderlying(
                    publicId: "underlying-\(symbol)",
                    ticker: symbol,
                    name: "\(symbol) Test Name",
                    assetClass: "commodity",
                    sector: "Precious Metals",
                    description: description
                ),
                groups: []
            )
        )
    }

    func testSelectInstrumentPopulatesRelatedResponse() async {
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["polygon"] }
        mockAPI.fetchInstrumentsHandler = { _ in [gld] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            return Self.makeRelatedResponse(exchange: exchange, symbol: symbol)
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        await viewModel.selectInstrument(gld)
        XCTAssertEqual(viewModel.relatedResponse?.payload.selected.nativeSymbol, "GLD")
        XCTAssertEqual(viewModel.relatedResponse?.payload.underlying?.description, "Test description.")
        XCTAssertFalse(viewModel.isLoadingRelated)
    }

    func testSelectInstrumentDoesNotFailOnRelatedFetchError() async {
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["polygon"] }
        mockAPI.fetchInstrumentsHandler = { _ in [gld] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        mockAPI.fetchRelatedInstrumentsHandler = { _, _ in
            throw APIError.serverError("temporary outage")
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        await viewModel.selectInstrument(gld)
        XCTAssertNil(viewModel.relatedResponse, "Related fetch failure must leave relatedResponse nil, not crash the selection.")
        XCTAssertTrue(viewModel.isReady, "Chart + metrics must still surface even when related fetch fails.")
        XCTAssertNil(viewModel.loadError, "Related fetch failure is non-fatal and must not poison loadError.")
        XCTAssertFalse(viewModel.isLoadingRelated)
    }

    func testSelectMarketSameExchangeLoadsInstrument() async {
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        let slv = makeInstrument(symbol: "SLV", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["polygon"] }
        mockAPI.fetchInstrumentsHandler = { _ in [gld, slv] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            return Self.makeRelatedResponse(exchange: exchange, symbol: symbol)
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        await viewModel.selectInstrument(gld)
        await viewModel.selectMarket(exchange: "polygon", symbol: "SLV")
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "SLV")
        XCTAssertNil(viewModel.marketSelectionError)
    }

    func testSelectMarketCrossExchangeSwitchesExchangeFirst() async {
        let btc = makeInstrument(symbol: "BTC-USD", exchange: "kraken")
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["kraken", "polygon"] }
        mockAPI.fetchInstrumentsHandler = { exchange in
            return exchange == "kraken" ? [btc] : [gld]
        }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            return Self.makeRelatedResponse(exchange: exchange, symbol: symbol)
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertEqual(viewModel.selectedExchange, "kraken")
        await viewModel.selectMarket(exchange: "polygon", symbol: "GLD")
        XCTAssertEqual(viewModel.selectedExchange, "polygon")
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "GLD")
        XCTAssertNil(viewModel.marketSelectionError)
    }

    func testSelectMarketUnknownSymbolSetsError() async {
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["polygon"] }
        mockAPI.fetchInstrumentsHandler = { _ in [gld] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            return Self.makeRelatedResponse(exchange: exchange, symbol: symbol)
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        await viewModel.selectMarket(exchange: "polygon", symbol: "NOTREAL")
        XCTAssertEqual(
            viewModel.marketSelectionError,
            .instrumentNotFound(exchange: "polygon", symbol: "NOTREAL")
        )
    }

    /// Both cache endpoints (chart-cache probe AND metrics probe)
    /// fail in the same selection cycle. The chart must still
    /// surface from the smart-route ``fetchCandles`` fetch and
    /// neither failure may poison ``loadError`` — both are
    /// best-effort signals.
    func testCachedEndpointFailureDoesNotBlankChart() async {
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["polygon"] }
        mockAPI.fetchInstrumentsHandler = { _ in [gld] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        mockAPI.fetchCachedCandlesHandler = { _, _, _, _ in
            throw APIError.serverError("metrics cache temporarily unavailable")
        }
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            return Self.makeRelatedResponse(exchange: exchange, symbol: symbol)
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        await viewModel.selectInstrument(gld)
        XCTAssertTrue(
            viewModel.isReady,
            "Chart must surface even when the metrics cache endpoint is unavailable."
        )
        XCTAssertNil(
            viewModel.loadError,
            "Metrics cache failure is best-effort and must not poison loadError."
        )
        XCTAssertNil(
            viewModel.cacheState,
            "Cache state stays nil when the metrics cache fetch fails; banner stays hidden."
        )
    }

    /// Selected timeframe is .fiveMinutes (chart-cache probe runs
    /// with timeframe=5m, limit=19). Metrics probe stays at 1h/25
    /// regardless. ``cacheState`` MUST come from the chart-cache
    /// probe (5m/limit=19 response, ``is_warm=false``,
    /// ``sample_count=10``) NOT from the metrics probe (1h/25
    /// response, ``is_warm=true``, ``sample_count=25``).
    func testCacheStateOwnedByChartProbeNotMetricsProbe() async {
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["polygon"] }
        mockAPI.fetchInstrumentsHandler = { _ in [gld] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            return Self.makeRelatedResponse(exchange: exchange, symbol: symbol)
        }
        mockAPI.fetchCachedCandlesHandler = { _, _, tf, _ in
            if tf == .fiveMinutes {
                return Self.makeCachedCandlesResponse(isWarm: false, sampleCount: 10, source: "cache")
            }
            return Self.makeCachedCandlesResponse(isWarm: true, sampleCount: 25, source: "cache")
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        viewModel.selectedTimeframe = .fiveMinutes
        await viewModel.selectInstrument(gld)
        XCTAssertEqual(
            viewModel.cacheState?.isWarm,
            false,
            "cacheState.isWarm must come from the chart-cache probe (.fiveMinutes), not metrics (.oneHour)."
        )
        XCTAssertEqual(
            viewModel.cacheState?.sampleCount,
            10,
            "cacheState.sampleCount must come from the chart-cache probe response."
        )
    }

    /// Metrics-probe failure must NOT clear ``cacheState`` —
    /// ownership belongs to the chart-cache probe, so a metrics
    /// outage is isolated from the warming banner.
    func testMetricsProbeFailureLeavesCacheStateIntact() async {
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["polygon"] }
        mockAPI.fetchInstrumentsHandler = { _ in [gld] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            return Self.makeRelatedResponse(exchange: exchange, symbol: symbol)
        }
        mockAPI.fetchCachedCandlesHandler = { _, _, tf, _ in
            if tf == .oneHour {
                throw APIError.serverError("metrics endpoint down")
            }
            return Self.makeCachedCandlesResponse(isWarm: false, sampleCount: 42, source: "cache")
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        await viewModel.selectInstrument(gld)
        XCTAssertEqual(
            viewModel.cacheState?.sampleCount,
            42,
            "cacheState must stay populated from the chart-cache probe when metrics fail in isolation."
        )
    }

    /// Chart-cache probe failure clears ``cacheState`` (banner
    /// hides) AND keeps the chart populated (smart-route fetch is
    /// independent and still succeeds). The smart-route fetch
    /// returns one synthetic candle so the test can prove the
    /// chart genuinely surfaced data, not just that ``isReady``
    /// flipped.
    func testChartCacheProbeFailureClearsCacheStateAndKeepsChart() async {
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        let stubCandle = MarketCandle(
            openAt: Date(timeIntervalSince1970: 1_700_000_000),
            open: 100,
            high: 101,
            low: 99,
            close: 100,
            volume: 10,
            vwap: nil,
            trades: nil
        )
        mockAPI.fetchExchangesHandler = { ["polygon"] }
        mockAPI.fetchInstrumentsHandler = { _ in [gld] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [stubCandle] }
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            return Self.makeRelatedResponse(exchange: exchange, symbol: symbol)
        }
        mockAPI.fetchCachedCandlesHandler = { _, _, tf, _ in
            if tf == .oneMinute {
                throw APIError.serverError("chart cache probe failed")
            }
            return Self.makeCachedCandlesResponse(isWarm: true, sampleCount: 25, source: "cache")
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        await viewModel.selectInstrument(gld)
        XCTAssertNil(
            viewModel.cacheState,
            "Chart-cache probe failure clears cacheState so the banner hides."
        )
        XCTAssertEqual(
            viewModel.candles.count,
            1,
            "Chart populated from smart-route /candles fetch — independent of the failed cache probe."
        )
    }

    func testSelectMarketCrossExchangeMissPreservesPriorSelection() async {
        let btc = makeInstrument(symbol: "BTC-USD", exchange: "kraken")
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["kraken", "polygon"] }
        mockAPI.fetchInstrumentsHandler = { exchange in
            return exchange == "kraken" ? [btc] : [gld]
        }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            return Self.makeRelatedResponse(exchange: exchange, symbol: symbol)
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        XCTAssertEqual(viewModel.selectedExchange, "kraken")
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "BTC-USD")

        await viewModel.selectMarket(exchange: "polygon", symbol: "NOTREAL")

        XCTAssertEqual(
            viewModel.marketSelectionError,
            .instrumentNotFound(exchange: "polygon", symbol: "NOTREAL")
        )
        XCTAssertEqual(
            viewModel.selectedExchange,
            "kraken",
            "Cross-exchange miss must NOT commit the venue switch."
        )
        XCTAssertEqual(
            viewModel.selectedInstrument?.symbol,
            "BTC-USD",
            "Cross-exchange miss must preserve the prior instrument."
        )
    }

    func testSelectMarketRecoveryClearsError() async {
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["polygon"] }
        mockAPI.fetchInstrumentsHandler = { _ in [gld] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            return Self.makeRelatedResponse(exchange: exchange, symbol: symbol)
        }
        let viewModel = makeViewModel()
        await viewModel.loadExchanges()
        await viewModel.selectMarket(exchange: "polygon", symbol: "NOTREAL")
        XCTAssertNotNil(viewModel.marketSelectionError)
        await viewModel.selectMarket(exchange: "polygon", symbol: "GLD")
        XCTAssertNil(viewModel.marketSelectionError)
        XCTAssertEqual(viewModel.selectedInstrument?.symbol, "GLD")
    }

    func testLocalePersistNotificationRefetchesRelated() async throws {
        let gld = makeInstrument(symbol: "GLD", exchange: "polygon")
        mockAPI.fetchExchangesHandler = { ["polygon"] }
        mockAPI.fetchInstrumentsHandler = { _ in [gld] }
        mockAPI.fetchCandlesHandler = { _, _, _, _, _ in [] }
        let fetchCount = RelatedFetchCounter()
        mockAPI.fetchRelatedInstrumentsHandler = { exchange, symbol in
            fetchCount.increment()
            return Self.makeRelatedResponse(
                exchange: exchange,
                symbol: symbol,
                description: "fetched-\(fetchCount.value)"
            )
        }
        let viewModel = makeViewModel()
        await viewModel.start()
        let baseline = fetchCount.value
        XCTAssertGreaterThan(baseline, 0, "Initial start+auto-pick must fetch related at least once.")

        NotificationCenter.default.post(
            name: .appStateLocaleDidPersist,
            object: nil,
            userInfo: ["language": "pl"]
        )

        let deadline = Date().addingTimeInterval(2.0)
        while fetchCount.value <= baseline, Date() < deadline {
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertGreaterThan(fetchCount.value, baseline, "Locale-persist notification must trigger an additional refetch.")
        XCTAssertEqual(viewModel.relatedResponse?.payload.underlying?.description, "fetched-\(fetchCount.value)")
        viewModel.stop()
    }
}

private final class RelatedFetchCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count: Int = 0
    func increment() {
        lock.withLock { count += 1 }
    }
    var value: Int {
        lock.withLock { count }
    }
}
