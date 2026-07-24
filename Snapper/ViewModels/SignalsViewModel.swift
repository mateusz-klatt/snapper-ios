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

/// ViewModel for ``SignalsView`` — the trading-signals feed.
///
/// Signals plumbing (``APIClientProtocol.fetchSignals``, the
/// ``SignalData`` / ``TradingSignal`` type, ``AppConfig.Endpoints.signals``)
/// already existed; this VM adds the presentation layer. It mirrors
/// ``PositionsViewModel``'s shape — wallet-scoped filter, typed
/// load-error handling, pure ``static`` decision helpers, and debounced
/// live-reload observation. On top of the wallet scope it composes a
/// client-side strategy filter (``selectedStrategy`` /
/// ``availableStrategies``) and a pure, RFC-4180 CSV builder
/// (``csv(for:)``) driving the share-sheet export. It stays read-only:
/// no order submit flows.
@MainActor
@Observable
final class SignalsViewModel {

    var signals: [TradingSignal] = []
    var isLoading: Bool = false
    var loadError: APIError?

    /// Selected strategy for the client-side filter. ``nil`` is the
    /// "all strategies" default. Held independently of ``signals`` so a
    /// live reload preserves the selection; a value naming a strategy
    /// absent from fresh data simply yields an empty filtered list.
    var selectedStrategy: String?

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

    /// Signals for the selected wallet only, before the strategy filter.
    /// Feeds ``availableStrategies`` and the "is there anything to show or
    /// export" decision so the strategy control stays reachable even when
    /// the active strategy filter narrows the list to empty.
    var walletScopedSignals: [TradingSignal] {
        return Self.filter(
            signals: signals,
            selectedWalletPublicId: appState.selectedWalletPublicId
        )
    }

    /// Wallet scope composed with the client-side strategy filter.
    var filteredSignals: [TradingSignal] {
        return Self.applyStrategyFilter(
            walletScopedSignals,
            selectedStrategy: selectedStrategy
        )
    }

    /// Distinct, first-appearance-ordered strategy names in the
    /// wallet-scoped signals — the strategy picker's options. Scoped to
    /// the selected wallet so the choices match the visible rows.
    var availableStrategies: [String] {
        return Self.distinctStrategies(from: walletScopedSignals)
    }

    /// Whether the CSV export has rows to write — drives the export
    /// button's disabled state. The export control is always rendered
    /// while the view model exists; this only toggles ``disabled``.
    var canExport: Bool {
        return !filteredSignals.isEmpty
    }

    /// Whether the strategy filter control should be shown — see
    /// ``shouldShowStrategyFilter(hasStrategyOptions:hasSelection:)``.
    var showsStrategyFilter: Bool {
        return Self.shouldShowStrategyFilter(
            hasStrategyOptions: !availableStrategies.isEmpty,
            hasSelection: selectedStrategy != nil
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

    /// Client-side strategy predicate. A ``nil`` selection (the "all"
    /// default) passes every row; otherwise the row's ``strategyName``
    /// must equal the selection exactly, so a ``nil`` / empty row
    /// strategy never matches a named selection.
    static func strategyMatches(strategyName: String?, selectedStrategy: String?) -> Bool {
        guard let selectedStrategy else { return true }
        return strategyName == selectedStrategy
    }

    /// Apply the strategy filter to an already wallet-scoped list. A
    /// ``nil`` selection passes the list through unchanged.
    static func applyStrategyFilter(
        _ signals: [TradingSignal],
        selectedStrategy: String?
    ) -> [TradingSignal] {
        guard selectedStrategy != nil else { return signals }
        return signals.filter {
            strategyMatches(strategyName: $0.strategyName, selectedStrategy: selectedStrategy)
        }
    }

    /// Whether the strategy filter control should be shown. It appears
    /// when there are strategy options to pick from OR a selection is
    /// currently active. The ``hasSelection`` arm is essential: a
    /// retained selection that survives a reload into rows carrying only
    /// ``nil`` / empty strategy names leaves ``availableStrategies``
    /// empty, and without this the menu would vanish while the rows stay
    /// filtered out — stranding the user with no way to clear back to
    /// "all strategies".
    static func shouldShowStrategyFilter(hasStrategyOptions: Bool, hasSelection: Bool) -> Bool {
        return hasStrategyOptions || hasSelection
    }

    /// Distinct strategy names in first-appearance order, dropping
    /// ``nil`` and empty names. Mirrors the web client's
    /// ``Array.from(new Set(...filter(Boolean)))`` derivation.
    static func distinctStrategies(from signals: [TradingSignal]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for signal in signals {
            guard let name = signal.strategyName, !name.isEmpty else { continue }
            if seen.insert(name).inserted {
                ordered.append(name)
            }
        }
        return ordered
    }

    /// Deterministic filename for the exported CSV, shared by the share
    /// sheet and asserted in tests. Matches the web export's
    /// ``signals.csv`` pattern.
    nonisolated static let exportFilename = "signals.csv"

    /// Stable English column identifiers for the export. CSV headers are
    /// a data-interchange contract, not localized UI, so they never route
    /// through the catalog. The column set mirrors the web export.
    nonisolated static let csvHeader: [String] = [
        "instrument",
        "exchange",
        "side",
        "strength",
        "strategy",
        "price",
        "reason",
        "fired_at",
    ]

    /// RFC-4180 field escaping: a field containing a comma, double quote,
    /// carriage return, or line feed is wrapped in double quotes with any
    /// embedded quote doubled. Every other field passes through unchanged.
    nonisolated static func csvField(_ value: String) -> String {
        let mustQuote = value.contains(",")
            || value.contains("\"")
            || value.contains("\n")
            || value.contains("\r")
        guard mustQuote else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// ISO-8601 UTC timestamp with millisecond precision (e.g.
    /// ``2023-11-14T22:13:20.000Z``), matching the web export's
    /// ``Date.toISOString()`` so both platforms emit identical values.
    nonisolated static func csvTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// The ordered CSV cells for one signal, aligned to ``csvHeader``.
    /// ``strength`` and ``price`` use the shortest round-trippable
    /// decimal; a ``nil`` price / strategy becomes an empty field.
    nonisolated static func csvRow(for signal: TradingSignal) -> [String] {
        return [
            signal.instrument,
            signal.exchange,
            signal.side,
            signal.strength.description,
            signal.strategyName ?? "",
            signal.price.map { $0.description } ?? "",
            signal.reason,
            Self.csvTimestamp(signal.firedAt),
        ]
    }

    /// Build the full CSV document for the given signals: a header row
    /// followed by one row per signal, fields RFC-4180 escaped, records
    /// separated by CRLF. An empty list yields the header row alone.
    nonisolated static func csv(for signals: [TradingSignal]) -> String {
        let recordSeparator = "\r\n"
        var lines: [String] = [Self.csvHeader.map(Self.csvField).joined(separator: ",")]
        for signal in signals {
            lines.append(Self.csvRow(for: signal).map(Self.csvField).joined(separator: ","))
        }
        return lines.joined(separator: recordSeparator)
    }
}
