import Foundation
import Observation
import os

/// Lifecycle bucket for a backtest run's ``status`` string. The backend
/// emits ``pending`` / ``running`` / ``completed`` / ``failed`` /
/// ``cancelled``; ``unknown`` is a defensive fallback so a future value
/// renders neutrally rather than being mislabelled.
enum BacktestStatusTier {
    case pending
    case running
    case completed
    case failed
    case cancelled
    case unknown

    /// Catalog key for the status label. Plain ``String`` so the mapping
    /// is asserted directly in unit tests.
    var localizationKey: String {
        switch self {
        case .pending: return "backtests.status.pending"
        case .running: return "backtests.status.running"
        case .completed: return "backtests.status.completed"
        case .failed: return "backtests.status.failed"
        case .cancelled: return "backtests.status.cancelled"
        case .unknown: return "backtests.status.unknown"
        }
    }
}

/// ViewModel for ``BacktestsView`` — the read-only list of backtest
/// runs from ``APIClientProtocol/fetchBacktests`` (`GET /api/backtests`).
///
/// Mirrors ``SignalsViewModel``'s error/loading shape but is **not**
/// client-side wallet-scoped: unlike `/api/signals` (which returns every
/// accessible wallet), the backend backtests endpoint already scopes the
/// result to the session's active wallet server-side and takes no wallet
/// parameter. Filtering by the local ``AppState/selectedWalletPublicId``
/// here would wrongly hide every row whenever the local pick differs from
/// the token's active wallet, so no filter (and no ``WalletPicker``) is
/// applied. Read-only — create / cancel / rerun, the detail / compare
/// views, and the live-progress WebSocket are out of scope. Pull-to-
/// refresh only.
@MainActor
@Observable
final class BacktestsViewModel {

    var backtests: [BacktestRunData] = []
    var isLoading: Bool = false
    var loadError: APIError?

    private let api: APIClientProtocol

    private let logger = AppLogger.make(category: "BacktestsViewModel")

    init(api: APIClientProtocol = APIClient.shared) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            backtests = try await api.fetchBacktests()
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch backtests: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch backtests: \(error.localizedDescription, privacy: .public)")
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

    /// Map the wire ``status`` string to a display tier, lowered
    /// defensively so a differently-cased value still classifies.
    static func statusTier(_ status: String) -> BacktestStatusTier {
        switch status.lowercased() {
        case "pending": return .pending
        case "running": return .running
        case "completed": return .completed
        case "failed": return .failed
        case "cancelled": return .cancelled
        default: return .unknown
        }
    }
}
