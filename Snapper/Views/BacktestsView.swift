import SwiftUI

/// Read-only list of backtest runs, sourced from `GET /api/backtests`.
/// Pushed from ``HomeView`` (nested in its ``NavigationStack``) rather
/// than owning a tab, mirroring ``HealthView`` — keeps the tab bar at
/// six. Not client-side wallet-scoped: the backend already scopes the
/// list to the session's active wallet (see ``BacktestsViewModel``), so
/// there is no ``WalletPicker`` here. Pull-to-refresh only. The web's
/// create / cancel / rerun actions and the detail / compare /
/// live-progress views are out of scope for this first cut.
struct BacktestsView: View {

    @State private var viewModel: BacktestsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.backtests.isEmpty {
                    ProgressView(LocalizedStringKey("common.loading"))
                } else if BacktestsViewModel.shouldShowLoadError(
                    count: viewModel.backtests.count,
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
                } else if viewModel.backtests.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("backtests.empty.title"),
                        systemImage: "chart.bar.xaxis",
                        description: Text(LocalizedStringKey("backtests.empty.message"))
                    )
                } else {
                    List(viewModel.backtests, id: \.publicId) { run in
                        BacktestRow(run: run)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.bgBase)
                    .refreshable { await viewModel.load() }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("backtests.navTitle"))
        .task {
            if viewModel == nil {
                viewModel = BacktestsViewModel()
            }
            await viewModel?.load()
        }
    }
}

/// One backtest run row: strategy + status badge, instrument / exchange,
/// then labelled timeframe / period / initial-cash / id metrics and any
/// run error.
private struct BacktestRow: View {
    let run: BacktestRunData

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: run.strategyName)
                    .font(.headline)
                Spacer()
                statusBadge
            }

            HStack(spacing: 6) {
                Text(verbatim: run.instrument ?? run.instrumentPublicId)
                    .font(.caption.monospaced())
                Text(verbatim: run.exchange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let target = run.targetExecutionExchange, !target.isEmpty {
                    Text(verbatim: "→ \(target)")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }

            metricRow(labelKey: "backtests.field.timeframe", value: run.timeframe)
            metricRow(labelKey: "backtests.field.period", value: periodText)
            metricRow(
                labelKey: "backtests.field.initialCash",
                value: run.initialCash.formattedCurrency(in: appState.locale, code: "USD", fractionDigits: 2)
            )
            metricRow(labelKey: "backtests.field.id", value: String(run.publicId.prefix(12)))

            if let error = run.error, !error.isEmpty {
                Text(verbatim: error)
                    .font(.caption)
                    .foregroundStyle(Color.financialFalling(for: appState))
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusBadge: some View {
        let tier = BacktestsViewModel.statusTier(run.status)
        let color = statusColor(tier)
        return Text(LocalizedStringKey(tier.localizationKey))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func statusColor(_ tier: BacktestStatusTier) -> Color {
        switch tier {
        case .completed: return Color.financialRising(for: appState)
        case .failed: return Color.financialFalling(for: appState)
        case .running: return .accentColor
        case .pending, .cancelled, .unknown: return .secondary
        }
    }

    private var periodText: String {
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt)
            .locale(appState.locale.nativeLocale)
        let start = run.startDate.formatted(style)
        let end = run.endDate.formatted(style)
        return "\(start) – \(end)"
    }

    private func metricRow(labelKey: String, value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(labelKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value)
                .font(.caption)
                .monospacedDigit()
        }
    }
}

/// Tappable Home entry that pushes ``BacktestsView`` — mirrors
/// ``HealthEntryCard`` / ``MarketEntryCard``.
struct BacktestsEntryCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("backtests.navTitle"))
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(LocalizedStringKey("backtests.entry.subtitle"))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundColor(.textSecondary)
        }
        .padding(14)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct BacktestsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BacktestsView()
                .environment(AppState.shared)
                .environmentObject(AuthService.shared)
        }
    }
}
