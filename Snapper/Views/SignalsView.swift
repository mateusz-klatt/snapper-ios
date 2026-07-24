import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// Read-only trading-signals feed. Mirrors ``PositionsView``'s
/// loading / error / empty / list structure but carries no order
/// mutations — signals are strategy-generated buy/sell recommendations
/// the user reviews, not acts on from this screen.
///
/// A summary header (total / buy / sell / average strength) sits above
/// the list, matching the web Signals screen. A toolbar strategy filter
/// narrows the list client-side, and a share-sheet export writes the
/// currently filtered rows to a ``signals.csv`` document. Live updates
/// arrive via ``SignalsViewModel/startObservingLiveUpdates(from:)`` (a
/// debounced reload on ``signals.*`` pulses); pull-to-refresh remains.
struct SignalsView: View {

    @Environment(AppState.self) private var appState
    @EnvironmentObject private var webSocketManager: WebSocketManager
    @State private var viewModel: SignalsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.isLoading && viewModel.filteredSignals.isEmpty {
                        ProgressView(LocalizedStringKey("common.loading"))
                    } else if SignalsViewModel.shouldShowLoadError(
                        filteredCount: viewModel.filteredSignals.count,
                        loadError: viewModel.loadError,
                        isLoading: viewModel.isLoading
                    ), let loadError = viewModel.loadError {
                        ContentUnavailableView(
                            LocalizedStringKey("common.error.loadFailed.title"),
                            systemImage: "exclamationmark.triangle",
                            description: Text(verbatim: loadError.localizedDescription)
                        )
                        .overlay(alignment: .bottom) {
                            Button(LocalizedStringKey("common.retry")) {
                                Task { await viewModel.load() }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                    } else {
                        List {
                            if viewModel.filteredSignals.isEmpty {
                                ContentUnavailableView(
                                    LocalizedStringKey("signals.empty.title"),
                                    systemImage: "waveform.path.ecg",
                                    description: Text(LocalizedStringKey("signals.empty.message"))
                                )
                                .listRowBackground(Color.clear)
                            } else {
                                Section {
                                    SignalStatsHeader(stats: viewModel.stats)
                                }
                                Section {
                                    ForEach(viewModel.filteredSignals, id: \.publicId) { signal in
                                        SignalRow(signal: signal)
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .background(Color.bgBase)
                        .refreshable { await viewModel.load() }
                    }
                } else {
                    ProgressView(LocalizedStringKey("common.loading"))
                }
            }
            .navigationTitle(LocalizedStringKey("signals.navTitle"))
            .toolbar {
                if let viewModel, viewModel.showsStrategyFilter {
                    ToolbarItem(placement: .topBarLeading) {
                        StrategyFilterMenu(viewModel: viewModel)
                    }
                }
                if let viewModel {
                    ToolbarItem(placement: .topBarLeading) {
                        SignalsExportButton(viewModel: viewModel)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    WalletPicker()
                }
            }
        }
        .task(id: appState.selectedWalletPublicId) {
            if viewModel == nil {
                viewModel = SignalsViewModel(appState: appState)
            }
            await viewModel?.load()

            guard !Task.isCancelled, let viewModel else { return }
            let session = viewModel.startObservingLiveUpdates(from: webSocketManager)
            await withTaskCancellationHandler {
                try? await Task.sleep(nanoseconds: .max)
            } onCancel: {
                Task { @MainActor in
                    viewModel.stopObservingLiveUpdates(token: session)
                }
            }
        }
    }
}

/// Four summary tiles derived from the wallet-scoped list: total count,
/// buy / sell splits, and mean strength. "Buy" / "Sell" reuse the shared
/// ``trading.side.*`` catalog labels.
private struct SignalStatsHeader: View {
    let stats: SignalStats

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 12) {
            tile(labelKey: "signals.stats.total", value: Text(verbatim: stats.total.description))
            tile(labelKey: "trading.side.buy", value: Text(verbatim: stats.buy.description))
            tile(labelKey: "trading.side.sell", value: Text(verbatim: stats.sell.description))
            tile(
                labelKey: "signals.stats.avgStrength",
                value: Text(verbatim: stats.averageStrength.formattedPercent(in: appState.locale, fractionDigits: 0))
            )
        }
        .padding(.vertical, 4)
    }

    private func tile(labelKey: String, value: Text) -> some View {
        VStack(spacing: 4) {
            value
                .font(.title3.bold())
                .monospacedDigit()
            Text(LocalizedStringKey(labelKey))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// One signal card: instrument + relative fired-at time, a side/strategy
/// badge row, then labelled strength / price / exchange metrics and the
/// free-text reason.
private struct SignalRow: View {
    let signal: TradingSignal

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: signal.instrument)
                    .font(.headline)
                Spacer()
                Text(signal.firedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                sideBadge
                if let strategy = signal.strategyName, !strategy.isEmpty {
                    Text(verbatim: strategy)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }

            metricRow(labelKey: "signals.card.strength") {
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(SignalsViewModel.strengthTier(signal.strength).localizationKey))
                    Text(verbatim: signal.strength.formattedPercent(in: appState.locale, fractionDigits: 0))
                        .monospacedDigit()
                }
                .foregroundStyle(strengthColor)
            }
            metricRow(labelKey: "signals.card.price") {
                priceValue
            }
            metricRow(labelKey: "signals.card.exchange") {
                Text(verbatim: signal.exchange)
                    .monospacedDigit()
            }

            if !signal.reason.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("signals.card.reason"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(verbatim: signal.reason)
                        .font(.caption)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }

    private var sideBadge: some View {
        sideLabel
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(sideColor.opacity(0.15))
            .foregroundStyle(sideColor)
            .clipShape(Capsule())
    }

    @ViewBuilder private var sideLabel: some View {
        switch SignalsViewModel.side(for: signal.side) {
        case .buy: Text(LocalizedStringKey("trading.side.buy"))
        case .sell: Text(LocalizedStringKey("trading.side.sell"))
        case .other: Text(verbatim: signal.side)
        }
    }

    private var sideColor: Color {
        switch SignalsViewModel.side(for: signal.side) {
        case .buy: return Color.financialRising(for: appState)
        case .sell: return Color.financialFalling(for: appState)
        case .other: return .secondary
        }
    }

    @ViewBuilder private var priceValue: some View {
        if let price = signal.price {
            Text(verbatim: price.formattedCurrency(in: appState.locale, code: "USD", fractionDigits: 2))
                .monospacedDigit()
        } else {
            Text(LocalizedStringKey("signals.card.noPrice"))
                .foregroundStyle(.secondary)
        }
    }

    private var strengthColor: Color {
        switch SignalsViewModel.strengthTier(signal.strength) {
        case .strong: return Color.financialRising(for: appState)
        case .medium, .weak: return .orange
        case .veryWeak: return Color.financialFalling(for: appState)
        }
    }

    private func metricRow<Content: View>(
        labelKey: String,
        @ViewBuilder value: () -> Content
    ) -> some View {
        HStack {
            Text(LocalizedStringKey(labelKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            value()
                .font(.caption)
        }
    }
}

/// Toolbar strategy filter — a menu-backed picker fed by the distinct
/// strategy names in the loaded, wallet-scoped signals plus an "all"
/// default. The selection is client-side and survives live reloads; the
/// funnel fills when a strategy is active.
private struct StrategyFilterMenu: View {
    @Bindable var viewModel: SignalsViewModel

    var body: some View {
        Menu {
            Picker(selection: $viewModel.selectedStrategy) {
                Text(LocalizedStringKey("signals.filters.allStrategies"))
                    .tag(String?.none)
                ForEach(viewModel.availableStrategies, id: \.self) { name in
                    Text(verbatim: name).tag(String?.some(name))
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: viewModel.selectedStrategy == nil
                ? "line.3.horizontal.decrease.circle"
                : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel(Text(LocalizedStringKey("signals.filters.label")))
    }
}

/// Toolbar CSV export — shares the currently filtered signals as a
/// ``signals.csv`` document through the system share sheet. Disabled
/// when the filtered list is empty.
private struct SignalsExportButton: View {
    let viewModel: SignalsViewModel

    var body: some View {
        ShareLink(
            item: SignalsCSVDocument(rows: viewModel.filteredSignals),
            preview: SharePreview(SignalsViewModel.exportFilename)
        ) {
            Label {
                Text(LocalizedStringKey("signals.actions.export"))
            } icon: {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .disabled(!viewModel.canExport)
    }
}

/// A ``Transferable`` CSV rendering of the filtered signals for
/// ``ShareLink``. The CSV is built lazily — only when the share is
/// actually performed — via the pure ``SignalsViewModel/csv(for:)``
/// builder, and carries the deterministic ``signals.csv`` filename.
private struct SignalsCSVDocument: Transferable {
    let rows: [TradingSignal]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            Data(SignalsViewModel.csv(for: document.rows).utf8)
        }
        .suggestedFileName(SignalsViewModel.exportFilename)
    }
}

struct SignalsView_Previews: PreviewProvider {
    static var previews: some View {
        SignalsView()
            .environment(AppState.shared)
            .environmentObject(AuthService.shared)
            .environmentObject(WebSocketManager.shared)
    }
}
