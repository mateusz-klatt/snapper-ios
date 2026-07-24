import Foundation
import Observation
import os

/// Loaded time window for the P&L timeline. Durations mirror the web
/// ``PortfolioTimeline`` selector (24h / 7d / 30d / 90d). The window
/// is anchored at screen-entry time and only re-anchored when the
/// user changes it — there is no auto-sliding window, polling, or
/// WebSocket push for this read-only surface.
enum PnlTimelineWindow: String, CaseIterable, Identifiable {
    case h24
    case d7
    case d30
    case d90

    var id: String { rawValue }

    /// Window length in seconds, applied as ``anchor - duration`` for
    /// the ``from`` bound.
    var duration: TimeInterval {
        switch self {
        case .h24: return 24 * 60 * 60
        case .d7: return 7 * 24 * 60 * 60
        case .d30: return 30 * 24 * 60 * 60
        case .d90: return 90 * 24 * 60 * 60
        }
    }

    /// Catalog key for the window's control-row label.
    var titleKey: String {
        switch self {
        case .h24: return "positions.timeline.controls.last24Hours"
        case .d7: return "positions.timeline.controls.last7Days"
        case .d30: return "positions.timeline.controls.last30Days"
        case .d90: return "positions.timeline.controls.last90Days"
        }
    }
}

/// Sampling granularity for the P&L series. ``wireValue`` is the exact
/// backend query token (``1m`` / ``5m`` / ``1h`` / ``1d``);
/// ``coarsenessRank`` orders them from finest to coarsest so the
/// window-change auto-coarsen rule can be expressed as a floor.
enum PnlTimelineGranularity: String, CaseIterable, Identifiable {
    case m1
    case m5
    case h1
    case d1

    var id: String { rawValue }

    /// Backend query token. Rendered verbatim in the control picker
    /// (locale-invariant code, no catalog key).
    var wireValue: String {
        switch self {
        case .m1: return "1m"
        case .m5: return "5m"
        case .h1: return "1h"
        case .d1: return "1d"
        }
    }

    /// Finer-to-coarser rank used by ``PnlTimelineViewModel/defaultGranularity(for:current:)``.
    var coarsenessRank: Int {
        switch self {
        case .m1: return 0
        case .m5: return 1
        case .h1: return 2
        case .d1: return 3
        }
    }
}

/// One grouped withholding reason for the incompleteness summary. A
/// group collapses every point that shares the same
/// ``(scope, trigger, tier, reason)`` identity and counts how many
/// points it affects. Ported verbatim from the web
/// ``IncompletenessSummary`` grouping.
struct PnlIncompletenessGroup: Identifiable {
    let reason: PnlIncompletenessReasonData
    var affectedPointCount: Int
    var triggerContribution: PnlInstrumentContributionData?

    /// Stable identity for SwiftUI ``ForEach`` — derived from the
    /// group's four discriminating fields.
    var id: String {
        let trigger = reason.triggerInstrumentPublicId ?? "∅"
        return [
            reason.withholdingScope.rawValue,
            trigger,
            reason.withholdingTier.rawValue,
            reason.reason.rawValue,
        ].joined(separator: "\u{0}")
    }
}

/// Fully-resolved fingerprint of one P&L series request. Two requests
/// are the same fetch iff every field matches, so the render layer can
/// tell whether a held payload / error still describes the parameters
/// currently on screen (wallet, mode, granularity, window bounds, and
/// valuation currency).
struct PnlSeriesRequestKey: Equatable, Hashable, Sendable {
    let walletPublicId: String
    let mode: String
    let granularity: String
    let from: Date
    let to: Date
    let valuationCcy: String
}

/// Mode-INDEPENDENT fingerprint used to scope ERRORS. Unlike
/// ``PnlSeriesRequestKey`` it omits ``mode``, so it resolves
/// synchronously even when the wallet is not yet cached (mode unknown).
/// This keeps a failed uncached-wallet request uniquely identified: two
/// different uncached wallets (or the same wallet with different
/// controls) produce different attempt keys, so one wallet's error is
/// never mistaken for another's.
struct PnlSeriesAttemptKey: Equatable, Hashable, Sendable {
    let walletPublicId: String
    let granularity: String
    let from: Date
    let to: Date
    let valuationCcy: String
}

/// ViewModel for the native P&L timeline surface hosted inside
/// ``PositionsView`` (``GET /api/portfolio/pnl/series``).
///
/// Read-only, v1: no decision markers, no interaction, no live
/// telemetry. Mode (``live`` / ``paper``) is derived from the selected
/// wallet's ``is_paper`` flag — never guessed; when the wallet is not
/// yet cached in ``AppState/availableWallets`` the VM fetches wallets
/// first (mirroring the web ``walletModeReady`` gate). Cached ``data``
/// survives a failed refresh.
@MainActor
@Observable
final class PnlTimelineViewModel {

    private(set) var data: PnlSeriesData?

    /// Fingerprint of the request that produced ``data``. The render
    /// layer shows the payload ONLY while this still equals the current
    /// request parameters, so a stale payload cannot survive a
    /// wallet / window / granularity / currency change.
    private(set) var loadedKey: PnlSeriesRequestKey?

    private(set) var isLoading: Bool = false
    private(set) var loadError: APIError?

    /// Mode-independent fingerprint the current ``loadError`` belongs to
    /// (``nil`` only when no wallet was selected). Lets the view
    /// distinguish a same-request refresh failure (inline banner over
    /// live data) from a stale error for parameters — or a wallet — that
    /// have since changed, including between two uncached wallets whose
    /// mode could not be resolved.
    private(set) var errorKey: PnlSeriesAttemptKey?

    /// Monotonic request generation. Only the newest in-flight load may
    /// commit state, so a slow older request can never overwrite newer
    /// data nor clear ``isLoading`` during the newer request.
    @ObservationIgnored private var generation: Int = 0

    /// Loaded window. Changing it re-anchors the snapshot and
    /// auto-coarsens the granularity so a wide window never fires a
    /// minute-resolution request that blows the server work budget.
    var window: PnlTimelineWindow = .h24 {
        didSet {
            guard oldValue != window else { return }
            anchor = now()
            granularity = Self.defaultGranularity(for: window, current: granularity)
        }
    }

    var granularity: PnlTimelineGranularity = .m1
    var valuationCcy: String = "USD"

    /// Snapshot instant captured at init and re-captured ONLY on
    /// window change (web parity — the chart does not slide forward).
    private(set) var anchor: Date

    private let api: APIClientProtocol
    private let appState: AppState
    private let now: () -> Date
    private let logger = AppLogger.make(category: "PnlTimelineViewModel")

    /// Valuation currencies offered in the control row (web parity).
    static let valuationCurrencies: [String] = ["USD", "PLN", "EUR"]

    init(
        api: APIClientProtocol = APIClient.shared,
        appState: AppState = .shared,
        now: @escaping () -> Date = { Date() }
    ) {
        self.api = api
        self.appState = appState
        self.now = now
        self.anchor = now()
    }

    /// The request the VM WOULD issue right now, resolved synchronously
    /// from the current controls, anchor, and cached wallet. ``nil``
    /// when no wallet is selected or the wallet's mode is not yet known
    /// (the wallet list is still being fetched).
    func currentRequestKey() -> PnlSeriesRequestKey? {
        guard
            let walletId = appState.selectedWalletPublicId,
            let wallet = appState.availableWallets.first(where: { $0.publicId == walletId })
        else {
            return nil
        }
        return makeKey(walletId: walletId, mode: Self.modeString(isPaper: wallet.isPaper))
    }

    private func makeKey(walletId: String, mode: String) -> PnlSeriesRequestKey {
        return PnlSeriesRequestKey(
            walletPublicId: walletId,
            mode: mode,
            granularity: granularity.wireValue,
            from: anchor.addingTimeInterval(-window.duration),
            to: anchor,
            valuationCcy: valuationCcy
        )
    }

    /// The mode-independent attempt fingerprint for the current
    /// parameters. Resolvable whenever a wallet is selected, even if its
    /// mode is not yet known (wallet still being fetched).
    func currentAttemptKey() -> PnlSeriesAttemptKey? {
        guard let walletId = appState.selectedWalletPublicId else { return nil }
        return PnlSeriesAttemptKey(
            walletPublicId: walletId,
            granularity: granularity.wireValue,
            from: anchor.addingTimeInterval(-window.duration),
            to: anchor,
            valuationCcy: valuationCcy
        )
    }

    /// Payload for the CURRENT request parameters, or ``nil`` when the
    /// held ``data`` was produced by a now-superseded request.
    var freshData: PnlSeriesData? {
        guard let key = currentRequestKey(), key == loadedKey else { return nil }
        return data
    }

    /// The load error that belongs to the current desired request, or
    /// ``nil`` when the outstanding error is for parameters — or a
    /// wallet — that have since changed.
    var currentError: APIError? {
        guard loadError != nil, let errorKey else { return nil }
        return errorKey == currentAttemptKey() ? loadError : nil
    }

    /// Fetch the P&L series for the selected wallet. Clears state and
    /// returns early when no wallet is selected. Derives ``mode`` from
    /// the wallet's ``is_paper`` flag, fetching the wallet list first if
    /// the cache does not yet contain it. Inputs are captured at entry
    /// and tagged with a generation so a slow older request cannot
    /// overwrite newer state; a cancellation never surfaces as an error.
    func load() async {
        generation += 1
        let generationAtEntry = generation
        guard let walletId = appState.selectedWalletPublicId else {
            data = nil
            loadedKey = nil
            loadError = nil
            errorKey = nil
            isLoading = false
            return
        }
        isLoading = true
        let capturedGranularity = granularity.wireValue
        let capturedValuation = valuationCcy
        let capturedTo = anchor
        let capturedFrom = anchor.addingTimeInterval(-window.duration)
        let attemptKey = PnlSeriesAttemptKey(
            walletPublicId: walletId,
            granularity: capturedGranularity,
            from: capturedFrom,
            to: capturedTo,
            valuationCcy: capturedValuation
        )
        do {
            let resolution = try await resolveMode(walletId: walletId)
            guard generationAtEntry == generation else { return }
            if Task.isCancelled {
                isLoading = false
                return
            }
            if let walletsToCommit = resolution.walletsToCommit {
                appState.availableWallets = walletsToCommit
            }
            let key = PnlSeriesRequestKey(
                walletPublicId: walletId,
                mode: resolution.mode,
                granularity: capturedGranularity,
                from: capturedFrom,
                to: capturedTo,
                valuationCcy: capturedValuation
            )
            let payload = try await api.fetchPnlSeries(
                walletPublicId: walletId,
                mode: resolution.mode,
                granularity: capturedGranularity,
                from: capturedFrom,
                to: capturedTo,
                valuationCcy: capturedValuation
            )
            guard generationAtEntry == generation else { return }
            if Task.isCancelled {
                isLoading = false
                return
            }
            data = payload
            loadedKey = key
            loadError = nil
            errorKey = nil
            isLoading = false
        } catch {
            guard generationAtEntry == generation else { return }
            if Self.isCancellation(error) || Task.isCancelled {
                isLoading = false
                return
            }
            let apiError = (error as? APIError) ?? .invalidResponse
            logger.error("Failed to fetch P&L series: \(apiError.localizedDescription, privacy: .public)")
            loadError = apiError
            errorKey = attemptKey
            isLoading = false
        }
    }

    /// Resolve the request ``mode`` from the selected wallet's
    /// ``is_paper`` flag. When the wallet is absent from the local cache
    /// the wallet list is fetched and RETURNED for the caller to commit
    /// (only after re-checking the generation) — this method never
    /// mutates ``AppState`` itself, so an obsolete resolution can never
    /// overwrite a newer wallet cache. ``walletsToCommit`` is ``nil``
    /// when the mode came from the existing cache. A wallet that still
    /// cannot be resolved throws rather than guessing a mode.
    private func resolveMode(
        walletId: String
    ) async throws -> (mode: String, walletsToCommit: [WalletInfo]?) {
        if let wallet = appState.availableWallets.first(where: { $0.publicId == walletId }) {
            return (Self.modeString(isPaper: wallet.isPaper), nil)
        }
        let wallets = try await api.fetchWallets()
        guard let wallet = wallets.first(where: { $0.publicId == walletId }) else {
            throw APIError.invalidResponse
        }
        return (Self.modeString(isPaper: wallet.isPaper), wallets)
    }

    /// ``true`` for a task cancellation (either a raw ``CancellationError``
    /// or a ``URLError`` whose code is ``.cancelled``), which must be
    /// swallowed rather than mapped to a load error.
    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    var points: [PnlTimelinePointData] { freshData?.points ?? [] }
    var incompleteCount: Int { Self.incompleteCount(points: points) }
    var latestPoint: PnlTimelinePointData? { Self.latestPoint(freshData) }
    var incompletenessGroups: [PnlIncompletenessGroup] { Self.groupedIncompleteness(points: points) }

    /// ``"paper"`` for a paper wallet, ``"live"`` otherwise — the exact
    /// mapping the backend enforces against the wallet's ``is_paper``.
    static func modeString(isPaper: Bool) -> String {
        return isPaper ? "paper" : "live"
    }

    /// Auto-coarsen the granularity for a newly selected window: never
    /// finer than the window's floor (``h24`` → any, ``d7`` → ≥ 5m,
    /// ``d30`` / ``d90`` → ≥ 1h) and never finer than the current
    /// selection. A user may still manually pick a finer granularity;
    /// the resulting work-budget rejection then surfaces as the error
    /// state.
    static func defaultGranularity(
        for window: PnlTimelineWindow,
        current: PnlTimelineGranularity
    ) -> PnlTimelineGranularity {
        let floor: PnlTimelineGranularity
        switch window {
        case .h24: floor = .m1
        case .d7: floor = .m5
        case .d30, .d90: floor = .h1
        }
        return current.coarsenessRank >= floor.coarsenessRank ? current : floor
    }

    /// Surface the full-screen error only when a load has settled with
    /// an error and there is nothing cached to show.
    static func shouldShowLoadError(
        hasData: Bool,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard loadError != nil else { return false }
        return !hasData
    }

    /// The latest (last) point of the series — the tables always
    /// reflect this single point, never an aggregate.
    static func latestPoint(_ data: PnlSeriesData?) -> PnlTimelinePointData? {
        return data?.points.last
    }

    /// Count of points whose valuation was withheld as incomplete.
    static func incompleteCount(points: [PnlTimelinePointData]) -> Int {
        return points.filter { $0.valuationStatus == .incomplete }.count
    }

    /// Client-computed net contribution for one instrument: the sum of
    /// realized + fee + accrual + unrealized ONLY when all four are
    /// present. Any withheld component yields ``nil`` (never a
    /// fabricated zero).
    static func contributionNet(_ contribution: PnlInstrumentContributionData) -> Double? {
        guard
            let realized = contribution.realizedPnl,
            let fee = contribution.feePnl,
            let accrual = contribution.accrualPnl,
            let unrealized = contribution.unrealizedPnl
        else {
            return nil
        }
        return realized + fee + accrual + unrealized
    }

    /// Display identity for an instrument contribution: ``SYM ·
    /// EXCHANGE`` when both are proven, the bare symbol when the
    /// exchange is withheld, and the raw public id when the symbol
    /// itself is unproven (web ``formatPnlInstrumentIdentity``).
    static func instrumentIdentity(_ contribution: PnlInstrumentContributionData) -> String {
        guard let symbol = contribution.nativeSymbol else {
            return contribution.instrumentPublicId
        }
        guard let exchange = contribution.exchange else {
            return symbol
        }
        return "\(symbol) · \(exchange)"
    }

    /// Group the withholding reasons across every loaded point.
    /// Per-point duplicate ``(scope, trigger, tier, reason)`` tuples are
    /// deduped first; groups are then accumulated across points, count
    /// the points they affect, and adopt the first proven trigger
    /// contribution. Sorted global-scope-first, then trigger id, then
    /// ``mark_incomplete``-before-``untrusted`` tier, then reason. Ported
    /// verbatim from the web ``IncompletenessSummary``.
    static func groupedIncompleteness(points: [PnlTimelinePointData]) -> [PnlIncompletenessGroup] {
        var groups: [PnlIncompletenessGroup] = []
        for point in points {
            for reason in uniqueReasons(point.incompletenessReasons) {
                let trigger = findTriggerContribution(point: point, reason: reason)
                if let index = groups.firstIndex(where: { sameReasonIdentity($0.reason, reason) }) {
                    groups[index].affectedPointCount += 1
                    if groups[index].triggerContribution == nil, let trigger {
                        groups[index].triggerContribution = trigger
                    }
                } else {
                    groups.append(
                        PnlIncompletenessGroup(
                            reason: reason,
                            affectedPointCount: 1,
                            triggerContribution: trigger
                        )
                    )
                }
            }
        }
        return groups.sorted { reasonSortKey($0.reason) < reasonSortKey($1.reason) }
    }

    /// Two reasons share identity when scope, trigger instrument,
    /// tier, and reason all match.
    static func sameReasonIdentity(
        _ left: PnlIncompletenessReasonData,
        _ right: PnlIncompletenessReasonData
    ) -> Bool {
        return left.withholdingScope == right.withholdingScope
            && left.triggerInstrumentPublicId == right.triggerInstrumentPublicId
            && left.withholdingTier == right.withholdingTier
            && left.reason == right.reason
    }

    private static func uniqueReasons(
        _ reasons: [PnlIncompletenessReasonData]
    ) -> [PnlIncompletenessReasonData] {
        var unique: [PnlIncompletenessReasonData] = []
        for reason in reasons where !unique.contains(where: { sameReasonIdentity($0, reason) }) {
            unique.append(reason)
        }
        return unique
    }

    private static func findTriggerContribution(
        point: PnlTimelinePointData,
        reason: PnlIncompletenessReasonData
    ) -> PnlInstrumentContributionData? {
        guard let triggerId = reason.triggerInstrumentPublicId else { return nil }
        return point.perInstrument.first(where: { $0.instrumentPublicId == triggerId })
    }

    private static func reasonSortKey(_ reason: PnlIncompletenessReasonData) -> String {
        let scope = reason.withholdingScope == .global ? "0" : "1"
        let tier = reason.withholdingTier == .markIncomplete ? "0" : "1"
        return [
            scope,
            reason.triggerInstrumentPublicId ?? "",
            tier,
            reason.reason.rawValue,
        ].joined(separator: "\u{0}")
    }
}
