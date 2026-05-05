import SwiftUI

/// Modal sheet for entering a fresh trading order. Mirrors the web
/// frontend's ``NewOrderModal`` at
/// `frontend/src/features/orders/NewOrderModal.tsx`.
///
/// Refactored to MVVM in v0.3.1 — the View is now a thin form-binder
/// over `NewOrderSheetViewModel` (see
/// `Snapper/ViewModels/NewOrderSheetViewModel.swift`). Async fetches,
/// race-guards, idempotency, validation, and body building all live
/// in the VM. The View only owns layout, the `@State`-owned VM
/// instance, and the `dismiss` plumbing.
///
/// Backend route: ``POST /api/orders`` carrying
/// ``CreateOrderCommand``. The submit flow:
/// 1. User picks exchange (loaded from the parent OrdersView's
///    derivedExchanges list).
/// 2. User picks instrument (filtered to ``can_trade == true`` rows
///    so TradFi mirrors are disabled at row level).
/// 3. User picks side / order type / quantity / optional price /
///    optional stop price / leverage / reduce-only toggle.
/// 4. Submit fires the parent-injected `onSubmit` closure (which in
///    turn calls ``APIClient.createOrder`` with provenance from
///    ``EnvelopeMinter``). On success the sheet dismisses; on
///    failure it stays open so the user can correct + retry under
///    the same idempotency key.
struct NewOrderSheet: View {

    @State private var viewModel: NewOrderSheetViewModel
    let onSubmit: (CreateOrderBody) async -> Bool

    @Environment(\.dismiss) private var dismiss

    init(
        exchanges: [String],
        walletPublicId: String,
        walletIsPaper: Bool,
        defaultExchange: String? = nil,
        onSubmit: @escaping (CreateOrderBody) async -> Bool
    ) {
        _viewModel = State(initialValue: NewOrderSheetViewModel(
            exchanges: exchanges,
            walletPublicId: walletPublicId,
            walletIsPaper: walletIsPaper,
            defaultExchange: defaultExchange
        ))
        self.onSubmit = onSubmit
    }

    var body: some View {
        NavigationStack {
            Form {
                if let loadError = viewModel.loadError {
                    Section {
                        Text(loadError).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Venue") {
                    Picker("Exchange", selection: $viewModel.selectedExchange) {
                        ForEach(viewModel.exchanges, id: \.self) { exchange in
                            Text(exchange).tag(exchange)
                        }
                    }
                    Picker("Instrument", selection: Binding(
                        get: { viewModel.selectedInstrument?.instrumentPublicId ?? "" },
                        set: { newId in
                            viewModel.selectedInstrument = viewModel.availableInstruments.first {
                                $0.instrumentPublicId == newId
                            }
                        }
                    )) {
                        Text(viewModel.isLoadingInstruments ? "Loading…" : "Select instrument")
                            .tag("")
                        ForEach(viewModel.availableInstruments.filter { $0.canTrade }, id: \.instrumentPublicId) { row in
                            Text(row.symbol).tag(row.instrumentPublicId)
                        }
                    }
                }

                Section("Order") {
                    Picker("Side", selection: $viewModel.side) {
                        Text("Buy").tag("buy")
                        Text("Sell").tag("sell")
                    }
                    .pickerStyle(.segmented)

                    Picker("Type", selection: $viewModel.orderType) {
                        ForEach(NewOrderSheetViewModel.orderTypes, id: \.self) { type in
                            Text(NewOrderSheetViewModel.displayName(forOrderType: type)).tag(type)
                        }
                    }

                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0.0", text: $viewModel.quantityText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 100)
                    }

                    if viewModel.needsPrice {
                        HStack {
                            Text("Price")
                            Spacer()
                            TextField("0.0", text: $viewModel.priceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 100)
                        }
                    }

                    if viewModel.needsStopPrice {
                        HStack {
                            Text("Stop price")
                            Spacer()
                            TextField("0.0", text: $viewModel.stopPriceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 100)
                        }
                    }
                }

                Section("Risk") {
                    HStack {
                        Text("Leverage")
                        Spacer()
                        TextField("optional", text: $viewModel.leverageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 80)
                    }
                    Toggle("Reduce-only", isOn: $viewModel.reduceOnly)
                }
            }
            .navigationTitle("New order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            // Keep the sheet open on failure so the user can correct
                            // input and retry under the same idempotency key.
                            if await viewModel.submit(via: onSubmit) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView().controlSize(.large)
                }
            }
            .task(id: viewModel.selectedExchange) {
                await viewModel.loadInstruments()
            }
        }
    }
}

struct NewOrderSheet_Previews: PreviewProvider {
    static var previews: some View {
        NewOrderSheet(
            exchanges: ["kraken"],
            walletPublicId: "preview",
            walletIsPaper: true,
            onSubmit: { _ in true }
        )
    }
}
