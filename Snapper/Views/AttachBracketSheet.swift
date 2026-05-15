import SwiftUI

/// Modal sheet to attach a stop-loss / take-profit bracket to an
/// open position cycle. Mirrors the web frontend's
/// `AttachBracketModal` at
/// `frontend/src/features/positions/AttachBracketModal.tsx`.
///
/// Refactored to MVVM in v0.3.1 — the View is a thin Form binder
/// over `AttachBracketSheetViewModel`. Form state, parsing,
/// idempotency, and submit re-entry guard live in the VM.
///
/// Backend route: `POST /api/execution-plans` carrying
/// `BracketCreateCommand` whose payload links to
/// `position_cycle_public_id`. Backend rejects the request when
/// the cycle is already closed or when neither `sl_price` nor
/// `tp_price` is supplied.
///
/// Either price is optional individually — but the UI requires at
/// least one before enabling the submit button so the user does
/// not fire an empty bracket request that the backend would reject
/// with HTTP 400.
struct AttachBracketSheet: View {

    let position: PositionSnapshot
    let onSubmit: (Double?, Double?, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AttachBracketSheetViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Position") {
                    HStack {
                        Text(position.instrument).font(.headline)
                        Spacer()
                        Text("\(PositionCard.direction(for: position.quantity)) \(String(format: "%.4f", position.quantity))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Average price")
                        Spacer()
                        Text(String(format: "%.4f", position.averagePrice))
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    HStack {
                        Text(LocalizedStringKey("trading.bracket.stopLossLabel"))
                        Spacer()
                        TextField(LocalizedStringKey("trading.bracket.stopLossPlaceholder"), text: $viewModel.slPriceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 100)
                    }
                    HStack {
                        Text(LocalizedStringKey("trading.bracket.takeProfitLabel"))
                        Spacer()
                        TextField(LocalizedStringKey("trading.bracket.takeProfitPlaceholder"), text: $viewModel.tpPriceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 100)
                    }
                } header: {
                    Text("Bracket")
                } footer: {
                    Text("At least one of stop loss / take profit is required. Backend fires reduce-only protective orders when price crosses either level.")
                }
            }
            .navigationTitle(LocalizedStringKey("trading.bracket.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("trading.bracket.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("trading.bracket.submit")) {
                        Task {
                            /// Keep the sheet open on failure so the user can correct
                            /// input and retry under the same idempotency key.
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
        }
    }
}
