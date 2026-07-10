import Foundation
import Observation
import os

/// Severity bucket for the server's overall health ``status`` string.
/// The backend emits exactly ``healthy`` / ``warning`` / ``error``
/// (``HealthStatusEnum``); ``unknown`` is a defensive fallback so a
/// future / malformed value renders neutrally instead of being forced
/// into one of the known states.
enum HealthSeverity {
    case healthy
    case warning
    case error
    case unknown

    /// Catalog key for the status label. Plain ``String`` so the
    /// mapping is asserted directly in unit tests.
    var localizationKey: String {
        switch self {
        case .healthy: return "health.status.healthy"
        case .warning: return "health.status.warning"
        case .error: return "health.status.error"
        case .unknown: return "health.status.unknown"
        }
    }
}

/// ViewModel for ``HealthView`` — the read-only server-health snapshot
/// (connection stats + provenance gap-detection) sourced from the
/// already-wired ``APIClientProtocol/fetchHealth`` (`GET /api/health`).
///
/// Mirrors ``SignalsViewModel``'s shape (typed error handling, pure
/// ``static`` decision helpers) but is not wallet-scoped — health is a
/// system-wide snapshot, so there is no filter and no ``AppState``
/// dependency. Pull-to-refresh only; ``/health`` has no live-push
/// channel.
@MainActor
@Observable
final class HealthViewModel {

    var health: HealthCheckData?
    var isLoading: Bool = false
    var loadError: APIError?

    private let api: APIClientProtocol

    private let logger = AppLogger.make(category: "HealthViewModel")

    init(api: APIClientProtocol = APIClient.shared) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            health = try await api.fetchHealth().payload
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch health: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch health: \(error.localizedDescription, privacy: .public)")
            loadError = .invalidResponse
        }
    }

    /// Error-state branch: surface the "couldn't load" variant only
    /// when there is no cached snapshot to show and a load has settled.
    static func shouldShowLoadError(
        hasData: Bool,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard loadError != nil else { return false }
        return !hasData
    }

    /// Map the wire ``status`` string to a display severity. Lowered
    /// defensively so a differently-cased value still classifies.
    static func severity(for status: String) -> HealthSeverity {
        switch status.lowercased() {
        case "healthy": return .healthy
        case "warning": return .warning
        case "error": return .error
        default: return .unknown
        }
    }
}
