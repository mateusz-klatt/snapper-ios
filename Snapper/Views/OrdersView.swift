import SwiftUI

/// Orders + executions list, segmented by lifecycle state.
///
/// Refactored to MVVM in v0.3.1 — data, async I/O, and submit
/// flows live in `OrdersViewModel`. The View binds segment
/// selection + sheet/alert presentation flags via `@State`.
///
/// Picker tabs:
/// - Open: orders whose `status` is one of the live-lifecycle
///   members of the backend `OrderStatusEnum` (`new`, `submitted`,
///   `open`, `partially_filled`).
/// - Recent: every order the wallet selection grants visibility to,
///   newest-first, capped at 50 rows for paging discipline.
/// - Fills: `ExecutionData` rows from `GET /api/executions`.
///
/// Wallet filter: orders + executions both expose
/// `walletPublicId`, so the list is scoped to
/// `AppState.selectedWalletPublicId` whenever a wallet is picked.
/// Rows whose `walletPublicId` is `nil` (legacy / system rows
/// without an owner) pass through so the UI never silently drops
/// data.
struct OrdersView: View {

    @Environment(AppState.self) private var appState
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var webSocketManager: WebSocketManager
    @State private var viewModel: OrdersViewModel?

    @State private var segment: OrdersSegment = .open
    @State private var presentingNewOrder = false
    @State private var pendingCancelOrder: OrderStatus?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(LocalizedStringKey("orders.segment.label"), selection: $segment) {
                    ForEach(OrdersSegment.allCases) { seg in
                        Text(LocalizedStringKey(seg.titleKey)).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    if let viewModel {
                        if OrdersViewModel.shouldShowLoadingPlaceholder(
                            isLoading: viewModel.isLoading,
                            activeSegmentIsEmpty: activeSegmentIsEmpty(viewModel: viewModel)
                        ) {
                            Section {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text(LocalizedStringKey("common.loading"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else if OrdersViewModel.shouldShowLoadError(
                            errorMessage: viewModel.errorMessage,
                            isLoading: viewModel.isLoading
                        ), let errorMessage = viewModel.errorMessage {
                            Section {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LocalizedStringKey("common.error.loadFailed.title"))
                                            .font(.subheadline.weight(.semibold))
                                        Text(errorMessage)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(LocalizedStringKey("common.retry")) {
                                        Task { await viewModel.load() }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        switch segment {
                        case .open:
                            ForEach(viewModel.filteredOpen, id: \.publicId) { order in
                                if authService.hasPermission(.cancelOrders) {
                                    OrderRow(order: order)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                pendingCancelOrder = order
                                            } label: {
                                                Label(LocalizedStringKey("orders.row.swipeCancel"), systemImage: "xmark.circle")
                                            }
                                            .accessibilityLabel(LocalizedStringKey("orders.accessibility.label.cancelButton"))
                                            .disabled(order.planPublicId == nil)
                                        }
                                } else {
                                    OrderRow(order: order)
                                }
                            }
                        case .recent:
                            ForEach(viewModel.filteredRecent, id: \.publicId) { order in
                                OrderRow(order: order)
                            }
                        case .fills:
                            ForEach(viewModel.filteredFills, id: \.publicId) { execution in
                                ExecutionRow(execution: execution)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.bgBase)
                .refreshable { await viewModel?.load() }
            }
            .navigationTitle(LocalizedStringKey("orders.navTitle"))
            .toolbar {
                if authService.hasPermission(.createOrders) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            presentingNewOrder = true
                        } label: {
                            Label(LocalizedStringKey("orders.newOrder.button"), systemImage: "plus.circle")
                        }
                        .disabled(viewModel?.resolvedWallet == nil)
                    }
                }
            }
        }
        .task(id: appState.selectedWalletPublicId) {
            if viewModel == nil {
                viewModel = OrdersViewModel(appState: appState)
            }
            await viewModel?.load()

            guard let viewModel else { return }
            viewModel.startObservingLiveUpdates(from: webSocketManager.state)
            await withTaskCancellationHandler {
                try? await Task.sleep(nanoseconds: .max)
            } onCancel: {
                Task { @MainActor in
                    viewModel.stopObservingLiveUpdates()
                }
            }
        }
        .sheet(isPresented: $presentingNewOrder) {
            if let viewModel, let wallet = viewModel.resolvedWallet {
                NewOrderSheet(
                    exchanges: viewModel.derivedExchanges,
                    walletPublicId: wallet.publicId,
                    walletIsPaper: wallet.isPaper,
                    onSubmit: { body in
                        await viewModel.submitNewOrder(body: body)
                    }
                )
            }
        }
        .alert(
            LocalizedStringKey("orders.cancel.confirmTitle"),
            isPresented: Binding(
                get: { pendingCancelOrder != nil },
                set: { if !$0 { pendingCancelOrder = nil } }
            ),
            presenting: pendingCancelOrder
        ) { order in
            Button(LocalizedStringKey("orders.cancel.confirmButton"), role: .destructive) {
                Task { await viewModel?.submitCancel(order: order) }
            }
            Button(LocalizedStringKey("orders.cancel.keepOpen"), role: .cancel) {
                pendingCancelOrder = nil
            }
        } message: { order in
            Text("\(order.instrument) \(order.side.uppercased()) \(String(format: "%.4f", order.size)) @ \(order.price.map { String(format: "%.4f", $0) } ?? "market") will be cancelled at the venue.")
        }
        .alert(
            LocalizedStringKey("common.error.submissionFailed"),
            isPresented: Binding(
                get: { viewModel?.submitError != nil },
                set: { if !$0 { viewModel?.submitError = nil } }
            ),
            presenting: viewModel?.submitError
        ) { _ in
            Button(LocalizedStringKey("common.ok"), role: .cancel) {
                viewModel?.submitError = nil
            }
        } message: { error in
            Text(error)
        }
    }

    private func activeSegmentIsEmpty(viewModel: OrdersViewModel) -> Bool {
        switch segment {
        case .open: return viewModel.filteredOpen.isEmpty
        case .recent: return viewModel.filteredRecent.isEmpty
        case .fills: return viewModel.filteredFills.isEmpty
        }
    }
}

enum OrdersSegment: String, CaseIterable, Identifiable {
    case open
    case recent
    case fills

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: return "Open"
        case .recent: return "Recent"
        case .fills: return "Fills"
        }
    }

    /// Catalog key for the segment title — drives the Picker's
    /// localized rendering via ``LocalizedStringKey``. Keep parallel
    /// to ``title`` until the raw-string ``title`` callers are
    /// migrated.
    var titleKey: String {
        switch self {
        case .open: return "orders.segment.open"
        case .recent: return "orders.segment.recent"
        case .fills: return "orders.segment.fills"
        }
    }
}

private struct OrderRow: View {
    let order: OrderStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(order.instrument)
                    .font(.headline)
                Spacer()
                Text(order.status)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusBackgroundColor)
                    .cornerRadius(4)
            }
            HStack {
                Text("\(order.side) \(order.orderType)")
                Spacer()
                Text(String(format: "Size: %.4f", order.size))
            }
            .font(.caption)
            .foregroundColor(.secondary)
            if let price = order.price {
                Text(String(format: "Price: %.4f", price))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusBackgroundColor: Color {
        switch order.status {
        case "filled":
            return .brandGreen.opacity(0.2)
        case "cancelled", "rejected":
            return .lossRed.opacity(0.2)
        case "partially_filled":
            return .orange.opacity(0.2)
        default:
            return .brandRed.opacity(0.2)
        }
    }
}

private struct ExecutionRow: View {
    let execution: ExecutionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(execution.instrument)
                    .font(.headline)
                Spacer()
                Text(execution.side)
                    .font(.caption)
                    .foregroundColor(execution.side == "buy" ? .profitGreen : .lossRed)
            }
            HStack {
                Text(String(format: "Filled %.4f @ %.4f", execution.lastSize, execution.lastPrice))
                Spacer()
                Text(String(format: "Fee: %.4f %@", execution.fee, execution.feeAsset))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct OrdersView_Previews: PreviewProvider {
    static var previews: some View {
        OrdersView()
            .environment(AppState.shared)
            .environmentObject(AuthService.shared)
    }
}
