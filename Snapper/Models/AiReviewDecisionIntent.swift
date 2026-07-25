import Foundation

/// A verdict a delegate can record on a CONSULT review.
///
/// Modeled as a closed enum rather than a raw ``String`` and threaded all
/// the way down to ``APIClientProtocol`` so the backend's
/// ``invalid_decision`` (422) outcome is unrepresentable: there is no
/// call site that can put an unrecognised value on the wire. The raw
/// values ARE the wire values validated server-side against
/// ``AiReviewDecisionEnum``.
///
/// Lives in the model layer rather than beside the ViewModel because
/// both the network surface and the UI depend on it.
enum AiReviewDecisionIntent: String, CaseIterable, Sendable {
    case approve
    case reject

    /// Wire value for ``AiReviewDecisionRequest/decision``.
    var wireValue: String { return rawValue }
}

/// Wire-contract bounds for the rationale attached to a decision.
///
/// Nonisolated on purpose: this is a fact about the backend schema, not
/// about any screen, so the network layer and its tests can consult it
/// without hopping to the main actor.
enum AiReviewRationale {

    /// Longest rationale the backend will store — the
    /// ``ai_reviews.rationale`` column constraint, also declared on
    /// ``AiReviewDecisionRequest``.
    static let characterLimit = 4096

    /// Whether an already-normalized rationale exceeds that limit.
    ///
    /// Callers refuse an over-long rationale CLIENT-SIDE: the backend
    /// answers it with a plain FastAPI validation 422, a different shape
    /// from the decision route's own ``error_code`` envelope, which the
    /// outcome table cannot classify — it would degrade to a generic
    /// failure and leave the row unreconciled in the inbox. The rationale
    /// is audit text attached to a trade veto, so it is refused rather
    /// than silently truncated; the author decides what to cut.
    ///
    /// Counted in UNICODE SCALARS to match Python's ``len()``
    /// server-side. Swift's ``String.count`` counts grapheme clusters and
    /// would under-count text with combining marks or emoji, letting a
    /// payload the backend rejects slip past this guard.
    static func exceedsLimit(_ rationale: String?) -> Bool {
        guard let rationale else { return false }
        return rationale.unicodeScalars.count > characterLimit
    }
}
