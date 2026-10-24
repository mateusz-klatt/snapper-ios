import XCTest
@testable import Snapper

@MainActor
final class NewOrderSheetTests: XCTestCase {

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private static let fixedProvenance = EnvelopeMinter.Provenance(
        publicId: "test-public-id",
        sessionId: "session-test",
        sequenceId: 27,
        timestamp: baseTimestamp,
        timestampString: "2023-11-14T22:13:20.000Z"
    )

    private static func makeInstrument(
        canTrade: Bool = true,
        instrumentPublicId: String = "inst-1",
        symbol: String = "BTC-USD",
        exchange: String = "kraken"
    ) -> InstrumentDetailData {
        return InstrumentDetailData(
            type: "instrument_detail",
            sequenceId: 1,
            publicId: "envelope-id",
            timestamp: baseTimestamp,
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

    private static func baseForm() -> NewOrderSheetViewModel.OrderFormSnapshot {
        return NewOrderSheetViewModel.OrderFormSnapshot(
            instrument: makeInstrument(),
            selectedExchange: "kraken",
            side: "buy",
            orderType: "market",
            quantityText: "1",
            priceText: "",
            stopPriceText: "",
            leverageText: "",
            reduceOnly: false
        )
    }

    private static func baseGate() -> NewOrderSheetViewModel.SubmitGateState {
        return NewOrderSheetViewModel.SubmitGateState(
            isLoadingInstruments: false,
            isSubmitting: false
        )
    }

    private static func walletContext(
        publicId: String = "w",
        isPaper: Bool = false
    ) -> NewOrderSheetViewModel.WalletContext {
        return NewOrderSheetViewModel.WalletContext(
            publicId: publicId,
            isPaper: isPaper
        )
    }

    private static let testIdempotencyKey: String = "test-idempotency-key"

    /// Two venues can list the same `symbol` (e.g. "BTC-USD" exists
    /// on both kraken-spot and kraken-futures) with distinct
    /// `instrumentPublicId`. Identifying the picked row by symbol
    /// alone routes orders to the wrong venue when the user
    /// switches exchanges. The builder MUST use the picked row's
    /// `instrumentPublicId` + `exchange` verbatim — no symbol
    /// reconciliation.
    func testBuildBodyPropagatesPickedInstrumentPublicIdNotSymbol() {
        let krakenSpot = Self.makeInstrument(
            instrumentPublicId: "inst-kraken-spot-btc",
            symbol: "BTC-USD",
            exchange: "kraken"
        )
        let krakenFutures = Self.makeInstrument(
            instrumentPublicId: "inst-kraken-futures-btc",
            symbol: "BTC-USD",
            exchange: "kraken_futures"
        )
        var spotForm = Self.baseForm()
        spotForm.instrument = krakenSpot
        spotForm.selectedExchange = "kraken"
        let bodySpot = NewOrderSheetViewModel.buildBody(
            form: spotForm,
            wallet: Self.walletContext(),
            idempotencyKey: Self.testIdempotencyKey
        )
        var futuresForm = Self.baseForm()
        futuresForm.instrument = krakenFutures
        futuresForm.selectedExchange = "kraken_futures"
        let bodyFutures = NewOrderSheetViewModel.buildBody(
            form: futuresForm,
            wallet: Self.walletContext(),
            idempotencyKey: Self.testIdempotencyKey
        )
        XCTAssertEqual(bodySpot?.instrumentPublicId, "inst-kraken-spot-btc")
        XCTAssertEqual(bodySpot?.exchange, "kraken")
        XCTAssertEqual(bodyFutures?.instrumentPublicId, "inst-kraken-futures-btc")
        XCTAssertEqual(bodyFutures?.exchange, "kraken_futures")
    }

    /// Cross-exchange race regression guard: when the picked
    /// instrument's exchange does NOT match the currently-selected
    /// exchange (because the instruments fetch is still in flight
    /// after a venue switch), the builder must refuse to build a
    /// body — submitting one venue's instrument under another
    /// venue's name is the worst case the original symbol-keyed bug
    /// could produce.
    func testBuildBodyRejectsExchangeMismatch() {
        var form = Self.baseForm()
        form.instrument = Self.makeInstrument(exchange: "kraken")
        form.selectedExchange = "kraken_futures"
        XCTAssertNil(NewOrderSheetViewModel.buildBody(
            form: form,
            wallet: Self.walletContext(),
            idempotencyKey: Self.testIdempotencyKey
        ))
    }

    /// `needsPrice` mirrors the frontend rule at
    /// `NewOrderModal.tsx:114` — limit + stop_limit require a price.
    func testNeedsPriceFollowsBackendOrderTypes() {
        XCTAssertTrue(NewOrderSheetViewModel.needsPrice(orderType: "limit"))
        XCTAssertTrue(NewOrderSheetViewModel.needsPrice(orderType: "stop_limit"))
        XCTAssertFalse(NewOrderSheetViewModel.needsPrice(orderType: "market"))
        XCTAssertFalse(NewOrderSheetViewModel.needsPrice(orderType: "stop"))
    }

    func testNeedsStopPriceFollowsBackendOrderTypes() {
        XCTAssertTrue(NewOrderSheetViewModel.needsStopPrice(orderType: "stop"))
        XCTAssertTrue(NewOrderSheetViewModel.needsStopPrice(orderType: "stop_limit"))
        XCTAssertFalse(NewOrderSheetViewModel.needsStopPrice(orderType: "limit"))
        XCTAssertFalse(NewOrderSheetViewModel.needsStopPrice(orderType: "market"))
    }

    func testDisplayNameMapsOrderTypes() {
        XCTAssertEqual(NewOrderSheetViewModel.displayName(forOrderType: "limit"), "Limit")
        XCTAssertEqual(NewOrderSheetViewModel.displayName(forOrderType: "market"), "Market")
        XCTAssertEqual(NewOrderSheetViewModel.displayName(forOrderType: "stop"), "Stop")
        XCTAssertEqual(NewOrderSheetViewModel.displayName(forOrderType: "stop_limit"), "Stop limit")
        XCTAssertEqual(NewOrderSheetViewModel.displayName(forOrderType: "iceberg"), "iceberg")
    }

    func testParsePositiveHandlesWhitespaceCommaAndInvalidValues() {
        XCTAssertEqual(NewOrderSheetViewModel.parsePositive(" 1,25 "), 1.25)
        XCTAssertEqual(NewOrderSheetViewModel.parsePositive("\n 1,25\t"), 1.25)
        XCTAssertNil(NewOrderSheetViewModel.parsePositive(""))
        XCTAssertNil(NewOrderSheetViewModel.parsePositive("0"))
        XCTAssertNil(NewOrderSheetViewModel.parsePositive("-1"))
        XCTAssertNil(NewOrderSheetViewModel.parsePositive("abc"))
    }

    func testParsePositiveIntHandlesWhitespaceAndInvalidValues() {
        XCTAssertEqual(NewOrderSheetViewModel.parsePositiveInt(" 5 "), 5)
        XCTAssertEqual(NewOrderSheetViewModel.parsePositiveInt("\n 5\t"), 5)
        XCTAssertNil(NewOrderSheetViewModel.parsePositiveInt(""))
        XCTAssertNil(NewOrderSheetViewModel.parsePositiveInt("0"))
        XCTAssertNil(NewOrderSheetViewModel.parsePositiveInt("-1"))
        XCTAssertNil(NewOrderSheetViewModel.parsePositiveInt("1.5"))
    }

    func testParsePositiveRejectsNonFiniteValuesAndOverflow() {
        for text in ["inf", "+inf", "Infinity", "-Infinity", "nan", "NaN", "1e309"] {
            XCTAssertNil(NewOrderSheetViewModel.parsePositive(text), text)
        }
        XCTAssertEqual(NewOrderSheetViewModel.parsePositive("1e308"), 1e308)
    }

    func testParsePositiveIntUsesBackendInt32Range() {
        XCTAssertEqual(NewOrderSheetViewModel.parsePositiveInt("2147483647"), Int(Int32.max))
        for text in ["2147483648", "9223372036854775807", "9223372036854775808", "inf", "NaN"] {
            XCTAssertNil(NewOrderSheetViewModel.parsePositiveInt(text), text)
        }
    }

    func testNonFiniteRequiredNumbersBlockGateAndBody() {
        for text in ["inf", "NaN", "1e309"] {
            var form = Self.baseForm()
            form.quantityText = text
            assertSubmissionRejected(form, message: "quantity: \(text)")
            form.quantityText = "1"
            form.orderType = "limit"
            form.priceText = text
            assertSubmissionRejected(form, message: "price: \(text)")
            form.orderType = "stop"
            form.priceText = ""
            form.stopPriceText = text
            assertSubmissionRejected(form, message: "stop price: \(text)")
        }
    }

    func testNonblankInvalidLeverageBlocksGateAndBody() {
        for text in ["abc", "0", "-1", "1.5", "2147483648", "inf", "NaN"] {
            var form = Self.baseForm()
            form.leverageText = text
            assertSubmissionRejected(form, message: "leverage: \(text)")
        }
    }

    func testLeverageIsAcceptedForLiveKrakenSpot() {
        var form = Self.baseForm()
        form.leverageText = "\n 5\t"
        XCTAssertTrue(NewOrderSheetViewModel.canSubmit(form: form, gate: Self.baseGate()))
        let body = NewOrderSheetViewModel.buildBody(
            form: form,
            wallet: Self.walletContext(),
            idempotencyKey: Self.testIdempotencyKey
        )
        XCTAssertEqual(body?.leverage, 5)
    }

    func testFrozenXStockCannotSubmitWithLeverage() {
        var form = Self.baseForm()
        form.instrument = Self.makeInstrument(
            canTrade: false,
            instrumentPublicId: "tokenized-nvdax",
            symbol: "NVDAx-EUR"
        )
        form.leverageText = "5"
        assertSubmissionRejected(form, message: "Tokenized instrument remains market data only")
    }

    func testPerOrderLeverageIsRejectedForPaperAndOtherVenues() {
        var form = Self.baseForm()
        form.leverageText = "5"
        var paperGate = Self.baseGate()
        paperGate.walletIsPaper = true
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(form: form, gate: paperGate))
        XCTAssertNil(NewOrderSheetViewModel.buildBody(
            form: form,
            wallet: Self.walletContext(isPaper: true),
            idempotencyKey: Self.testIdempotencyKey
        ))
        for exchange in ["kraken_futures", "binance"] {
            form.selectedExchange = exchange
            form.instrument = Self.makeInstrument(exchange: exchange)
            assertSubmissionRejected(form, message: exchange)
        }
    }

    func testBlankLeverageIsOmittedForPaperAndFutures() {
        for isPaper in [false, true] {
            for exchange in ["kraken", "kraken_futures"] {
                var form = Self.baseForm()
                form.selectedExchange = exchange
                form.instrument = Self.makeInstrument(exchange: exchange)
                form.leverageText = " \n\t"
                var gate = Self.baseGate()
                gate.walletIsPaper = isPaper
                XCTAssertTrue(NewOrderSheetViewModel.canSubmit(form: form, gate: gate))
                let body = NewOrderSheetViewModel.buildBody(
                    form: form,
                    wallet: Self.walletContext(isPaper: isPaper),
                    idempotencyKey: Self.testIdempotencyKey
                )
                XCTAssertNotNil(body)
                XCTAssertNil(body?.leverage)
            }
        }
    }

    private func assertSubmissionRejected(
        _ form: NewOrderSheetViewModel.OrderFormSnapshot,
        message: String
    ) {
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(form: form, gate: Self.baseGate()), message)
        XCTAssertNil(NewOrderSheetViewModel.buildBody(
            form: form,
            wallet: Self.walletContext(),
            idempotencyKey: Self.testIdempotencyKey
        ), message)
    }

    /// Submit gate: instrument must be tradable, exchange must
    /// match the picker, instruments fetch must be settled,
    /// quantity must parse positive, and any required price field
    /// must parse positive. Mirrors the disabled-state rules in
    /// the SwiftUI Form so the caller cannot fire requests that
    /// the backend would 422.
    func testCanSubmitRejectsMissingInstrument() {
        var form = Self.baseForm()
        form.instrument = nil
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(
            form: form,
            gate: Self.baseGate()
        ))
    }

    func testCanSubmitRejectsMarketDataOnlyInstrument() {
        var form = Self.baseForm()
        form.instrument = Self.makeInstrument(canTrade: false)
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(
            form: form,
            gate: Self.baseGate()
        ))
    }

    func testCanSubmitRejectsExchangeMismatch() {
        var form = Self.baseForm()
        form.instrument = Self.makeInstrument(exchange: "kraken")
        form.selectedExchange = "kraken_futures"
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(
            form: form,
            gate: Self.baseGate()
        ))
    }

    /// While instruments are still loading after an exchange
    /// switch, submit must stay disabled so a quick tap cannot
    /// fire the previously-selected instrument under a new
    /// exchange's name.
    func testCanSubmitBlockedWhileInstrumentsLoading() {
        var gate = Self.baseGate()
        gate.isLoadingInstruments = true
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(
            form: Self.baseForm(),
            gate: gate
        ))
    }

    func testCanSubmitBlockedWhileSubmitting() {
        var gate = Self.baseGate()
        gate.isSubmitting = true
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(
            form: Self.baseForm(),
            gate: gate
        ))
    }

    func testCanSubmitRejectsZeroOrMissingQuantity() {
        var form = Self.baseForm()
        form.quantityText = ""
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(
            form: form,
            gate: Self.baseGate()
        ))
        form.quantityText = "0"
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(
            form: form,
            gate: Self.baseGate()
        ))
    }

    func testCanSubmitRequiresPriceForLimit() {
        var form = Self.baseForm()
        form.orderType = "limit"
        form.priceText = ""
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(
            form: form,
            gate: Self.baseGate()
        ))
        form.priceText = "100"
        XCTAssertTrue(NewOrderSheetViewModel.canSubmit(
            form: form,
            gate: Self.baseGate()
        ))
    }

    func testCanSubmitRequiresStopPriceForStopLimit() {
        var form = Self.baseForm()
        form.orderType = "stop_limit"
        form.priceText = "100"
        form.stopPriceText = ""
        XCTAssertFalse(NewOrderSheetViewModel.canSubmit(
            form: form,
            gate: Self.baseGate()
        ))
        form.stopPriceText = "95"
        XCTAssertTrue(NewOrderSheetViewModel.canSubmit(
            form: form,
            gate: Self.baseGate()
        ))
    }

    func testCanSubmitMarketOrderJustNeedsQuantity() {
        var form = Self.baseForm()
        form.quantityText = "0.25"
        XCTAssertTrue(NewOrderSheetViewModel.canSubmit(
            form: form,
            gate: Self.baseGate()
        ))
    }

    /// Builder propagates picker selections + parsed numeric inputs
    /// onto a `CreateOrderBody` whose shape matches the backend's
    /// validators. `time_in_force` defaults to GTC and `post_only`
    /// to false so the API contract sees explicit non-null values
    /// (avoids ambiguous "use venue defaults" semantics on the
    /// server side).
    func testBuildBodyPropagatesPickerSelectionsAndParsedNumbers() {
        var form = Self.baseForm()
        form.side = "sell"
        form.orderType = "limit"
        form.quantityText = "1.25"
        form.priceText = "65000.5"
        form.leverageText = "5"
        form.reduceOnly = true
        let body = NewOrderSheetViewModel.buildBody(
            form: form,
            wallet: Self.walletContext(publicId: "wallet-9"),
            idempotencyKey: Self.testIdempotencyKey
        )
        XCTAssertNotNil(body)
        guard let body else { return }
        XCTAssertEqual(body.instrument, "BTC-USD")
        XCTAssertEqual(body.instrumentPublicId, "inst-1")
        XCTAssertEqual(body.exchange, "kraken")
        XCTAssertEqual(body.side, "sell")
        XCTAssertEqual(body.orderType, "limit")
        XCTAssertEqual(body.quantity, 1.25)
        XCTAssertEqual(body.price, 65000.5)
        XCTAssertNil(body.stopPrice)
        XCTAssertEqual(body.leverage, 5)
        XCTAssertEqual(body.reduceOnly, true)
        XCTAssertEqual(body.walletPublicId, "wallet-9")
        XCTAssertEqual(body.timeInForce, "GTC")
        XCTAssertEqual(body.postOnly, false)
        XCTAssertEqual(body.idempotencyKey, Self.testIdempotencyKey)
    }

    func testBuildBodyReturnsNilWhenGateFails() {
        var form = Self.baseForm()
        form.instrument = Self.makeInstrument(canTrade: false)
        XCTAssertNil(NewOrderSheetViewModel.buildBody(
            form: form,
            wallet: Self.walletContext(publicId: "wallet-9"),
            idempotencyKey: Self.testIdempotencyKey
        ))
    }

    func testBuildBodyReturnsNilForMissingQuantityOrRequiredPrices() {
        var missingQuantity = Self.baseForm()
        missingQuantity.quantityText = ""
        XCTAssertNil(NewOrderSheetViewModel.buildBody(
            form: missingQuantity,
            wallet: Self.walletContext(),
            idempotencyKey: Self.testIdempotencyKey
        ))

        var missingLimitPrice = Self.baseForm()
        missingLimitPrice.orderType = "limit"
        missingLimitPrice.priceText = ""
        XCTAssertNil(NewOrderSheetViewModel.buildBody(
            form: missingLimitPrice,
            wallet: Self.walletContext(),
            idempotencyKey: Self.testIdempotencyKey
        ))

        var missingStopPrice = Self.baseForm()
        missingStopPrice.orderType = "stop"
        missingStopPrice.stopPriceText = ""
        XCTAssertNil(NewOrderSheetViewModel.buildBody(
            form: missingStopPrice,
            wallet: Self.walletContext(),
            idempotencyKey: Self.testIdempotencyKey
        ))
    }

    /// Critical safety regression guard: a paper wallet must always
    /// produce a body with ``mode == "paper"`` so the backend's
    /// ``CreateOrderBody.mode`` default of ``"live"`` cannot route
    /// real money on a paper-wallet user's behalf.
    func testBuildBodyForPaperWalletStampsPaperMode() {
        let body = NewOrderSheetViewModel.buildBody(
            form: Self.baseForm(),
            wallet: Self.walletContext(publicId: "paper-wallet", isPaper: true),
            idempotencyKey: Self.testIdempotencyKey
        )
        XCTAssertEqual(body?.mode, "paper")
    }

    func testBuildBodyForLiveWalletStampsLiveMode() {
        let body = NewOrderSheetViewModel.buildBody(
            form: Self.baseForm(),
            wallet: Self.walletContext(publicId: "live-wallet"),
            idempotencyKey: Self.testIdempotencyKey
        )
        XCTAssertEqual(body?.mode, "live")
    }

    /// Idempotency key propagates verbatim from the caller into the
    /// outbound body so a network retry collides with the server's
    /// dedup index instead of creating a duplicate live order.
    func testBuildBodyPropagatesIdempotencyKey() {
        let body = NewOrderSheetViewModel.buildBody(
            form: Self.baseForm(),
            wallet: Self.walletContext(),
            idempotencyKey: "stable-key-42"
        )
        XCTAssertEqual(body?.idempotencyKey, "stable-key-42")
    }

    func testMakeCommandStampsProvenance() {
        let body = CreateOrderBody(
            instrument: "BTC-USD",
            instrumentPublicId: "inst-1",
            exchange: "kraken",
            mode: nil,
            side: "buy",
            orderType: "market",
            quantity: 0.5,
            price: nil,
            stopPrice: nil,
            timeInForce: "GTC",
            postOnly: false,
            leverage: nil,
            reduceOnly: false,
            walletPublicId: "wallet-9",
            operatorPublicId: nil,
            idempotencyKey: nil,
            aiReviewPublicId: nil
        )
        let command = NewOrderSheetViewModel.makeCommand(body: body, provenance: Self.fixedProvenance)
        XCTAssertEqual(command.type, "create_order_command")
        XCTAssertEqual(command.sessionId, "session-test")
        XCTAssertEqual(command.sequenceId, 27)
        XCTAssertEqual(command.publicId, "test-public-id")
        XCTAssertEqual(command.payload.quantity, 0.5)
        XCTAssertEqual(command.payload.instrument, "BTC-USD")
    }
}
