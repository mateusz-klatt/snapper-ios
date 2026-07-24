import SwiftUI

/// Read-only server-health snapshot: overall status, version,
/// connection stats, and provenance gap-detection counters, sourced
/// from `GET /api/health`. Pushed from ``HomeView`` (nested in its
/// ``NavigationStack``) rather than owning a tab — Home already
/// surfaces trader/connection status, so this reads as its details
/// drill-down and avoids deepening the tab bar's "More" overflow.
///
/// Not wallet-scoped (health is a system-wide snapshot); pull-to-refresh
/// only, since `/health` has no live-push channel.
struct HealthView: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel: HealthViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.health == nil {
                    ProgressView(LocalizedStringKey("common.loading"))
                } else if HealthViewModel.shouldShowLoadError(
                    hasData: viewModel.health != nil,
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
                } else if let health = viewModel.health {
                    healthList(health)
                } else {
                    List {
                        ContentUnavailableView(
                            LocalizedStringKey("health.empty.title"),
                            systemImage: "heart.text.square",
                            description: Text(LocalizedStringKey("health.empty.message"))
                        )
                        .listRowBackground(Color.clear)
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
        .navigationTitle(LocalizedStringKey("health.navTitle"))
        .task {
            if viewModel == nil {
                viewModel = HealthViewModel()
            }
            await viewModel?.load()
        }
    }

    private func healthList(_ health: HealthCheckData) -> some View {
        let severity = HealthViewModel.severity(for: health.status)
        let color = severityColor(severity)
        return List {
            Section {
                HStack(spacing: 10) {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                    Text(LocalizedStringKey(severity.localizationKey))
                        .font(.headline)
                        .foregroundStyle(color)
                    Spacer()
                }
                stringRow(labelKey: "health.version", value: health.version)
            }
            Section(LocalizedStringKey("health.section.connections")) {
                statRow(labelKey: "health.connections.active", value: health.connections.activeConnections)
                statRow(labelKey: "health.connections.zmqSubscribers", value: health.connections.zmqSubscribers)
                statRow(labelKey: "health.connections.subscriberTasks", value: health.connections.subscriberTasks)
                statRow(labelKey: "health.connections.activeTopics", value: health.topics.active)
                statRow(labelKey: "health.connections.activeClients", value: health.connections.activeClients)
            }
            Section(LocalizedStringKey("health.section.gapDetection")) {
                statRow(labelKey: "health.gaps.detected", value: health.gapDetection.bridge.gapsDetected)
                statRow(labelKey: "health.gaps.sessionResets", value: health.gapDetection.bridge.sessionResets)
                statRow(labelKey: "health.gaps.duplicates", value: health.gapDetection.bridge.duplicates)
                statRow(labelKey: "health.gaps.midStreamJoins", value: health.gapDetection.bridge.midStreamJoins)
                statRow(labelKey: "health.gaps.rejectedUnstamped", value: health.gapDetection.bridge.rejectedUnstamped)
                statRow(labelKey: "health.gaps.restClients", value: health.gapDetection.restClients?.count)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgBase)
        .refreshable { await viewModel?.load() }
    }

    private func severityColor(_ severity: HealthSeverity) -> Color {
        switch severity {
        case .healthy: return Color.financialRising(for: appState)
        case .warning: return .orange
        case .error: return Color.financialFalling(for: appState)
        case .unknown: return .secondary
        }
    }

    private func statRow(labelKey: String, value: Int?) -> some View {
        HStack {
            Text(LocalizedStringKey(labelKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value.map { $0.description } ?? "—")
                .font(.subheadline)
                .monospacedDigit()
        }
    }

    private func stringRow(labelKey: String, value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(labelKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value)
                .font(.subheadline)
                .monospacedDigit()
        }
    }
}

/// Tappable Home entry that pushes ``HealthView``. Mirrors
/// ``MarketEntryCard``'s card styling (icon tile + title/subtitle +
/// forward chevron that auto-mirrors under RTL).
struct HealthEntryCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("health.navTitle"))
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(LocalizedStringKey("health.entry.subtitle"))
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

struct HealthView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HealthView()
                .environment(AppState.shared)
        }
    }
}
