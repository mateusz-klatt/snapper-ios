import SwiftUI

/// Read-only list of configured trading strategies from
/// `GET /api/strategies`. Pushed from ``HomeView`` (nested in its
/// ``NavigationStack``) rather than owning a tab, mirroring
/// ``BacktestsView``. Not client-side wallet-scoped (see
/// ``StrategiesViewModel``); pull-to-refresh only. The web's register /
/// edit-scope / start / stop actions and the live-heartbeat telemetry
/// are out of scope for this first cut.
struct StrategiesView: View {

    @EnvironmentObject private var webSocketManager: WebSocketManager
    @State private var viewModel: StrategiesViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.strategies.isEmpty {
                    ProgressView(LocalizedStringKey("common.loading"))
                } else if StrategiesViewModel.shouldShowLoadError(
                    count: viewModel.strategies.count,
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
                        if viewModel.strategies.isEmpty {
                            ContentUnavailableView(
                                LocalizedStringKey("strategies.empty.title"),
                                systemImage: "brain.head.profile",
                                description: Text(LocalizedStringKey("strategies.empty.message"))
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(viewModel.sortedStrategies, id: \.publicId) { strategy in
                                StrategyRow(strategy: strategy)
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
        .navigationTitle(LocalizedStringKey("strategies.navTitle"))
        .task {
            if viewModel == nil {
                viewModel = StrategiesViewModel()
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

/// One strategy row: display name + running badge, then a mode metric
/// and an optional autostart badge.
private struct StrategyRow: View {
    let strategy: StrategyProcess

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(verbatim: StrategiesViewModel.displayName(for: strategy.name))
                    .font(.subheadline.weight(.medium))
                Spacer()
                runningBadge
            }
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(LocalizedStringKey("strategies.field.mode"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(verbatim: strategy.mode)
                        .font(.caption2.monospaced())
                }
                if strategy.enabled {
                    Text(LocalizedStringKey("strategies.badge.autostart"))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var runningBadge: some View {
        let color = strategy.running ? Color.financialRising(for: appState) : Color.secondary
        return Text(LocalizedStringKey(StrategiesViewModel.runningLabelKey(strategy.running)))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Tappable Home entry that pushes ``StrategiesView`` — mirrors
/// ``HealthEntryCard``.
struct StrategiesEntryCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("strategies.navTitle"))
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(LocalizedStringKey("strategies.entry.subtitle"))
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

struct StrategiesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StrategiesView()
                .environment(AppState.shared)
                .environmentObject(WebSocketManager.shared)
        }
    }
}
