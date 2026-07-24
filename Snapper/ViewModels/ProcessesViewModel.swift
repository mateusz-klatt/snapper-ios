import Combine
import Foundation
import Observation
import os

/// ViewModel for ``ProcessesView`` — the read-only process monitor from
/// ``APIClientProtocol/fetchProcessSummary`` (`GET /api/processes/summary`,
/// gated by `read:system_status`). Surfaces per-category running/total
/// counts plus a per-process list (name, running state, role, memory,
/// CPU).
///
/// Mirrors ``HealthViewModel``: system-wide (NOT wallet-scoped), typed
/// error handling, pure ``static`` decision helpers. Read-only — the
/// web's start / stop / restart / create actions and the live-heartbeat
/// WebSocket are out of scope for this first cut. Pull-to-refresh only.
@MainActor
@Observable
final class ProcessesViewModel {

    var summary: ProcessSummaryData?
    var isLoading: Bool = false
    var loadError: APIError?

    @ObservationIgnored private let liveUpdates = LiveUpdateObserver()

    private let api: APIClientProtocol

    private let logger = AppLogger.make(category: "ProcessesViewModel")

    init(api: APIClientProtocol = APIClient.shared) {
        self.api = api
    }

    /// Begin observing live process-event frames (summary / configured /
    /// run) plus the reconnect heal for a debounced REST reload. Returns
    /// the session token to hand back to ``stopObservingLiveUpdates(token:)``
    /// so a stale view-task teardown cannot stop a newer session.
    @discardableResult
    func startObservingLiveUpdates(from webSocketManager: WebSocketManager) -> UInt64 {
        let state = webSocketManager.state
        return liveUpdates.start(
            slots: [
                LiveUpdateObserver.pulse(state.$lastProcessSummary),
                LiveUpdateObserver.pulse(state.$lastProcessConfigured),
                LiveUpdateObserver.pulse(state.$lastProcessRun),
            ],
            connection: webSocketManager.$connectionState.eraseToAnyPublisher(),
            reload: { [weak self] in await self?.load() }
        )
    }

    /// Cancel observation + any pending debounced reload for `token`. A
    /// stale token (a superseded session) is a no-op.
    func stopObservingLiveUpdates(token: UInt64) {
        liveUpdates.stop(session: token)
    }

    /// Per-process rows, name-sorted for a stable render order.
    var sortedProcesses: [ProcessSummaryItem] {
        return (summary?.processes ?? []).sorted { $0.name < $1.name }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try await api.fetchProcessSummary()
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch process summary: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch process summary: \(error.localizedDescription, privacy: .public)")
            loadError = .invalidResponse
        }
    }

    /// Surface the "couldn't load" variant only when there is no cached
    /// summary to show and a load has settled.
    static func shouldShowLoadError(
        hasData: Bool,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard loadError != nil else { return false }
        return !hasData
    }

    /// Catalog key for a process's running state — ``running`` /
    /// ``stopped`` — kept pure so the mapping is unit-tested directly.
    static func runningLabelKey(_ running: Bool) -> String {
        return running ? "processes.status.running" : "processes.status.stopped"
    }

    /// Locale-aware memory string for a process's RSS, or ``"—"`` when
    /// the sample is missing (thread-mode / unsampled processes).
    static func formattedMemory(_ rssBytes: Int?) -> String {
        guard let rss = rssBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(rss), countStyle: .memory)
    }

    /// Locale-aware CPU string. ``cpuPercent`` is already a percentage
    /// (``3.5`` means 3.5%), so it is divided by 100 before the percent
    /// formatter — which multiplies back by 100 — renders it. ``"—"``
    /// when the sample is missing.
    static func formattedCpuPercent(_ cpuPercent: Double?, locale: AppLocale) -> String {
        guard let cpu = cpuPercent else { return "—" }
        return (cpu / 100.0).formattedPercent(in: locale, fractionDigits: 1)
    }
}
