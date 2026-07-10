import Foundation
import Observation
import os

/// Verdict of an AI-delegate review. The backend `decision` field is
/// ``"approve"`` / ``"reject"`` / ``null`` (still pending); ``pending``
/// is also the defensive fallback for any unexpected value.
enum AiReviewDecision {
    case approved
    case rejected
    case pending

    /// Catalog key for the decision label — kept as a plain ``String``
    /// so the mapping is asserted directly in unit tests.
    var localizationKey: String {
        switch self {
        case .approved: return "aiReviews.decision.approve"
        case .rejected: return "aiReviews.decision.reject"
        case .pending: return "aiReviews.decision.pending"
        }
    }
}

/// ViewModel for ``AiReviewsView`` — the read-only audit list of
/// AI-delegate decisions from ``APIClientProtocol/fetchAiReviews``
/// (`GET /api/ai-reviews`).
///
/// Mirrors ``BacktestsViewModel``'s list shape and error handling.
/// **Not** client-side wallet-scoped: the backend audit endpoint scopes
/// results server-side, so filtering by the local wallet selection here
/// could wrongly hide rows — no filter and no ``WalletPicker``. Read-only
/// — the delegate approve / reject controls and the live activity
/// WebSocket are out of scope for this first cut. Pull-to-refresh only.
@MainActor
@Observable
final class AiReviewsViewModel {

    var reviews: [AdminAiReviewItem] = []
    var isLoading: Bool = false
    var loadError: APIError?

    private let api: APIClientProtocol

    private let logger = AppLogger.make(category: "AiReviewsViewModel")

    init(api: APIClientProtocol = APIClient.shared) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            reviews = try await api.fetchAiReviews()
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch AI reviews: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch AI reviews: \(error.localizedDescription, privacy: .public)")
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

    /// Map the wire ``decision`` string to a display verdict, lowered
    /// defensively; ``nil`` / unexpected → ``.pending``.
    static func decision(for raw: String?) -> AiReviewDecision {
        switch raw?.lowercased() {
        case "approve": return .approved
        case "reject": return .rejected
        default: return .pending
        }
    }
}
