import XCTest
@testable import Snapper

@MainActor
final class AiReviewsViewTests: XCTestCase {

    func testShouldShowLoadErrorWhenEmptyAndLoadFailed() {
        XCTAssertTrue(AiReviewsViewModel.shouldShowLoadError(count: 0, loadError: .httpError(503), isLoading: false))
    }

    func testShouldNotShowLoadErrorWhenListNonEmpty() {
        XCTAssertFalse(AiReviewsViewModel.shouldShowLoadError(count: 3, loadError: .invalidResponse, isLoading: false))
    }

    func testShouldNotShowLoadErrorWhileLoading() {
        XCTAssertFalse(AiReviewsViewModel.shouldShowLoadError(count: 0, loadError: .invalidResponse, isLoading: true))
    }

    func testShouldNotShowLoadErrorWhenNoError() {
        XCTAssertFalse(AiReviewsViewModel.shouldShowLoadError(count: 0, loadError: nil, isLoading: false))
    }

    /// approve/reject map to their verdicts (case-insensitive); nil and
    /// any unexpected value fall to ``.pending``.
    func testDecisionMapping() {
        XCTAssertEqual(AiReviewsViewModel.decision(for: "approve"), .approved)
        XCTAssertEqual(AiReviewsViewModel.decision(for: "APPROVE"), .approved)
        XCTAssertEqual(AiReviewsViewModel.decision(for: "reject"), .rejected)
        XCTAssertEqual(AiReviewsViewModel.decision(for: nil), .pending)
        XCTAssertEqual(AiReviewsViewModel.decision(for: "deferred"), .pending)
    }

    func testDecisionLocalizationKeys() {
        XCTAssertEqual(AiReviewDecision.approved.localizationKey, "aiReviews.decision.approve")
        XCTAssertEqual(AiReviewDecision.rejected.localizationKey, "aiReviews.decision.reject")
        XCTAssertEqual(AiReviewDecision.pending.localizationKey, "aiReviews.decision.pending")
    }

    /// The segmented control reuses each feed's own title key rather than
    /// minting segment-only duplicates.
    func testSegmentTitleKeys() {
        XCTAssertEqual(AiReviewsSegment.allCases.map(\.id), ["pending", "decisions"])
        XCTAssertEqual(AiReviewsSegment.pending.titleKey, "aiReviews.pending.title")
        XCTAssertEqual(AiReviewsSegment.decisions.titleKey, "aiReviews.decisions.title")
    }

    /// Expiry truth table. The boundary is INCLUSIVE: a deadline exactly
    /// equal to now has elapsed, matching the backend's inline timeout,
    /// which would answer 410 for such a row.
    func testExpiredRowPreDisableTruthTable() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertFalse(
            AiReviewsViewModel.isExpired(deadline: now.addingTimeInterval(1), now: now),
            "a deadline one second out is still actionable"
        )
        XCTAssertTrue(
            AiReviewsViewModel.isExpired(deadline: now, now: now),
            "a deadline exactly at now has elapsed"
        )
        XCTAssertTrue(
            AiReviewsViewModel.isExpired(deadline: now.addingTimeInterval(-1), now: now)
        )
        XCTAssertTrue(
            AiReviewsViewModel.isExpired(deadline: now.addingTimeInterval(-86_400), now: now)
        )
        XCTAssertFalse(
            AiReviewsViewModel.isExpired(deadline: now.addingTimeInterval(86_400), now: now)
        )
    }

    /// The Home badge appears only for a non-zero count. Home supplies a
    /// non-zero count only for a delegate session, so the badge is
    /// inherently delegate-only.
    func testEntryCardBadgeVisibility() {
        XCTAssertFalse(AiReviewsEntryCard.showsBadge(pendingCount: 0))
        XCTAssertTrue(AiReviewsEntryCard.showsBadge(pendingCount: 1))
        XCTAssertTrue(AiReviewsEntryCard.showsBadge(pendingCount: 42))
    }

    /// Deadlines render in the IN-APP language, never the process
    /// locale.
    func testFormattedDeadlineUsesExplicitLocale() {
        let deadline = Date(timeIntervalSince1970: 1_767_225_600)
        let english = AiReviewsViewModel.formattedDeadline(deadline, locale: .us)
        let polish = AiReviewsViewModel.formattedDeadline(deadline, locale: .pl)
        XCTAssertFalse(english.isEmpty)
        XCTAssertFalse(polish.isEmpty)
        XCTAssertNotEqual(english, polish, "the explicit locale must change the rendering")
    }

    func testSubmitErrorMessagePrefersServerDetail() {
        XCTAssertEqual(
            AiReviewsViewModel.submitErrorMessage(APIError.serverError("scope grant missing")),
            "scope grant missing"
        )
        XCTAssertEqual(
            AiReviewsViewModel.submitErrorMessage(APIError.httpError(503)),
            "HTTP error: 503"
        )
    }
}
