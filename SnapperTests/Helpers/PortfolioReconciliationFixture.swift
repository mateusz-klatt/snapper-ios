import Foundation
@testable import Snapper

/// Test fixture for ``PortfolioReconciliationView``. Default values model a
/// clean, matched, authoritative reconciliation on the happy path; named
/// arguments override the two fields that callers are most likely to vary.
///
/// The reconciliation view became a required field on ``PortfolioAccountState``.
/// The account-truth and accounts-view-model tests do not assert on
/// reconciliation, so the default simply satisfies the schema requirement while
/// keeping those call sites focused on the fields they actually exercise.
extension PortfolioReconciliationView {
    static func fixture(
        effectiveStatus: PortfolioReconciliationEffectiveStatus = .matched,
        isAuthoritative: Bool = true
    ) -> PortfolioReconciliationView {
        return PortfolioReconciliationView(
            method: nil,
            evaluationStatus: nil,
            effectiveStatus: effectiveStatus,
            isAuthoritative: isAuthoritative,
            evaluatedAt: nil,
            currentObservationId: nil,
            lastFullObservationId: nil,
            detailSourceObservationId: nil,
            lastFullOutcome: nil,
            consecutiveFullMismatches: 0,
            anchorPublicId: nil,
            venueAccountStatePublicId: nil,
            venueAccountObservationId: nil,
            sourceWatermarkKind: nil,
            sourceWatermark: nil,
            expected: nil,
            actual: nil,
            difference: nil,
            tolerance: nil,
            reconciledAt: nil,
            authoritativeUntil: nil,
            error: nil,
            openDriftEpisode: nil
        )
    }
}
