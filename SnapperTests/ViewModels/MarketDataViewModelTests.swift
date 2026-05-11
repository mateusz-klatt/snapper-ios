import XCTest
@testable import Snapper

@MainActor
final class MarketDataViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!
    private var webSocketManager: WebSocketManager!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
        webSocketManager = WebSocketManager(
            authService: FakeAuthService(nextToken: "test-token"),
            taskFactory: FakeWebSocketTaskFactory(task: FakeWebSocketTask()),
            sleeper: FakeSleeper()
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
}
