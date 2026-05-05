import XCTest
@testable import Snapper

/// Async / instance-state tests for `NewOrderSheetViewModel`.
///
/// Pure-helper coverage (canSubmit / buildBody / needsPrice /
/// needsStopPrice / makeCommand) lives in
/// `Views/NewOrderSheetTests.swift` and exercises the static
/// surface. The tests here drive the live VM through real async
/// branches: instrument loading, race-guard, sticky-error
/// recovery, submit re-entry, idempotency key stability across
/// retries.
@MainActor
final class NewOrderSheetViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() {
        mockAPI = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeViewModel(
        exchanges: [String] = ["kraken"],
        defaultExchange: String? = nil,
        walletIsPaper: Bool = false,
        idempotencyKey: String = "test-idempotency-key"
    ) -> NewOrderSheetViewModel {
        return NewOrderSheetViewModel(
            exchanges: exchanges,
            walletPublicId: "wallet-1",
            walletIsPaper: walletIsPaper,
            defaultExchange: defaultExchange,
            api: mockAPI,
            idempotencyKey: idempotencyKey
        )
    }

    private func makeInstrument(
        canTrade: Bool = true,
        instrumentPublicId: String = "inst-1",
        symbol: String = "BTC-USD",
        exchange: String = "kraken"
    ) -> InstrumentDetailData {
        return InstrumentDetailData(
            type: "instrument_detail",
            sequenceId: 1,
            publicId: "envelope-id",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            sessionId: "session-test",
            topic: nil,
            instrumentPublicId: instrumentPublicId,
            symbolPublicId: "sym-1",
            symbol: symbol,
            exchange: exchange,
            canTrade: canTrade,
            canMarketData: true,
            instrumentResolved: true,
            instrumentKind: "spot",
            expiryAt: nil
        )
    }

    // MARK: - Initialization

    func testInitialStateUsesFirstExchangeWhenNoDefault() {
        let viewModel = makeViewModel(exchanges: ["kraken", "binance"])
        XCTAssertEqual(viewModel.selectedExchange, "kraken")
        XCTAssertEqual(viewModel.idempotencyKey, "test-idempotency-key")
        XCTAssertNil(viewModel.selectedInstrument)
        XCTAssertEqual(viewModel.side, "buy")
        XCTAssertEqual(viewModel.orderType, "limit")
        XCTAssertFalse(viewModel.isLoadingInstruments)
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertNil(viewModel.loadError)
        XCTAssertTrue(viewModel.availableInstruments.isEmpty)
    }

    func testInitialStateUsesDefaultExchangeWhenProvided() {
        let viewModel = makeViewModel(
            exchanges: ["kraken", "binance"],
            defaultExchange: "binance"
        )
        XCTAssertEqual(viewModel.selectedExchange, "binance")
    }

    func testInitialStateUsesEmptyExchangeForEmptyExchangeList() {
        let viewModel = makeViewModel(exchanges: [])
        XCTAssertEqual(viewModel.selectedExchange, "")
    }

    // MARK: - loadInstruments — happy path + skip + failure

    func testLoadInstrumentsSuccessPopulatesAvailable() async {
        let viewModel = makeViewModel()
        let instrument = makeInstrument()
        mockAPI.fetchInstrumentsHandler = { _ in [instrument] }
        await viewModel.loadInstruments()
        XCTAssertEqual(viewModel.availableInstruments.count, 1)
        XCTAssertEqual(viewModel.availableInstruments.first?.instrumentPublicId, "inst-1")
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoadingInstruments)
    }

    func testLoadInstrumentsSkipsForEmptySelectedExchange() async {
        let viewModel = makeViewModel(exchanges: [])
        // The handler must NOT fire — record any call to fail loud.
        let calls = CallCounter()
        mockAPI.fetchInstrumentsHandler = { _ in
            await calls.increment()
            return []
        }
        await viewModel.loadInstruments()
        let count = await calls.count
        XCTAssertEqual(count, 0)
        XCTAssertFalse(viewModel.isLoadingInstruments)
    }

    func testLoadInstrumentsFailureSetsLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchInstrumentsHandler = { _ in throw APIError.invalidResponse }
        await viewModel.loadInstruments()
        XCTAssertTrue(viewModel.availableInstruments.isEmpty)
        XCTAssertEqual(viewModel.loadError, "Couldn't load instruments. Pull to refresh.")
        XCTAssertFalse(viewModel.isLoadingInstruments)
    }

    /// Bug-fix regression guard for v0.3.1 Q9a: a successful retry
    /// after a load failure must clear the sticky error banner. The
    /// pre-MVVM body never reset `loadError` on success so the
    /// banner persisted after recovery.
    func testLoadInstrumentsClearsLoadErrorOnRecovery() async {
        let viewModel = makeViewModel()
        // First attempt fails — stamps loadError.
        mockAPI.fetchInstrumentsHandler = { _ in throw APIError.invalidResponse }
        await viewModel.loadInstruments()
        XCTAssertNotNil(viewModel.loadError)
        // Second attempt succeeds — must clear loadError.
        let instrument = makeInstrument()
        mockAPI.fetchInstrumentsHandler = { _ in [instrument] }
        await viewModel.loadInstruments()
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.availableInstruments.count, 1)
    }

    /// Cross-exchange race guard: if the user changes
    /// `selectedExchange` while a fetch is in flight, the result
    /// for the OLD exchange must NOT overwrite the state that the
    /// new exchange's task will eventually populate.
    func testLoadInstrumentsRaceGuardDropsStaleSuccessResults() async {
        let viewModel = makeViewModel(exchanges: ["kraken", "binance"])
        // Slow fetch for kraken; fast for binance — but we won't
        // even let the binance task run; we just need to verify
        // the kraken stale result is ignored after we change exchange.
        mockAPI.fetchInstrumentsHandler = { exchange in
            if exchange == "kraken" {
                try await Task.sleep(nanoseconds: 50_000_000)
                return [
                    InstrumentDetailData(
                        type: "instrument_detail",
                        sequenceId: 1,
                        publicId: "envelope-id",
                        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                        sessionId: "session-test",
                        topic: nil,
                        instrumentPublicId: "stale-inst",
                        symbolPublicId: "sym-1",
                        symbol: "STALE",
                        exchange: "kraken",
                        canTrade: true,
                        canMarketData: true,
                        instrumentResolved: true,
                        instrumentKind: "spot",
                        expiryAt: nil
                    )
                ]
            }
            return []
        }
        let task = Task { await viewModel.loadInstruments() }
        // Give the task time to enter the await, then change exchange.
        try? await Task.sleep(nanoseconds: 10_000_000)
        viewModel.selectedExchange = "binance"
        await task.value
        // Stale kraken response must NOT have populated state.
        XCTAssertTrue(
            viewModel.availableInstruments.isEmpty,
            "Race-guard must drop stale fetch result after exchange change"
        )
    }

    /// Race-guard on the error path too: a kraken-side failure must
    /// not leak into the loadError slot once the user is on binance.
    func testLoadInstrumentsRaceGuardDropsStaleFailures() async {
        let viewModel = makeViewModel(exchanges: ["kraken", "binance"])
        mockAPI.fetchInstrumentsHandler = { exchange in
            if exchange == "kraken" {
                try await Task.sleep(nanoseconds: 50_000_000)
                throw APIError.httpError(503)
            }
            return []
        }
        let task = Task { await viewModel.loadInstruments() }
        try? await Task.sleep(nanoseconds: 10_000_000)
        viewModel.selectedExchange = "binance"
        await task.value
        XCTAssertNil(
            viewModel.loadError,
            "Race-guard must drop stale fetch error after exchange change"
        )
    }

    /// When the previously-selected instrument disappears from the
    /// fresh fetch's result set (e.g. the venue de-listed it), the
    /// VM must clear `selectedInstrument` so the picker does not
    /// keep a phantom row.
    func testLoadInstrumentsClearsStaleSelectedInstrumentMissingFromFetch() async {
        let viewModel = makeViewModel()
        // Pre-select an instrument that the upcoming fetch will not return.
        viewModel.selectedInstrument = makeInstrument(instrumentPublicId: "delisted")
        mockAPI.fetchInstrumentsHandler = { _ in [] }
        await viewModel.loadInstruments()
        XCTAssertNil(viewModel.selectedInstrument)
    }

    /// When the previously-selected instrument was for a different
    /// exchange than the one being loaded, the VM must clear it
    /// synchronously (BEFORE the await) so the user cannot tap
    /// Submit during the fetch and ship the stale instrument under
    /// a new exchange's name.
    func testLoadInstrumentsClearsStaleSelectedInstrumentFromOtherExchange() async {
        let viewModel = makeViewModel(exchanges: ["binance"])
        // Pre-select an instrument from a previous exchange.
        viewModel.selectedInstrument = makeInstrument(
            instrumentPublicId: "old",
            exchange: "kraken"
        )
        mockAPI.fetchInstrumentsHandler = { _ in [] }
        await viewModel.loadInstruments()
        XCTAssertNil(viewModel.selectedInstrument)
    }

    // MARK: - submit — happy path + invalid + re-entry

    func testSubmitFiresOnSubmitClosureWithBuiltBody() async {
        let viewModel = makeViewModel()
        viewModel.selectedInstrument = makeInstrument()
        viewModel.quantityText = "1.5"
        viewModel.priceText = "100"
        viewModel.orderType = "limit"
        let captured = CapturedBody()
        let result = await viewModel.submit { body in
            await captured.set(body)
            return true
        }
        XCTAssertTrue(result)
        let bodyOut = await captured.body
        XCTAssertNotNil(bodyOut)
        XCTAssertEqual(bodyOut?.quantity, 1.5)
        XCTAssertEqual(bodyOut?.price, 100)
        XCTAssertEqual(bodyOut?.idempotencyKey, "test-idempotency-key")
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func testSubmitReturnsFalseAndSkipsClosureWhenBuildBodyReturnsNil() async {
        let viewModel = makeViewModel()
        // No instrument → buildBody returns nil → submit short-circuits.
        let calls = CallCounter()
        let result = await viewModel.submit { _ in
            await calls.increment()
            return true
        }
        XCTAssertFalse(result)
        let count = await calls.count
        XCTAssertEqual(count, 0)
    }

    func testSubmitClearsIsSubmittingOnFailure() async {
        let viewModel = makeViewModel()
        viewModel.selectedInstrument = makeInstrument()
        viewModel.quantityText = "1"
        viewModel.orderType = "market"
        let result = await viewModel.submit { _ in return false }
        XCTAssertFalse(result)
        XCTAssertFalse(
            viewModel.isSubmitting,
            "isSubmitting must clear after a failed submit so the user can retry"
        )
    }

    /// Re-entry guard: a second submit while the first is in flight
    /// must short-circuit so a frantic double-tap cannot fire two
    /// parallel `createOrder` requests.
    func testSubmitGuardsAgainstReentryWhileInFlight() async {
        let viewModel = makeViewModel()
        viewModel.selectedInstrument = makeInstrument()
        viewModel.quantityText = "1"
        viewModel.orderType = "market"

        let counter = CallCounter()
        let firstTask = Task {
            await viewModel.submit { _ in
                await counter.increment()
                try? await Task.sleep(nanoseconds: 50_000_000)
                return true
            }
        }
        // Allow the first call to enter the await.
        try? await Task.sleep(nanoseconds: 10_000_000)
        // Second submit while the first is in flight — must reject.
        let secondResult = await viewModel.submit { _ in
            await counter.increment()
            return true
        }
        await firstTask.value
        let totalCalls = await counter.count
        XCTAssertEqual(totalCalls, 1, "Re-entry guard must reject concurrent submit")
        XCTAssertFalse(secondResult)
    }

    // MARK: - Idempotency key stability

    /// The idempotency key must stay stable across retries within
    /// the same VM instance — server-side dedup index keys on it,
    /// and a regenerated key on retry would create a duplicate
    /// live order.
    func testIdempotencyKeyStableAcrossRetries() async {
        let viewModel = makeViewModel(idempotencyKey: "stable-key-9")
        viewModel.selectedInstrument = makeInstrument()
        viewModel.quantityText = "1"
        viewModel.orderType = "market"
        let collector = KeyCollector()
        // First attempt fails.
        _ = await viewModel.submit { body in
            await collector.append(body.idempotencyKey ?? "")
            return false
        }
        // Retry must reuse the same key.
        _ = await viewModel.submit { body in
            await collector.append(body.idempotencyKey ?? "")
            return true
        }
        let keys = await collector.keys
        XCTAssertEqual(keys, ["stable-key-9", "stable-key-9"])
    }

    /// Sheet re-presentation gets a fresh VM (and therefore a fresh
    /// random key). Two newly-constructed VMs without an explicit
    /// key must produce distinct, non-empty values.
    func testIdempotencyKeyChangesAcrossPresentations() {
        let vm1 = NewOrderSheetViewModel(
            exchanges: ["kraken"],
            walletPublicId: "w",
            walletIsPaper: false,
            api: mockAPI
        )
        let vm2 = NewOrderSheetViewModel(
            exchanges: ["kraken"],
            walletPublicId: "w",
            walletIsPaper: false,
            api: mockAPI
        )
        XCTAssertNotEqual(vm1.idempotencyKey, vm2.idempotencyKey)
        XCTAssertFalse(vm1.idempotencyKey.isEmpty)
        XCTAssertFalse(vm2.idempotencyKey.isEmpty)
    }

    // MARK: - Computed properties

    func testNeedsPriceComputedReflectsOrderType() {
        let viewModel = makeViewModel()
        viewModel.orderType = "limit"
        XCTAssertTrue(viewModel.needsPrice)
        viewModel.orderType = "market"
        XCTAssertFalse(viewModel.needsPrice)
        viewModel.orderType = "stop_limit"
        XCTAssertTrue(viewModel.needsPrice)
        viewModel.orderType = "stop"
        XCTAssertFalse(viewModel.needsPrice)
    }

    func testNeedsStopPriceComputedReflectsOrderType() {
        let viewModel = makeViewModel()
        viewModel.orderType = "stop"
        XCTAssertTrue(viewModel.needsStopPrice)
        viewModel.orderType = "stop_limit"
        XCTAssertTrue(viewModel.needsStopPrice)
        viewModel.orderType = "limit"
        XCTAssertFalse(viewModel.needsStopPrice)
        viewModel.orderType = "market"
        XCTAssertFalse(viewModel.needsStopPrice)
    }

    func testCanSubmitReflectsFormState() {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.canSubmit, "No instrument → cannot submit")
        viewModel.selectedInstrument = makeInstrument()
        XCTAssertFalse(viewModel.canSubmit, "No quantity → cannot submit")
        viewModel.quantityText = "1"
        viewModel.orderType = "market"
        XCTAssertTrue(viewModel.canSubmit, "Market order with quantity + instrument")
        viewModel.isSubmitting = true
        XCTAssertFalse(viewModel.canSubmit, "Cannot submit while a submit is in flight")
    }

    func testBuildBodyDelegatesToStaticHelperWithVMState() {
        let viewModel = makeViewModel(walletIsPaper: true, idempotencyKey: "k-paper")
        viewModel.selectedInstrument = makeInstrument()
        viewModel.quantityText = "0.25"
        viewModel.orderType = "market"
        let body = viewModel.buildBody()
        XCTAssertNotNil(body)
        XCTAssertEqual(body?.mode, "paper")
        XCTAssertEqual(body?.quantity, 0.25)
        XCTAssertEqual(body?.idempotencyKey, "k-paper")
        XCTAssertEqual(body?.walletPublicId, "wallet-1")
    }
}

// MARK: - Test-only actor helpers for closure-captured state

/// Crosses isolation cleanly under Swift 6 strict concurrency. VM
/// closures are not declared `@Sendable`, so technically a plain
/// `var` capture would work, but routing through actors keeps the
/// test agnostic to how the VM sequences its callers and avoids
/// false positives on future tightening of the closure signature.
private actor CallCounter {
    private(set) var count: Int = 0
    func increment() { count += 1 }
}

private actor CapturedBody {
    private(set) var body: CreateOrderBody?
    func set(_ value: CreateOrderBody) { body = value }
}

private actor KeyCollector {
    private(set) var keys: [String] = []
    func append(_ key: String) { keys.append(key) }
}
