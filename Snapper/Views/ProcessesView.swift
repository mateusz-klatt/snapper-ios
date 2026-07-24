import SwiftUI

/// A pending destructive confirmation for one row: stop / disable (both
/// use the stop copy) or restart. Start / enable are plain, non-destructive
/// actions and bypass this flow.
private struct ProcessConfirmRequest: Identifiable {
    enum Kind {
        case stop
        case restart
    }

    let name: String
    let kind: Kind
    let mode: ProcessControlMode

    var id: String {
        return "\(name)-\(kind == .stop ? "stop" : "restart")"
    }
}

/// Process monitor from `GET /api/processes/summary` with lifecycle
/// controls: a per-category running/total header over a per-process list
/// (name, role, running state, memory, CPU) plus per-row start / stop /
/// restart and desired-state actions. Pushed from ``HomeView`` (nested in
/// its ``NavigationStack``) rather than owning a tab, mirroring
/// ``HealthView``. Not wallet-scoped (system-wide).
///
/// Controls appear only for a caller holding ``manage:processes`` and only
/// on rows with a configured match that is neither a strategy/backtest role
/// nor a config-only template — the routing (local start/stop vs remote
/// desired-state) is decided by ``ProcessesViewModel/controlMode``. A stop,
/// disable, or restart is confirmed first; a start or enable fires
/// immediately. Pull-to-refresh plus the live process-event observer keep
/// the list fresh (no optimistic updates).
struct ProcessesView: View {

    @Environment(AppState.self) private var appState
    @EnvironmentObject private var webSocketManager: WebSocketManager
    @State private var viewModel: ProcessesViewModel?
    @State private var confirmRequest: ProcessConfirmRequest?

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
                    summaryList(viewModel, summary: summary, processes: viewModel.sortedProcesses)
                }
            } else {
                ProgressView(LocalizedStringKey("common.loading"))
            }
        }
        .navigationTitle(LocalizedStringKey("processes.navTitle"))
        .confirmationDialog(
            confirmTitle(for: confirmRequest),
            isPresented: Binding(
                get: { confirmRequest != nil },
                set: { if !$0 { confirmRequest = nil } }
            ),
            titleVisibility: .visible,
            presenting: confirmRequest
        ) { request in
            Button(
                LocalizedStringKey(request.kind == .stop ? "processes.control.stop" : "processes.control.restart"),
                role: .destructive
            ) {
                runConfirmed(request)
            }
            Button(LocalizedStringKey("processes.action.cancel"), role: .cancel) {
                confirmRequest = nil
            }
        } message: { request in
            confirmMessage(for: request)
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
            Text(verbatim: error)
        }
        .task {
            if viewModel == nil {
                viewModel = ProcessesViewModel()
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

    private func summaryList(
        _ viewModel: ProcessesViewModel,
        summary: ProcessSummaryData,
        processes: [ProcessSummaryItem]
    ) -> some View {
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
                        row(for: item, viewModel: viewModel)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgBase)
        .refreshable { await viewModel.load() }
    }

    private func row(for item: ProcessSummaryItem, viewModel: ProcessesViewModel) -> some View {
        let mode = viewModel.controlMode(for: item.name)
        return ProcessRow(
            item: item,
            mode: mode,
            configured: viewModel.configuredByName[item.name],
            isBusy: viewModel.isInFlight(item.name) || viewModel.isPending(item.name),
            onStart: { Task { await viewModel.start(name: item.name, expected: mode) } },
            onStop: { confirmRequest = ProcessConfirmRequest(name: item.name, kind: .stop, mode: mode) },
            onRestart: { confirmRequest = ProcessConfirmRequest(name: item.name, kind: .restart, mode: mode) }
        )
    }

    private func runConfirmed(_ request: ProcessConfirmRequest) {
        guard let viewModel else { return }
        Task {
            switch request.kind {
            case .stop:
                await viewModel.stop(name: request.name, expected: request.mode)
            case .restart:
                await viewModel.restart(name: request.name, expected: request.mode)
            }
        }
    }

    private func confirmTitle(for request: ProcessConfirmRequest?) -> Text {
        guard let request else { return Text(verbatim: "") }
        let key = request.kind == .stop ? "processes.action.stop.title" : "processes.action.restart.title"
        let language = appState.locale.catalogLanguage
        let template = LocaleStrings.localized(key, in: language)
        return Text(verbatim: String(format: template, locale: Locale(identifier: language.rawValue), request.name))
    }

    private func confirmMessage(for request: ProcessConfirmRequest) -> Text {
        let key = request.kind == .stop ? "processes.action.stop.message" : "processes.action.restart.message"
        let language = appState.locale.catalogLanguage
        let template = LocaleStrings.localized(key, in: language)
        return Text(verbatim: String(format: template, locale: Locale(identifier: language.rawValue), request.name))
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

/// One process row: name + role tag + running badge, then memory / CPU,
/// then (when the caller may control it) the lifecycle action buttons.
private struct ProcessRow: View {
    let item: ProcessSummaryItem
    let mode: ProcessControlMode
    let configured: ConfiguredProcess?
    let isBusy: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void

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
            if mode != .none {
                controls
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var controls: some View {
        VStack(alignment: .leading, spacing: 6) {
            if mode == .remote {
                managedRemotelyNotice
            }
            HStack(spacing: 8) {
                if item.running {
                    stopButton
                } else {
                    startButton
                }
                if ProcessesViewModel.showsRestart(mode: mode, running: item.running, configured: configured) {
                    restartButton
                }
            }
        }
        .padding(.top, 2)
    }

    private var startButton: some View {
        Button(action: onStart) {
            controlContent(isBusy ? "processes.control.starting" : "processes.control.start")
        }
        .buttonStyle(.bordered)
        .tint(.green)
        .disabled(isBusy)
        .accessibilityIdentifier("processes.control.start.\(item.name)")
    }

    private var stopButton: some View {
        Button(role: .destructive, action: onStop) {
            controlContent(isBusy ? "processes.control.stopping" : "processes.control.stop")
        }
        .buttonStyle(.bordered)
        .disabled(isBusy)
        .accessibilityIdentifier("processes.control.stop.\(item.name)")
    }

    private var restartButton: some View {
        Button(action: onRestart) {
            controlContent("processes.control.restart")
        }
        .buttonStyle(.bordered)
        .tint(.blue)
        .disabled(isBusy)
        .accessibilityIdentifier("processes.control.restart.\(item.name)")
    }

    private func controlContent(_ key: String) -> some View {
        HStack(spacing: 6) {
            if isBusy {
                ProgressView().controlSize(.mini)
            }
            Text(LocalizedStringKey(key))
                .font(.caption.weight(.medium))
        }
    }

    private var managedRemotelyNotice: some View {
        let language = appState.locale.catalogLanguage
        let coordinator = configured?.coordinatorLabel
            ?? configured?.coordinator
            ?? LocaleStrings.localized("processes.control.remoteCoordinatorUnknown", in: language)
        let template = LocaleStrings.localized("processes.control.managedRemotely", in: language)
        return HStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: String(format: template, locale: Locale(identifier: language.rawValue), coordinator))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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
                .environmentObject(AuthService.shared)
                .environmentObject(WebSocketManager.shared)
        }
    }
}
