import Combine
import Foundation
import Observation
import os

/// ViewModel for ``StrategiesView`` — the read-only list of configured
/// trading strategies from ``APIClientProtocol/fetchStrategies``
/// (`GET /api/strategies`).
///
/// Mirrors ``AiReviewsViewModel``/``BacktestsViewModel``: typed error
/// handling, pure ``static`` decision helpers. Not client-side
/// wallet-scoped: the ``StrategyProcess`` read type carries no wallet and
/// the backend endpoint is permission-scoped server-side, so there is no
/// filter and no ``WalletPicker``. Read-only — the web's register /
/// edit-scope / start / stop actions and the live-heartbeat WebSocket
/// telemetry are out of scope for this first cut. Pull-to-refresh only.
@MainActor
@Observable
final class StrategiesViewModel {

    var strategies: [StrategyProcess] = []
    var isLoading: Bool = false
    var loadError: APIError?

    @ObservationIgnored private let liveUpdates = LiveUpdateObserver()

    private let api: APIClientProtocol

    private let logger = AppLogger.make(category: "StrategiesViewModel")

    init(api: APIClientProtocol = APIClient.shared) {
        self.api = api
    }

    /// Begin observing live `strategy_list_event` frames plus the reconnect
    /// heal for a debounced REST reload. Returns the session token to hand
    /// back to ``stopObservingLiveUpdates(token:)`` so a stale view-task
    /// teardown cannot stop a newer session.
    @discardableResult
    func startObservingLiveUpdates(from webSocketManager: WebSocketManager) -> UInt64 {
        let state = webSocketManager.state
        return liveUpdates.start(
            slots: [LiveUpdateObserver.pulse(state.$lastStrategyList)],
            connection: webSocketManager.$connectionState.eraseToAnyPublisher(),
            reload: { [weak self] in await self?.load() }
        )
    }

    /// Cancel observation + any pending debounced reload for `token`. A
    /// stale token (a superseded session) is a no-op.
    func stopObservingLiveUpdates(token: UInt64) {
        liveUpdates.stop(session: token)
    }

    /// Name-sorted rows for a stable render order.
    var sortedStrategies: [StrategyProcess] {
        return strategies.sorted { $0.name < $1.name }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            strategies = try await api.fetchStrategies()
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch strategies: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch strategies: \(error.localizedDescription, privacy: .public)")
            loadError = .invalidResponse
        }
    }

    /// Surface the "couldn't load" variant only when there is nothing
    /// cached to show and a load has settled.
    static func shouldShowLoadError(
        count: Int,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard loadError != nil else { return false }
        return count == 0
    }

    /// Catalog key for a strategy's run state — ``running`` / ``stopped``.
    static func runningLabelKey(_ running: Bool) -> String {
        return running ? "strategies.status.running" : "strategies.status.stopped"
    }

    /// Human display name: drop the ``strategy_`` prefix and render each
    /// ``_``-separated segment upper-cased (``strategy_macd_btc`` →
    /// ``MACD BTC``), matching the web card. Falls back to the raw name
    /// if the transform would produce an empty string.
    static func displayName(for name: String) -> String {
        let base = name.hasPrefix("strategy_")
            ? String(name.dropFirst("strategy_".count))
            : name
        let joined = base
            .split(separator: "_")
            .map { $0.uppercased() }
            .joined(separator: " ")
        return joined.isEmpty ? name : joined
    }
}
