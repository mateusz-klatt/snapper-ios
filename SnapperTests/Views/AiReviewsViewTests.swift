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
}
