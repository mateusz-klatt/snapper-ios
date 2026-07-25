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

    /// Badge truth table over the backend contract: every
    /// ``AiReviewStatusEnum`` value crossed with the ``decision`` values
    /// that can legitimately accompany it.
    ///
    /// The regression this pins: `timeout` and `superseded` are TERMINAL
    /// states reached with ``decision == nil`` and a populated
    /// ``resolvedAt``. Deriving the badge from ``decision`` alone
    /// rendered them "Pending" beside a "Decided at" timestamp.
    func testBadgeVerdictTruthTable() {
        let cases: [(decision: String?, status: String, expected: AiReviewDecision, note: String)] = [
            ("approve", "resolved_approved", .approved, "delegate approved"),
            ("reject", "resolved_rejected", .rejected, "delegate rejected"),
            (nil, "timeout", .timedOut, "reaper closed it at the deadline — NOT pending"),
            (nil, "superseded", .superseded, "strategy abandoned the signal — NOT pending"),
            (nil, "pending", .pending, "awaiting a delegate"),
            (nil, "fanout_dispatched", .pending, "broadcast to fanout, still awaiting"),
        ]
        for testCase in cases {
            XCTAssertEqual(
                AiReviewsViewModel.verdict(decision: testCase.decision, status: testCase.status),
                testCase.expected,
                "\(testCase.status)/\(testCase.decision ?? "nil"): \(testCase.note)"
            )
        }
    }

    /// Status is the lifecycle authority, so it wins over a ``decision``
    /// that disagrees with it — a combination the backend should never
    /// emit, but which must not resolve to a cheerful "Approved" on a
    /// timed-out review.
    func testStatusOutranksAContradictoryDecisionField() {
        XCTAssertEqual(
            AiReviewsViewModel.verdict(decision: "approve", status: "timeout"),
            .timedOut
        )
        XCTAssertEqual(
            AiReviewsViewModel.verdict(decision: "reject", status: "superseded"),
            .superseded
        )
    }

    /// An unrecognised (future) status degrades to the decision field
    /// rather than to a wrong label; both inputs are lowered defensively.
    func testUnknownStatusFallsBackToDecisionCaseInsensitively() {
        XCTAssertEqual(
            AiReviewsViewModel.verdict(decision: "APPROVE", status: "some_future_state"),
            .approved
        )
        XCTAssertEqual(
            AiReviewsViewModel.verdict(decision: "Reject", status: "some_future_state"),
            .rejected
        )
        XCTAssertEqual(
            AiReviewsViewModel.verdict(decision: nil, status: "some_future_state"),
            .pending
        )
        XCTAssertEqual(
            AiReviewsViewModel.verdict(decision: "deferred", status: "some_future_state"),
            .pending
        )
        XCTAssertEqual(
            AiReviewsViewModel.verdict(decision: nil, status: "TIMEOUT"),
            .timedOut,
            "status is lowered before matching"
        )
    }

    func testDecisionLocalizationKeys() {
        XCTAssertEqual(AiReviewDecision.approved.localizationKey, "aiReviews.decision.approve")
        XCTAssertEqual(AiReviewDecision.rejected.localizationKey, "aiReviews.decision.reject")
        XCTAssertEqual(AiReviewDecision.pending.localizationKey, "aiReviews.decision.pending")
        XCTAssertEqual(
            AiReviewDecision.timedOut.localizationKey,
            "aiReviews.pending.expired",
            "a timed-out review reuses the inbox expiry label rather than minting a duplicate"
        )
        XCTAssertEqual(
            AiReviewDecision.superseded.localizationKey,
            "aiReviews.decision.superseded"
        )
    }

    /// Every badge label must resolve to real catalog copy — a key typo
    /// would otherwise ship as the raw key string on screen.
    func testEveryBadgeLabelResolvesInTheCatalog() {
        let verdicts: [AiReviewDecision] = [.approved, .rejected, .timedOut, .superseded, .pending]
        for verdict in verdicts {
            let resolved = LocaleStrings.localized(verdict.localizationKey, in: .en)
            XCTAssertFalse(resolved.isEmpty, "\(verdict.localizationKey) is empty")
            XCTAssertNotEqual(
                resolved,
                verdict.localizationKey,
                "\(verdict.localizationKey) is missing from the catalog"
            )
        }
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
