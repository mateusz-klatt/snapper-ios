import SwiftUI

/// Read-only process monitor from `GET /api/processes/summary`: a
/// per-category running/total header over a per-process list (name,
/// role, running state, memory, CPU). Pushed from ``HomeView`` (nested
/// in its ``NavigationStack``) rather than owning a tab, mirroring
/// ``HealthView``. Not wallet-scoped (system-wide). Pull-to-refresh only
/// — start / stop / restart and the live-heartbeat WebSocket are out of
/// scope for this first cut.
struct ProcessesView: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel: ProcessesViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.summary == nil {
                    ProgressView(LocalizedStringKey("common.loading"))
                } else if ProcessesViewModel.shouldShowLoadError(
                    hasData: viewModel.summary != nil,
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
                } else if let summary = viewModel.summary {
                    summaryList(summary, processes: viewModel.sortedProcesses)
                }
            } else {
                ProgressView(LocalizedStringKey("common.loading"))
            }
        }
        .navigationTitle(LocalizedStringKey("processes.navTitle"))
        .task {
            if viewModel == nil {
                viewModel = ProcessesViewModel()
            }
            await viewModel?.load()
        }
    }

    private func summaryList(_ summary: ProcessSummaryData, processes: [ProcessSummaryItem]) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    categoryTile(labelKey: "processes.category.feeds", count: summary.feeds)
                    categoryTile(labelKey: "processes.category.strategies", count: summary.strategies)
                    categoryTile(labelKey: "processes.category.executors", count: summary.executors)
                    categoryTile(labelKey: "processes.category.brokers", count: summary.brokers)
                }
                .padding(.vertical, 4)
            }
            Section(LocalizedStringKey("processes.navTitle")) {
                if processes.isEmpty {
                    Text(LocalizedStringKey("processes.empty.message"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(processes, id: \.name) { item in
                        ProcessRow(item: item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgBase)
        .refreshable { await viewModel?.load() }
    }

    private func categoryTile(labelKey: String, count: ProcessCategoryCount) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: "\(count.running)/\(count.total)")
                .font(.title3.bold())
                .monospacedDigit()
            Text(LocalizedStringKey(labelKey))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// One process row: name + role tag + running badge, then memory / CPU.
private struct ProcessRow: View {
    let item: ProcessSummaryItem

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(verbatim: item.name)
                    .font(.subheadline.weight(.medium))
                Text(verbatim: item.role)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                runningBadge
            }
            HStack(spacing: 16) {
                metric(labelKey: "processes.field.memory", value: memoryText)
                metric(labelKey: "processes.field.cpu", value: cpuText)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var runningBadge: some View {
        let color = item.running ? Color.financialRising(for: appState) : Color.secondary
        return Text(LocalizedStringKey(ProcessesViewModel.runningLabelKey(item.running)))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var memoryText: String {
        return ProcessesViewModel.formattedMemory(item.rssBytes)
    }

    private var cpuText: String {
        return ProcessesViewModel.formattedCpuPercent(item.cpuPercent, locale: appState.locale)
    }

    private func metric(labelKey: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(LocalizedStringKey(labelKey))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.caption.monospacedDigit())
        }
    }
}

/// Tappable Home entry that pushes ``ProcessesView`` — mirrors
/// ``HealthEntryCard``.
struct ProcessesEntryCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("processes.navTitle"))
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(LocalizedStringKey("processes.entry.subtitle"))
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

struct ProcessesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProcessesView()
                .environment(AppState.shared)
        }
    }
}
