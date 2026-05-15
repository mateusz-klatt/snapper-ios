import SwiftUI

/// Modal sheet to attach a trailing-stop plan to an open position
/// cycle. Mirrors the web frontend's `AttachTrailingStopModal` at
/// `frontend/src/features/positions/AttachTrailingStopModal.tsx`.
///
/// Refactored to MVVM in v0.3.1 — the View is a thin Form binder
/// over `AttachTrailingStopSheetViewModel`.
///
/// Backend route: `POST /api/trailing-stops` carrying
/// `TrailingStopCreateCommand` whose payload links to
/// `position_cycle_public_id` and supplies `trailing_pct`
/// (required) plus an optional `min_lock_pct` floor that prevents
/// the trail from moving below a locked-in profit threshold.
struct AttachTrailingStopSheet: View {

    let position: PositionSnapshot
    let onSubmit: (Double, Double?, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = AttachTrailingStopSheetViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("common.position.label")) {
                    HStack {
                        Text(position.instrument).font(.headline)
                        Spacer()
                        Text("\(PositionCard.direction(for: position.quantity)) \(position.quantity.formattedDecimal(in: appState.locale, fractionDigits: 4))")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    HStack {
                        Text(LocalizedStringKey("trading.trailingStop.trailAmountLabel"))
                        Spacer()
                        TextField("1.5", text: $viewModel.trailingPctText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 80)
                        Text(LocalizedStringKey("common.percentSymbol")).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(LocalizedStringKey("trading.trailingStop.activationLabel"))
                        Spacer()
                        TextField(LocalizedStringKey("common.optional.placeholder"), text: $viewModel.minLockPctText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 80)
                        Text(LocalizedStringKey("common.percentSymbol")).foregroundStyle(.secondary)
                    }
                } header: {
                    Text(LocalizedStringKey("trading.trailingStop.section.trailingStop"))
                } footer: {
                    Text(LocalizedStringKey("trading.trailingStop.footer.explanation"))
                }
            }
            .navigationTitle(LocalizedStringKey("trading.trailingStop.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("trading.trailingStop.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("trading.trailingStop.submit")) {
                        Task {
                            /// Keep the sheet open on failure so the user can correct
                            /// input and retry under the same idempotency key.
                            if await viewModel.submit(via: onSubmit) {
                                dismiss()
                            }
                        }
                    }
                    .accessibilityLabel(LocalizedStringKey("trading.trailingStop.accessibility.label.submitButton"))
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
