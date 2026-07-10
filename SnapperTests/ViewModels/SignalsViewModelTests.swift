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
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            instrument: instrument,
            exchange: exchange,
            side: side,
            strength: strength,
            reason: reason,
            price: price,
            strategyName: strategyName,
            firedAt: Self.baseTimestamp,
            walletPublicId: walletPublicId
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
}
