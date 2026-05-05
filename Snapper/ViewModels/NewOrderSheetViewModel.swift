import Foundation
import Observation
import os

/// ViewModel for `NewOrderSheet` — the first MVVM pilot landed in
/// v0.3.1. Architecture rules in `docs/architecture-mvvm.md`.
///
/// Owns every piece of state the pre-MVVM body kept inside `@State`:
/// form fields (exchange / instrument / side / order type / quantity
/// / price / stop price / leverage / reduce-only), the available
/// instruments cache, async / submit flags, the per-presentation
/// idempotency key, and the load-error string. The View now reads
/// the VM through `@Bindable`-style `$viewModel.field` bindings on
/// each form control, and the VM is the single test surface for
/// every load / submit / race / idempotency branch.
///
/// Notable behaviours:
///
/// 1. **Race-safe instrument load.** When the user changes
///    `selectedExchange` mid-`await`, the post-await guard drops
///    the stale fetch's payload AND the `defer` block guards the
///    `isLoadingInstruments = false` write behind the same exchange
///    check, so a slow kraken response never overwrites a fresh
///    binance fetch on either the data side or the loading-flag
///    side. Mirrors `testLoadInstrumentsRaceGuardDropsStaleSuccessResults`
///    + `testLoadInstrumentsRaceGuardDropsStaleFailures`.
///
/// 2. **`loadError` clears on recovery.** v0.3.0 had a sticky
///    banner: a successful retry after a load failure left
///    `loadError` populated. Q9a in the v0.3.1 architect consensus
///    flagged this; the VM now clears the slot whenever a fresh
///    fetch completes successfully.
///
/// 3. **Per-presentation idempotency key.** Minted exactly once in
///    `init` and re-used across retries inside the same VM
///    instance so the backend dedup index sees a stable key on
///    user-driven retries; a new sheet presentation gets a new
///    instance and a new key. Tests cover both halves.
///
/// 4. **Re-entry guard on submit.** A submit in flight rejects a
///    second tap before the closure runs, so a frantic
///    double-tap cannot fire two parallel `createOrder`
///    requests.
@MainActor
@Observable
final class NewOrderSheetViewModel {

    // MARK: - Mutable form state (read/write from View)

    var selectedExchange: String
    var availableInstruments: [InstrumentDetailData] = []
    var selectedInstrument: InstrumentDetailData?
    var side: String = "buy"
    var orderType: String = "limit"
    var quantityText: String = ""
    var priceText: String = ""
    var stopPriceText: String = ""
    var leverageText: String = ""
    var reduceOnly: Bool = false

    // MARK: - Async + submit-flow flags

    var isLoadingInstruments: Bool = false
    var isSubmitting: Bool = false
    var loadError: String?

    // MARK: - Static config (immutable for the VM's lifetime)

    let exchanges: [String]
    let walletPublicId: String
    let walletIsPaper: Bool

    /// Stable across retries within this VM presentation. Tests
    /// inject a deterministic value via the `idempotencyKey` init
    /// parameter; production code lets it default to a random UUID.
    let idempotencyKey: String

    // MARK: - Dependencies

    private let api: APIClientProtocol

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Snapper",
        category: "NewOrderSheetViewModel"
    )

    init(
        exchanges: [String],
        walletPublicId: String,
        walletIsPaper: Bool,
        defaultExchange: String? = nil,
        api: APIClientProtocol = APIClient.shared,
        idempotencyKey: String = UUID().uuidString
    ) {
        self.exchanges = exchanges
        self.walletPublicId = walletPublicId
        self.walletIsPaper = walletIsPaper
        self.selectedExchange = defaultExchange ?? exchanges.first ?? ""
        self.api = api
        self.idempotencyKey = idempotencyKey
    }

    // MARK: - Computed view state

    var needsPrice: Bool {
        return Self.needsPrice(orderType: orderType)
    }

    var needsStopPrice: Bool {
        return Self.needsStopPrice(orderType: orderType)
    }

    var canSubmit: Bool {
        return Self.canSubmit(
            instrument: selectedInstrument,
            selectedExchange: selectedExchange,
            isLoadingInstruments: isLoadingInstruments,
            quantityText: quantityText,
            priceText: priceText,
            stopPriceText: stopPriceText,
            orderType: orderType,
            isSubmitting: isSubmitting
        )
    }

    // MARK: - Async behaviour

    /// Fetch capability-aware instrument rows for the currently
    /// selected exchange. Race-safe via a post-await `guard` on
    /// `selectedExchange` so a stale response from a previous
    /// exchange cannot overwrite the current state.
    func loadInstruments() async {
        guard !selectedExchange.isEmpty else { return }
        // Synchronously clear stale rows BEFORE the await so the
        // user cannot tap Submit during the fetch and ship the
        // previous exchange's instrument under a new exchange's
        // name.
        let exchangeBeingLoaded = selectedExchange
        if selectedInstrument?.exchange != exchangeBeingLoaded {
            selectedInstrument = nil
        }
        availableInstruments = []
        isLoadingInstruments = true
        // Race-guard the loading-flag write too: a stale task
        // returning after the user picked a fresh exchange must NOT
        // flip `isLoadingInstruments` back to `false` and re-enable
        // Submit while the new task is still in flight. Tying the
        // defer to the same exchange-token check that gates the
        // payload writes keeps the loading UI consistent with the
        // current task.
        defer {
            if exchangeBeingLoaded == selectedExchange {
                isLoadingInstruments = false
            }
        }
        do {
            let fetched = try await api.fetchInstruments(exchange: exchangeBeingLoaded)
            // Race-guard: if the user changed exchange while we were
            // waiting, the .task(id: selectedExchange) modifier on the
            // View has already started a fresh task — defensively bail
            // so the stale payload does not clobber the new task's
            // populated state.
            guard exchangeBeingLoaded == selectedExchange else { return }
            availableInstruments = fetched
            // Clear sticky load-error on recovery (Q9a regression
            // guard from the v0.3.1 architect consensus). The
            // pre-MVVM body never reset this slot, so a successful
            // retry left the error banner showing.
            loadError = nil
            if let current = selectedInstrument,
               !fetched.contains(where: { $0.instrumentPublicId == current.instrumentPublicId }) {
                selectedInstrument = nil
            }
        } catch {
            // Preserve the device-log diagnostic the pre-MVVM body
            // emitted so an oncall reading sysdiag can still
            // correlate "instruments missing" reports with the
            // underlying error + venue.
            logger.error(
                "Failed to load instruments for \(exchangeBeingLoaded, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            // Race-guard the error path too: a failure on the
            // previous exchange must not surface an error banner
            // for the exchange the user has since switched to.
            guard exchangeBeingLoaded == selectedExchange else { return }
            loadError = "Couldn't load instruments. Pull to refresh."
            availableInstruments = []
        }
    }

    /// Build the outbound `CreateOrderBody` from the current form
    /// state. Returns `nil` when the form fails the same gate that
    /// drives the submit-button disabled state, so the generated
    /// body never violates backend's validators.
    func buildBody() -> CreateOrderBody? {
        return Self.buildBody(
            instrument: selectedInstrument,
            selectedExchange: selectedExchange,
            walletPublicId: walletPublicId,
            walletIsPaper: walletIsPaper,
            side: side,
            orderType: orderType,
            quantityText: quantityText,
            priceText: priceText,
            stopPriceText: stopPriceText,
            leverageText: leverageText,
            reduceOnly: reduceOnly,
            idempotencyKey: idempotencyKey
        )
    }

    /// Submit the current form via the parent-injected closure.
    /// Re-entry guard rejects a second tap while the first is in
    /// flight; the `defer` clears `isSubmitting` so the user can
    /// retry on failure under the same idempotency key.
    @discardableResult
    func submit(via onSubmit: (CreateOrderBody) async -> Bool) async -> Bool {
        guard !isSubmitting, let body = buildBody() else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        return await onSubmit(body)
    }

    // MARK: - Pure helpers (preserved from NewOrderSheet for the
    // existing test contract; tests reference `NewOrderSheetViewModel.X`
    // after the v0.3.1 migration)

    static let orderTypes: [String] = ["limit", "market", "stop", "stop_limit"]

    static func displayName(forOrderType orderType: String) -> String {
        switch orderType {
        case "limit": return "Limit"
        case "market": return "Market"
        case "stop": return "Stop"
        case "stop_limit": return "Stop limit"
        default: return orderType
        }
    }

    static func needsPrice(orderType: String) -> Bool {
        return orderType == "limit" || orderType == "stop_limit"
    }

    static func needsStopPrice(orderType: String) -> Bool {
        return orderType == "stop" || orderType == "stop_limit"
    }

    static func parsePositive(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    static func parsePositiveInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    static func canSubmit(
        instrument: InstrumentDetailData?,
        selectedExchange: String,
        isLoadingInstruments: Bool,
        quantityText: String,
        priceText: String,
        stopPriceText: String,
        orderType: String,
        isSubmitting: Bool
    ) -> Bool {
        guard !isSubmitting,
              !isLoadingInstruments,
              let instrument,
              instrument.canTrade,
              instrument.exchange == selectedExchange,
              parsePositive(quantityText) != nil
        else { return false }
        if needsPrice(orderType: orderType), parsePositive(priceText) == nil {
            return false
        }
        if needsStopPrice(orderType: orderType), parsePositive(stopPriceText) == nil {
            return false
        }
        return true
    }

    /// Pure builder for `CreateOrderBody`. Returns `nil` when the
    /// form fails the same gate as the submit-button disabled
    /// state. `walletIsPaper` derives the `mode` literal so a paper
    /// wallet never accidentally routes as a live order.
    static func buildBody(
        instrument: InstrumentDetailData?,
        selectedExchange: String,
        walletPublicId: String,
        walletIsPaper: Bool,
        side: String,
        orderType: String,
        quantityText: String,
        priceText: String,
        stopPriceText: String,
        leverageText: String,
        reduceOnly: Bool,
        idempotencyKey: String
    ) -> CreateOrderBody? {
        guard let instrument,
              instrument.canTrade,
              instrument.exchange == selectedExchange
        else { return nil }
        guard let quantity = parsePositive(quantityText) else { return nil }
        let price: Double? = needsPrice(orderType: orderType) ? parsePositive(priceText) : nil
        if needsPrice(orderType: orderType), price == nil { return nil }
        let stopPrice: Double? = needsStopPrice(orderType: orderType) ? parsePositive(stopPriceText) : nil
        if needsStopPrice(orderType: orderType), stopPrice == nil { return nil }
        let leverage: Int? = parsePositiveInt(leverageText)
        return CreateOrderBody(
            instrument: instrument.symbol,
            instrumentPublicId: instrument.instrumentPublicId,
            exchange: instrument.exchange,
            mode: walletIsPaper ? "paper" : "live",
            side: side,
            orderType: orderType,
            quantity: quantity,
            price: price,
            stopPrice: stopPrice,
            timeInForce: "GTC",
            postOnly: false,
            leverage: leverage,
            reduceOnly: reduceOnly,
            walletPublicId: walletPublicId,
            operatorPublicId: nil,
            idempotencyKey: idempotencyKey,
            aiReviewPublicId: nil
        )
    }

    /// Wrap a `CreateOrderBody` in a provenance-stamped
    /// `CreateOrderCommand` envelope.
    @MainActor
    static func makeCommand(
        body: CreateOrderBody,
        provenance: EnvelopeMinter.Provenance? = nil
    ) -> CreateOrderCommand {
        let envelope = provenance ?? EnvelopeMinter.shared.next(.control)
        return CreateOrderCommand(
            type: "create_order_command",
            sequenceId: envelope.sequenceId,
            publicId: envelope.publicId,
            timestamp: envelope.timestamp,
            sessionId: envelope.sessionId,
            topic: nil,
            payload: body
        )
    }
}
