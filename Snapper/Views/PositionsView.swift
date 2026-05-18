import SwiftUI

/// Wrapper that pairs a `PositionSnapshot` with an `Identifiable`
/// conformance for SwiftUI `sheet(item:)` driving without
/// retroactively conforming the generated `PositionData` type.
private struct IdentifiedPosition: Identifiable {
    let position: PositionSnapshot

    var id: String { position.publicId }
}

/// Positions list with reduce / close actions (iOS-Position-Mutations).
///
/// Refactored to MVVM in v0.3.1 — data, async I/O, and the four
/// submit flows live in `PositionsViewModel`. The View binds
/// sheet/alert presentation flags via `@State`.
struct PositionsView: View {

    @Environment(AppState.self) private var appState
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var webSocketManager: WebSocketManager
    @State private var viewModel: PositionsViewModel?

    @State private var actionSheetPosition: PositionSnapshot?
    @State private var reduceModalPosition: IdentifiedPosition?
    @State private var bracketModalPosition: IdentifiedPosition?
    @State private var trailingStopModalPosition: IdentifiedPosition?
    @State private var pendingClosePosition: PositionSnapshot?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.isLoading && viewModel.filteredPositions.isEmpty {
                        ProgressView(LocalizedStringKey("positions.loading"))
                    } else if PositionsViewModel.shouldShowLoadError(
                        filteredCount: viewModel.filteredPositions.count,
                        loadError: viewModel.loadError,
                        isLoading: viewModel.isLoading
                    ), let loadError = viewModel.loadError {
                        ContentUnavailableView(
                            LocalizedStringKey("positions.error.loadFailed.title"),
                            systemImage: "exclamationmark.triangle",
                            description: Text(loadError.localizedDescription)
                        )
                        .overlay(alignment: .bottom) {
                            Button(LocalizedStringKey("common.retry")) {
                                Task { await viewModel.load() }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                    } else if viewModel.filteredPositions.isEmpty {
                        ContentUnavailableView(
                            LocalizedStringKey("positions.empty.title"),
                            systemImage: "chart.line.flattrend.xyaxis",
                            description: Text(LocalizedStringKey("positions.empty.message"))
                        )
                    } else {
                        List(viewModel.filteredPositions, id: \.publicId) { position in
                            if authService.hasPermission(.managePositions) {
                                Button {
                                    actionSheetPosition = position
                                } label: {
                                    PositionCard(position: position)
                                }
                                .buttonStyle(.plain)
                            } else {
                                PositionCard(position: position)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .background(Color.bgBase)
                        .refreshable { await viewModel.load() }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("positions.navTitle"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    WalletPicker()
                }
            }
        }
        .task(id: appState.selectedWalletPublicId) {
            if viewModel == nil {
                viewModel = PositionsViewModel(appState: appState)
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
        .confirmationDialog(
            actionSheetPosition.map { "\($0.instrument) on \($0.exchange)" } ?? "",
            isPresented: Binding(
                get: { actionSheetPosition != nil },
                set: { if !$0 { actionSheetPosition = nil } }
            ),
            presenting: actionSheetPosition
        ) { position in
            if authService.hasPermission(.managePositions) {
                if PositionsViewModel.canSubmitReduce(position: position) {
                    Button(LocalizedStringKey("positions.row.actions.close"), role: .destructive) {
                        pendingClosePosition = position
                    }
                    .accessibilityLabel(LocalizedStringKey("positions.accessibility.label.closeButton"))
                    Button(LocalizedStringKey("positions.row.actions.reduce")) {
                        reduceModalPosition = IdentifiedPosition(position: position)
                    }
                    .accessibilityLabel(LocalizedStringKey("positions.accessibility.label.reduceButton"))
                }
                if position.positionCyclePublicId != nil {
                    Button(LocalizedStringKey("trading.bracket.attach")) {
                        bracketModalPosition = IdentifiedPosition(position: position)
                    }
                    Button(LocalizedStringKey("trading.trailingStop.attach")) {
                        trailingStopModalPosition = IdentifiedPosition(position: position)
                    }
                }
            }
            Button(LocalizedStringKey("positions.reduce.cancel"), role: .cancel) {
                actionSheetPosition = nil
            }
        } message: { position in
            Text(
                "\(PositionCard.direction(for: position.quantity)) \(position.quantity.formattedDecimal(in: appState.locale, fractionDigits: 4)) @ \(position.averagePrice.formattedDecimal(in: appState.locale, fractionDigits: 4))"
            )
        }
        .alert(
            "Close \(pendingClosePosition?.instrument ?? "position")?",
            isPresented: Binding(
                get: { pendingClosePosition != nil },
                set: { if !$0 { pendingClosePosition = nil } }
            ),
            presenting: pendingClosePosition
        ) { position in
            Button(LocalizedStringKey("positions.row.actions.close"), role: .destructive) {
                Task { await viewModel?.submitMarketReduce(position: position, quantity: abs(position.quantity)) }
            }
            Button(LocalizedStringKey("positions.reduce.cancel"), role: .cancel) {
                pendingClosePosition = nil
            }
        } message: { position in
            Text(
                "Submits a reduce-only market order for \(abs(position.quantity).formattedDecimal(in: appState.locale, fractionDigits: 4)) \(position.instrument)."
            )
        }
        .sheet(item: $reduceModalPosition) { wrapper in
            ReducePositionView(
                position: wrapper.position,
                onSubmit: { quantity in
                    await viewModel?.submitMarketReduce(position: wrapper.position, quantity: quantity) ?? false
                }
            )
        }
        .sheet(item: $bracketModalPosition) { wrapper in
            AttachBracketSheet(
                position: wrapper.position,
                onSubmit: { slPrice, tpPrice, idempotencyKey in
                    await viewModel?.submitBracket(
                        position: wrapper.position,
                        slPrice: slPrice,
                        tpPrice: tpPrice,
                        idempotencyKey: idempotencyKey
                    ) ?? false
                }
            )
        }
        .sheet(item: $trailingStopModalPosition) { wrapper in
            AttachTrailingStopSheet(
                position: wrapper.position,
                onSubmit: { trailingPct, minLockPct, idempotencyKey in
                    await viewModel?.submitTrailingStop(
                        position: wrapper.position,
                        trailingPct: trailingPct,
                        minLockPct: minLockPct,
                        idempotencyKey: idempotencyKey
                    ) ?? false
                }
            )
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
}

struct ReducePositionView: View {
    let position: PositionSnapshot
    let onSubmit: (Double) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var quantity: Double
    @State private var isSubmitting = false

    init(
        position: PositionSnapshot,
        onSubmit: @escaping (Double) async -> Bool
    ) {
        self.position = position
        self.onSubmit = onSubmit
        _quantity = State(initialValue: abs(position.quantity) * 0.5)
    }

    private var maxQuantity: Double {
        return abs(position.quantity)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("common.position.label")) {
                    HStack {
                        Text(position.instrument)
                            .font(.headline)
                        Spacer()
                        Text("\(PositionCard.direction(for: position.quantity)) \(position.quantity.formattedDecimal(in: appState.locale, fractionDigits: 4))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(LocalizedStringKey("common.averagePrice.label"))
                        Spacer()
                        Text(position.averagePrice.formattedDecimal(in: appState.locale, fractionDigits: 4))
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    HStack {
                        Text(LocalizedStringKey("positions.reduce.sizeLabel"))
                        Spacer()
                        Text(quantity.formattedDecimal(in: appState.locale, fractionDigits: 4))
                            .font(.body.monospaced())
                    }
                    Slider(value: $quantity, in: 0...maxQuantity)
                    HStack {
                        ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { ratio in
                            Button(ratio.formattedPercent(in: appState.locale, fractionDigits: 0)) {
                                quantity = maxQuantity * ratio
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("trading.order.quantityLabel"))
                } footer: {
                    Text(LocalizedStringKey("positions.reduce.footer"))
                }
            }
            .navigationTitle(LocalizedStringKey("positions.reduce.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("positions.reduce.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("positions.reduce.confirm")) {
                        Task {
                            isSubmitting = true
                            let succeeded = await onSubmit(quantity)
                            isSubmitting = false
                            if succeeded {
                                dismiss()
                            }
                        }
                    }
                    .disabled(quantity <= 0 || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    ProgressView().controlSize(.large)
                }
            }
        }
    }
}

struct PositionCard: View {
    let position: PositionSnapshot

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(position.instrument)
                    .font(.headline)
                Text(directionLabel)
                    .font(.caption)
                    .foregroundStyle(directionColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(position.unrealizedPnl.formattedCurrency(in: appState.locale, code: "USD", fractionDigits: 2))
                    .font(.body.monospaced())
                    .foregroundStyle(position.unrealizedPnl >= 0 ? Color.financialRising(for: appState) : Color.financialFalling(for: appState))
                Text(String(
                    format: LocaleStrings.localized("positions.row.avgPrice", in: appState.locale.catalogLanguage),
                    position.averagePrice.formattedDecimal(in: appState.locale, fractionDigits: 4)
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    static func direction(for quantity: Double) -> String {
        if quantity > 0 { return "Long" }
        if quantity < 0 { return "Short" }
        return "Flat"
    }

    private var directionLabel: String {
        return "\(Self.direction(for: position.quantity)) · \(position.quantity.formattedDecimal(in: appState.locale, fractionDigits: 4))"
    }

    private var directionColor: Color {
        if position.quantity > 0 { return Color.financialRising(for: appState) }
        if position.quantity < 0 { return Color.financialFalling(for: appState) }
        return .secondary
    }
}

struct PositionsView_Previews: PreviewProvider {
    static var previews: some View {
        PositionsView()
            .environment(AppState.shared)
            .environmentObject(AuthService.shared)
    }
}
