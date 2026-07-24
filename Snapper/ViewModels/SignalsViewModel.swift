import Combine
import Foundation
import Observation
import os

/// Aggregate counts + mean strength for the Signals summary tiles.
/// Computed purely from the wallet-scoped signal list so the header
/// row is unit-testable without rendering.
struct SignalStats: Equatable {
    let total: Int
    let buy: Int
    let sell: Int
    let averageStrength: Double
}

/// Direction of a signal, resolved defensively from the raw wire
/// ``side`` string. The backend contract is ``"buy"`` / ``"sell"``;
/// ``other`` is the fallback so a malformed / future value renders
/// neutrally instead of being silently mislabelled as a sell.
enum SignalSide {
    case buy
    case sell
    case other
}

/// Graded confidence bucket for a signal's ``strength`` (0.0...1.0).
/// Thresholds mirror the web client (STRONG 0.8, MEDIUM 0.6,
/// WEAK 0.4) so both surfaces label a given strength identically.
enum SignalStrengthTier {
    case strong
    case medium
    case weak
    case veryWeak

    /// Catalog key for the tier label. Kept as a plain ``String`` so
    /// the mapping is asserted directly in unit tests (``LocalizedStringKey``
    /// is opaque and not equatable).
    var localizationKey: String {
        switch self {
        case .strong: return "signals.strength.strong"
        case .medium: return "signals.strength.medium"
        case .weak: return "signals.strength.weak"
        case .veryWeak: return "signals.strength.veryWeak"
        }
    }
}

/// ViewModel for ``SignalsView`` — the read-only trading-signals feed.
///
/// Signals plumbing (``APIClientProtocol.fetchSignals``, the
/// ``SignalData`` / ``TradingSignal`` type, ``AppConfig.Endpoints.signals``)
/// already existed; this VM adds the presentation layer. It mirrors
/// ``PositionsViewModel``'s shape — wallet-scoped filter, typed
/// load-error handling, and pure ``static`` decision helpers — but is
/// read-only: no submit flows and (until ``WSState`` carries a
/// ``lastSignal``) no live-update observation, so the list refreshes
/// via pull-to-refresh only.
@MainActor
@Observable
final class SignalsViewModel {

    var signals: [TradingSignal] = []
    var isLoading: Bool = false
    var loadError: APIError?

    @ObservationIgnored private let liveUpdates = LiveUpdateObserver()

    private let api: APIClientProtocol
    private let appState: AppState

    private let logger = AppLogger.make(category: "SignalsViewModel")

    init(
        api: APIClientProtocol = APIClient.shared,
        appState: AppState = .shared
    ) {
        self.api = api
        self.appState = appState
    }

    /// Begin observing live `signal` pulses (plus the reconnect heal) for
    /// a debounced REST reload. Returns the session token to hand back to
    /// ``stopObservingLiveUpdates(token:)`` so a stale view-task teardown
    /// cannot stop a newer session. Self-cleaning re-entry.
    @discardableResult
    func startObservingLiveUpdates(from webSocketManager: WebSocketManager) -> UInt64 {
        let state = webSocketManager.state
        return liveUpdates.start(
            slots: [LiveUpdateObserver.pulse(state.$lastSignalAt)],
            connection: webSocketManager.$connectionState.eraseToAnyPublisher(),
            reload: { [weak self] in await self?.load() }
        )
    }

    /// Cancel observation + any pending debounced reload for `token`. A
    /// stale token (a superseded session) is a no-op.
    func stopObservingLiveUpdates(token: UInt64) {
        liveUpdates.stop(session: token)
    }

    var filteredSignals: [TradingSignal] {
        return Self.filter(
            signals: signals,
            selectedWalletPublicId: appState.selectedWalletPublicId
        )
    }

    var stats: SignalStats {
        return Self.stats(for: filteredSignals)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            signals = try await api.fetchSignals()
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch signals: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch signals: \(error.localizedDescription, privacy: .public)")
            loadError = .invalidResponse
        }
    }

    /// Pure wallet-match helper. ``nil`` selection passes through every
    /// row, and a ``nil`` row-side wallet passes through so legacy /
    /// system rows are never silently dropped — identical policy to
    /// ``PositionsViewModel.walletMatches``.
    static func walletMatches(rowWalletId: String?, selected: String?) -> Bool {
        guard let selected else { return true }
        guard let rowWalletId else { return true }
        return rowWalletId == selected
    }

    static func filter(
        signals: [TradingSignal],
        selectedWalletPublicId: String?
    ) -> [TradingSignal] {
        return signals.filter { signal in
            walletMatches(
                rowWalletId: signal.walletPublicId,
                selected: selectedWalletPublicId
            )
        }
    }

    /// Decision helper for the error-state branch — returns ``true``
    /// only when the body should render the "couldn't load" variant
    /// instead of the empty state or the cached list. We surface the
    /// error variant solely when there is nothing else to show.
    static func shouldShowLoadError(
        filteredCount: Int,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard loadError != nil else { return false }
        return filteredCount == 0
    }

    /// Case-insensitive side classification. The backend emits the
    /// ``TradeSide`` enum as lowercase ``"buy"`` / ``"sell"``; the
    /// comparison is lowered defensively so a differently-cased value
    /// never miscounts the summary tiles.
    static func isBuy(_ side: String) -> Bool {
        return side.lowercased() == "buy"
    }

    static func isSell(_ side: String) -> Bool {
        return side.lowercased() == "sell"
    }

    /// Three-way side classification used by the row badge. Keeps the
    /// badge consistent with the summary tiles (which count ``isBuy`` /
    /// ``isSell`` explicitly) and gives an unknown value a neutral
    /// ``other`` rendering rather than defaulting it to a sell.
    static func side(for raw: String) -> SignalSide {
        if isBuy(raw) { return .buy }
        if isSell(raw) { return .sell }
        return .other
    }

    /// Summary tiles: total count, buy / sell splits, and the mean
    /// strength across the list (``0`` for an empty list to avoid a
    /// divide-by-zero).
    static func stats(for signals: [TradingSignal]) -> SignalStats {
        let buy = signals.filter { isBuy($0.side) }.count
        let sell = signals.filter { isSell($0.side) }.count
        let averageStrength = signals.isEmpty
            ? 0.0
            : signals.map(\.strength).reduce(0.0, +) / Double(signals.count)
        return SignalStats(
            total: signals.count,
            buy: buy,
            sell: sell,
            averageStrength: averageStrength
        )
    }

    /// Bucket a raw strength into its display tier. Thresholds match
    /// the web client so a 0.82 signal reads "Strong" on both.
    static func strengthTier(_ strength: Double) -> SignalStrengthTier {
        if strength >= 0.8 { return .strong }
        if strength >= 0.6 { return .medium }
        if strength >= 0.4 { return .weak }
        return .veryWeak
    }
}
