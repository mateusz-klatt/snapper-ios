import Foundation
import Observation
import os

/// ViewModel for `OrdersView` — extracted in v0.3.1 as part of the
/// MVVM rollout. The VM owns the orders + executions data, the
/// parallel `async let` load, the submit / cancel flows, and the
/// derived filtered collections; the View becomes a thin Picker /
/// List binder over `$viewModel.X`.
///
/// Architecture rules in `docs/architecture-mvvm.md`. Sheet /
/// alert booleans (`presentingNewOrder`, `pendingCancelOrder`)
/// stay as `@State` in the View per Q3 of the v0.3.1 architect
/// consensus — moving them into the VM adds `Binding<Bool>`
/// ceremony without coverage gain.
@MainActor
@Observable
final class OrdersViewModel {

    var orders: [OrderStatus] = []
    var executions: [ExecutionRecord] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var submitError: String?

    private let api: APIClientProtocol
    private let appState: AppState

    private let logger = AppLogger.make(category: "OrdersViewModel")

    init(
        api: APIClientProtocol = APIClient.shared,
        appState: AppState = .shared
    ) {
        self.api = api
        self.appState = appState
    }
    var filteredOpen: [OrderStatus] {
        return Self.filterOpen(
            orders: orders,
            selectedWalletPublicId: appState.selectedWalletPublicId
        )
    }

    var filteredRecent: [OrderStatus] {
        return Self.filterRecent(
            orders: orders,
            selectedWalletPublicId: appState.selectedWalletPublicId
        )
    }

    var filteredFills: [ExecutionRecord] {
        return Self.filterFills(
            executions: executions,
            selectedWalletPublicId: appState.selectedWalletPublicId
        )
    }

    /// Unique exchange identifiers derived from the orders +
    /// executions already loaded. Powers `NewOrderSheet`'s exchange
    /// picker bootstrap when the user has no other venue catalog
    /// in scope. Falls back to `["kraken"]` so the form stays
    /// usable on a fresh app launch.
    var derivedExchanges: [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for value in orders.map(\.exchange) + executions.map(\.exchange) {
            if seen.insert(value).inserted {
                ordered.append(value)
            }
        }
        return ordered.isEmpty ? ["kraken"] : ordered
    }

    /// Resolves the user's selected wallet against the live
    /// `appState.availableWallets` cache. A persisted public id
    /// pointing at a wallet that no longer exists falls through
    /// to `nil` so the `+` button gate disables instead of
    /// presenting a sheet that cannot build a valid order body.
    var resolvedWallet: WalletInfo? {
        guard let id = appState.selectedWalletPublicId else { return nil }
        return appState.availableWallets.first { $0.publicId == id }
    }
    func load() async {
        isLoading = true
        defer { isLoading = false }

        async let ordersResult = api.fetchOrders()
        async let executionsResult = api.fetchExecutions()

        /// Capture both results before mutating errorMessage so a
        /// partial failure on either fetch surfaces — the Fills
        /// segment was previously hiding executions failures because
        /// only fetchOrders' catch was wired up.
        var encounteredError: String?
        do {
            orders = try await ordersResult
        } catch {
            logger.error("Failed to fetch orders: \(error.localizedDescription, privacy: .public)")
            encounteredError = error.localizedDescription
        }
        do {
            executions = try await executionsResult
        } catch {
            logger.error("Failed to fetch executions: \(error.localizedDescription, privacy: .public)")
            encounteredError = encounteredError ?? error.localizedDescription
        }
        errorMessage = encounteredError
    }

    @discardableResult
    func submitNewOrder(body: CreateOrderBody) async -> Bool {
        do {
            let command = NewOrderSheetViewModel.makeCommand(body: body)
            _ = try await api.createOrder(command: command)
            await load()
            return true
        } catch {
            logger.error("Failed to submit new order: \(error.localizedDescription, privacy: .public)")
            submitError = "Couldn't submit the order. Try again."
            return false
        }
    }

    func submitCancel(order: OrderStatus) async {
        guard let planId = order.planPublicId else {
            submitError = "This order has no execution plan to cancel."
            return
        }
        do {
            _ = try await api.cancelOrder(planPublicId: planId, reason: nil)
            await load()
        } catch {
            logger.error("Failed to cancel order: \(error.localizedDescription, privacy: .public)")
            submitError = "Couldn't cancel the order. Try again."
        }
    }
    /// Backward-compatible test contract.
    /// Backend-canonical "open" lifecycle states. Values mirror
    /// `snapper.core.types.OrderStatusEnum` members that have not
    /// reached a terminal state (`filled`, `cancelled`, `rejected`).
    static let openStatuses: Set<String> = ["new", "submitted", "open", "partially_filled"]

    static func isOpen(status: String) -> Bool {
        return openStatuses.contains(status)
    }

    static func walletMatches(rowWalletId: String?, selected: String?) -> Bool {
        guard let selected else { return true }
        guard let rowWalletId else { return true }
        return rowWalletId == selected
    }

    static func filterOpen(
        orders: [OrderStatus],
        selectedWalletPublicId: String?
    ) -> [OrderStatus] {
        return orders.filter { order in
            isOpen(status: order.status)
                && walletMatches(rowWalletId: order.walletPublicId, selected: selectedWalletPublicId)
        }
    }

    static func filterRecent(
        orders: [OrderStatus],
        selectedWalletPublicId: String?,
        limit: Int = 50
    ) -> [OrderStatus] {
        let scoped = orders.filter { order in
            walletMatches(rowWalletId: order.walletPublicId, selected: selectedWalletPublicId)
        }
        let sorted = scoped.sorted { $0.createdAt > $1.createdAt }
        return Array(sorted.prefix(limit))
    }

    static func filterFills(
        executions: [ExecutionRecord],
        selectedWalletPublicId: String?
    ) -> [ExecutionRecord] {
        return executions.filter { execution in
            walletMatches(
                rowWalletId: execution.walletPublicId,
                selected: selectedWalletPublicId
            )
        }
    }

    /// Decision helper for the error banner. Suppressed mid-load so
    /// the user does not see a stale error flash above an active
    /// spinner; surfaces the moment the load settles with an
    /// unresolved error.
    static func shouldShowLoadError(
        errorMessage: String?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard let errorMessage else { return false }
        return !errorMessage.isEmpty
    }

    /// Decision helper for the in-list "Loading…" placeholder. The
    /// banner suppresses itself while `isLoading` so a Retry tap on
    /// an empty failure leaves the user staring at a blank list
    /// without this placeholder. We only surface the placeholder
    /// when the active segment has nothing to render.
    static func shouldShowLoadingPlaceholder(
        isLoading: Bool,
        activeSegmentIsEmpty: Bool
    ) -> Bool {
        return isLoading && activeSegmentIsEmpty
    }
}
