import XCTest
@testable import Snapper

private struct AiReviewsUnexpectedError: Error {}

@MainActor
final class AiReviewsViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
        appState = AppState(
            userDefaults: UserDefaults(suiteName: "AiReviewsViewModelTests-\(UUID().uuidString)")!,
            preferredLanguagesProvider: { ["en-US"] }
        )
    }

    override func tearDown() {
        mockAPI = nil
        appState = nil
        super.tearDown()
    }

    /// Non-delegate session (the pre-inbox behavior): audit list only.
    private func makeViewModel() -> AiReviewsViewModel {
        return AiReviewsViewModel(
            api: mockAPI,
            appState: appState,
            delegatePublicId: { nil },
            canReadSignals: { false },
            canSubmitDecision: { false }
        )
    }

    /// Delegate session with the inbox open.
    private func makeDelegateViewModel(
        delegatePublicId: String? = "delegate-1",
        canReadSignals: Bool = true,
        canSubmitDecision: Bool = true
    ) -> AiReviewsViewModel {
        return AiReviewsViewModel(
            api: mockAPI,
            appState: appState,
            delegatePublicId: { delegatePublicId },
            canReadSignals: { canReadSignals },
            canSubmitDecision: { canSubmitDecision }
        )
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeReview(
        reviewPublicId: String,
        decision: String? = "approve",
        status: String = "resolved_approved"
    ) -> AdminAiReviewItem {
        return AdminAiReviewItem(
            reviewPublicId: reviewPublicId,
            strategyPublicId: "strategy-1",
            userPublicId: "user-1",
            operatorPublicId: "operator-1",
            walletPublicId: "wallet-1",
            instrumentPublicId: "instrument-1",
            selectedDelegatePublicId: "delegate-1",
            respondingDelegatePublicId: nil,
            status: status,
            decision: decision,
            rationale: "momentum confirmed",
            resolutionMode: nil,
            dispatchVersion: 1,
            createdAt: Self.baseTimestamp,
            resolvedAt: Self.baseTimestamp,
            deadline: Self.baseTimestamp
        )
    }

    private func makePending(
        reviewPublicId: String,
        instrument: String? = "BTC/USD",
        status: String = "pending"
    ) -> PendingReviewSummaryItem {
        return PendingReviewSummaryItem(
            reviewPublicId: reviewPublicId,
            selectedDelegatePublicId: "delegate-1",
            walletPublicId: "wallet-1",
            dispatchVersion: 1,
            status: status,
            deadline: Self.baseTimestamp.addingTimeInterval(3600),
            fanoutAfter: Self.baseTimestamp,
            instrument: instrument,
            signalEnvelope: nil
        )
    }

    private func makeDecisionResponse(
        success: Bool,
        errorCode: String? = nil,
        message: String = "decision recorded"
    ) -> AiReviewDecisionResponse {
        return AiReviewDecisionResponse(
            success: success,
            errorCode: errorCode,
            message: message,
            details: JsonObject()
        )
    }

    /// Prime a delegate VM with one audit row and one pending row, then
    /// install counting handlers so a post-mutation reload is observable
    /// without the feeds changing underneath.
    @discardableResult
    private func primeDelegate(
        viewModel: AiReviewsViewModel,
        pendingIds: [String] = ["r-1"]
    ) async -> AiReviewsReloadCounter {
        let reviews = [makeReview(reviewPublicId: "audit-1")]
        let pending = pendingIds.map { makePending(reviewPublicId: $0) }
        mockAPI.fetchAiReviewsHandler = { reviews }
        mockAPI.fetchPendingAiReviewsHandler = {
            PendingReviewListResponse(items: pending, count: pending.count)
        }
        await viewModel.load()
        let counter = AiReviewsReloadCounter()
        mockAPI.fetchPendingAiReviewsHandler = {
            await counter.increment()
            return PendingReviewListResponse(items: pending, count: pending.count)
        }
        return counter
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.reviews.isEmpty)
        XCTAssertTrue(viewModel.pending.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
        XCTAssertNil(viewModel.pendingLoadError)
        XCTAssertNil(viewModel.submitError)
        XCTAssertFalse(viewModel.showsPendingInbox)
        XCTAssertFalse(viewModel.canSubmitDecisions)
    }

    func testLoadHappyPathPopulatesReviews() async {
        let viewModel = makeViewModel()
        let review = makeReview(reviewPublicId: "r-1")
        mockAPI.fetchAiReviewsHandler = { [review] }
        await viewModel.load()
        XCTAssertEqual(viewModel.reviews.count, 1)
        XCTAssertEqual(viewModel.reviews.first?.decision, "approve")
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadFailureSetsTypedLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchAiReviewsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertTrue(viewModel.reviews.isEmpty)
        guard case .httpError(let code) = viewModel.loadError else {
            return XCTFail("Expected httpError, got \(String(describing: viewModel.loadError))")
        }
        XCTAssertEqual(code, 503)
    }

    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        let viewModel = makeViewModel()
        mockAPI.fetchAiReviewsHandler = { throw AiReviewsUnexpectedError() }
        await viewModel.load()
        guard case .invalidResponse = viewModel.loadError else {
            return XCTFail("Expected invalidResponse fallback, got \(String(describing: viewModel.loadError))")
        }
    }

    func testLoadClearsPreviousError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchAiReviewsHandler = { throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.loadError)

        let review = makeReview(reviewPublicId: "r-1")
        mockAPI.fetchAiReviewsHandler = { [review] }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.reviews.count, 1)
    }

    func testLoadFailurePreservesCachedData() async {
        let viewModel = makeViewModel()
        let review = makeReview(reviewPublicId: "r-1")
        mockAPI.fetchAiReviewsHandler = { [review] }
        await viewModel.load()
        XCTAssertEqual(viewModel.reviews.count, 1)

        mockAPI.fetchAiReviewsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertEqual(viewModel.reviews.count, 1, "Cached list must survive a failed refresh")
        XCTAssertNotNil(viewModel.loadError)
    }

    /// A non-delegate session must never touch the delegate-keyed
    /// endpoint — it would 422 server-side.
    func testNonDelegateSessionNeverFetchesPendingInbox() async {
        let viewModel = makeViewModel()
        let counter = AiReviewsReloadCounter()
        mockAPI.fetchAiReviewsHandler = { [] }
        mockAPI.fetchPendingAiReviewsHandler = {
            await counter.increment()
            return PendingReviewListResponse(items: [], count: 0)
        }

        await viewModel.load()

        let calls = await counter.value
        XCTAssertEqual(calls, 0)
        XCTAssertTrue(viewModel.pending.isEmpty)
        XCTAssertNil(viewModel.pendingLoadError)
    }

    func testDelegateSessionLoadsBothFeeds() async {
        let viewModel = makeDelegateViewModel()
        let reviews = [makeReview(reviewPublicId: "audit-1")]
        let pending = [makePending(reviewPublicId: "r-1"), makePending(reviewPublicId: "r-2")]
        mockAPI.fetchAiReviewsHandler = { reviews }
        mockAPI.fetchPendingAiReviewsHandler = {
            PendingReviewListResponse(items: pending, count: pending.count)
        }

        await viewModel.load()

        XCTAssertTrue(viewModel.showsPendingInbox)
        XCTAssertEqual(viewModel.reviews.count, 1)
        XCTAssertEqual(viewModel.pending.map(\.reviewPublicId), ["r-1", "r-2"])
        XCTAssertNil(viewModel.loadError)
        XCTAssertNil(viewModel.pendingLoadError)
    }

    /// A pure `aiDelegate` holds no `read:ai_reviews`, so its audit fetch
    /// fails while the inbox loads fine. The two feeds must commit
    /// independently.
    func testPendingSurvivesAuditFetchFailure() async {
        let viewModel = makeDelegateViewModel()
        let pending = [makePending(reviewPublicId: "r-1")]
        mockAPI.fetchAiReviewsHandler = { throw APIError.serverError("insufficient permissions") }
        mockAPI.fetchPendingAiReviewsHandler = {
            PendingReviewListResponse(items: pending, count: pending.count)
        }

        await viewModel.load()

        XCTAssertEqual(viewModel.pending.count, 1)
        XCTAssertNil(viewModel.pendingLoadError)
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertTrue(viewModel.reviews.isEmpty)
    }

    func testPendingLoadErrorIsTypedAndKeepsCachedRows() async {
        let viewModel = makeDelegateViewModel()
        await primeDelegate(viewModel: viewModel)
        XCTAssertEqual(viewModel.pending.count, 1)

        mockAPI.fetchPendingAiReviewsHandler = { throw APIError.httpError(503) }
        await viewModel.load()

        guard case .httpError(let code) = viewModel.pendingLoadError else {
            return XCTFail("Expected httpError, got \(String(describing: viewModel.pendingLoadError))")
        }
        XCTAssertEqual(code, 503)
        XCTAssertEqual(viewModel.pending.count, 1, "a transient failure must not blank the inbox")
    }

    /// The 422 `not_a_delegate` shape is unreachable behind the gate but
    /// must degrade to a surfaced typed error, never a crash.
    func testPendingNotADelegateResponseIsSurfacedAsTypedError() async {
        let viewModel = makeDelegateViewModel()
        mockAPI.fetchAiReviewsHandler = { [] }
        mockAPI.fetchPendingAiReviewsHandler = {
            throw APIError.serverError("ai-reviews endpoints require an AI_DELEGATE principal")
        }

        await viewModel.load()

        XCTAssertEqual(
            viewModel.pendingLoadError?.localizedDescription,
            "ai-reviews endpoints require an AI_DELEGATE principal"
        )
        XCTAssertTrue(viewModel.pending.isEmpty)
    }

    func testPendingNonAPIErrorFallsBackToInvalidResponse() async {
        let viewModel = makeDelegateViewModel()
        mockAPI.fetchAiReviewsHandler = { [] }
        mockAPI.fetchPendingAiReviewsHandler = { throw AiReviewsUnexpectedError() }

        await viewModel.load()

        guard case .invalidResponse = viewModel.pendingLoadError else {
            return XCTFail("Expected invalidResponse, got \(String(describing: viewModel.pendingLoadError))")
        }
    }

    /// Losing delegate mode clears the inbox rather than leaving stale
    /// rows the session can no longer act on.
    func testLosingDelegateModeClearsPendingOnNextLoad() async {
        let identity = MutableIdentity("delegate-1")
        let viewModel = AiReviewsViewModel(
            api: mockAPI,
            appState: appState,
            delegatePublicId: { identity.value },
            canReadSignals: { true },
            canSubmitDecision: { true }
        )
        let pending = [makePending(reviewPublicId: "r-1")]
        mockAPI.fetchAiReviewsHandler = { [] }
        mockAPI.fetchPendingAiReviewsHandler = {
            PendingReviewListResponse(items: pending, count: pending.count)
        }
        await viewModel.load()
        XCTAssertEqual(viewModel.pending.count, 1)

        identity.value = nil
        await viewModel.load()

        XCTAssertTrue(viewModel.pending.isEmpty)
        XCTAssertFalse(viewModel.showsPendingInbox)
    }

    func testDecisionSuccessDropsRowAndReloads() async {
        let viewModel = makeDelegateViewModel()
        let counter = await primeDelegate(viewModel: viewModel, pendingIds: ["r-1", "r-2"])
        let response = makeDecisionResponse(success: true)
        let recorder = AiReviewDecisionRecorder()
        mockAPI.submitAiReviewDecisionHandler = { reviewPublicId, decision, rationale in
            await recorder.record(reviewPublicId: reviewPublicId, decision: decision, rationale: rationale)
            return response
        }

        let accepted = await viewModel.submitDecision(
            reviewPublicId: "r-1",
            decision: .approve,
            rationale: "  looks right  "
        )

        XCTAssertTrue(accepted)
        XCTAssertNil(viewModel.submitError)
        let calls = await recorder.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.decision, "approve")
        XCTAssertEqual(calls.first?.rationale, "looks right", "the rationale is trimmed before it is sent")
        let reloads = await counter.value
        XCTAssertEqual(reloads, 1, "an accepted decision reloads exactly once through the coordinator")
        XCTAssertFalse(viewModel.isInFlight("r-1"))
    }

    /// The idempotent retry is a SUCCESS: the review is resolved, so the
    /// row leaves the inbox exactly as it would on the first decision.
    func testDecisionAlreadyRecordedIsTreatedAsSuccess() async {
        let viewModel = makeDelegateViewModel()
        let counter = await primeDelegate(viewModel: viewModel)
        let response = makeDecisionResponse(
            success: true,
            errorCode: "decision_already_recorded",
            message: "decision already recorded"
        )
        mockAPI.submitAiReviewDecisionHandler = { _, _, _ in response }

        let accepted = await viewModel.submitDecision(
            reviewPublicId: "r-1",
            decision: .approve,
            rationale: nil
        )

        XCTAssertTrue(accepted)
        XCTAssertNil(viewModel.submitError)
        let reloads = await counter.value
        XCTAssertEqual(reloads, 1)
    }

    /// Defensive: a future backend that reports the idempotent retry with
    /// `success == false` must still resolve the row.
    func testDecisionAlreadyRecordedWithoutSuccessFlagStillAccepted() {
        let response = AiReviewDecisionResponse(
            success: false,
            errorCode: "decision_already_recorded",
            message: "decision already recorded",
            details: JsonObject()
        )
        XCTAssertEqual(AiReviewsViewModel.outcome(for: response), .accepted)
    }

    func testStaleDecisionOutcomesSurfaceSpecificMessagesAndReload() async {
        let cases: [(code: String, message: String)] = [
            ("review_already_resolved_by_peer", "Another delegate already resolved this review."),
            ("review_id_expired", "This review passed its deadline and timed out."),
            ("review_not_found", "This review no longer exists."),
        ]

        for testCase in cases {
            let viewModel = makeDelegateViewModel()
            let counter = await primeDelegate(viewModel: viewModel)
            let response = makeDecisionResponse(
                success: false,
                errorCode: testCase.code,
                message: "backend copy that must not be shown verbatim"
            )
            mockAPI.submitAiReviewDecisionHandler = { _, _, _ in response }

            let accepted = await viewModel.submitDecision(
                reviewPublicId: "r-1",
                decision: .reject,
                rationale: nil
            )

            XCTAssertFalse(accepted, "\(testCase.code) is not a success")
            XCTAssertEqual(viewModel.submitError, testCase.message, "\(testCase.code) message")
            let reloads = await counter.value
            XCTAssertEqual(reloads, 1, "\(testCase.code) reconciles the stale snapshot")
        }
    }

    /// 403 is the one outcome only the backend can explain (not a
    /// delegate for THIS review, or no scope grant on the wallet +
    /// instrument), so its message is surfaced verbatim.
    func testNotAuthorizedSurfacesBackendMessageVerbatimWithoutReload() async {
        let viewModel = makeDelegateViewModel()
        let counter = await primeDelegate(viewModel: viewModel)
        let response = makeDecisionResponse(
            success: false,
            errorCode: "not_authorized",
            message: "no scope grant covers wallet-1 / instrument-1"
        )
        mockAPI.submitAiReviewDecisionHandler = { _, _, _ in response }

        let accepted = await viewModel.submitDecision(
            reviewPublicId: "r-1",
            decision: .approve,
            rationale: nil
        )

        XCTAssertFalse(accepted)
        XCTAssertEqual(viewModel.submitError, "no scope grant covers wallet-1 / instrument-1")
        let reloads = await counter.value
        XCTAssertEqual(reloads, 0, "an authorization failure changed nothing to reconcile")
    }

    /// The backend's defensive 503 race default, and any code the client
    /// does not know, degrade to the generic template — never a raw code.
    func testUnknownErrorCodeUsesGenericTemplateAndNeverRetries() async {
        let viewModel = makeDelegateViewModel()
        let counter = await primeDelegate(viewModel: viewModel)
        let response = makeDecisionResponse(
            success: false,
            errorCode: "review_state_race",
            message: "transient race"
        )
        let recorder = AiReviewDecisionRecorder()
        mockAPI.submitAiReviewDecisionHandler = { reviewPublicId, decision, rationale in
            await recorder.record(reviewPublicId: reviewPublicId, decision: decision, rationale: rationale)
            return response
        }

        let accepted = await viewModel.submitDecision(
            reviewPublicId: "r-1",
            decision: .approve,
            rationale: nil
        )

        XCTAssertFalse(accepted)
        XCTAssertEqual(viewModel.submitError, "Submit failed: transient race")
        let calls = await recorder.calls
        XCTAssertEqual(calls.count, 1, "a race outcome is NEVER auto-retried")
        let reloads = await counter.value
        XCTAssertEqual(reloads, 0)
    }

    func testThrownSubmitErrorSurfacesServerDetailAndKeepsRow() async {
        let viewModel = makeDelegateViewModel()
        await primeDelegate(viewModel: viewModel)
        mockAPI.submitAiReviewDecisionHandler = { _, _, _ in
            throw APIError.serverError("gateway timeout")
        }

        let accepted = await viewModel.submitDecision(
            reviewPublicId: "r-1",
            decision: .approve,
            rationale: nil
        )

        XCTAssertFalse(accepted)
        XCTAssertEqual(viewModel.submitError, "Submit failed: gateway timeout")
        XCTAssertEqual(viewModel.pending.count, 1, "a failed write leaves the row in the inbox")
        XCTAssertFalse(viewModel.isInFlight("r-1"))
    }

    /// Execution-time re-resolution: the delegate identity is re-checked
    /// immediately before the request, so a revoked session cannot fire
    /// a write the server would reject.
    func testDecisionAbortsWhenDelegateIdentityLostBetweenRenderAndTap() async {
        let identity = MutableIdentity("delegate-1")
        let viewModel = AiReviewsViewModel(
            api: mockAPI,
            appState: appState,
            delegatePublicId: { identity.value },
            canReadSignals: { true },
            canSubmitDecision: { true }
        )
        await primeDelegate(viewModel: viewModel)
        let recorder = AiReviewDecisionRecorder()
        mockAPI.submitAiReviewDecisionHandler = { reviewPublicId, decision, rationale in
            await recorder.record(reviewPublicId: reviewPublicId, decision: decision, rationale: rationale)
            return AiReviewDecisionResponse(
                success: true, errorCode: nil, message: "ok", details: JsonObject()
            )
        }

        identity.value = nil
        let accepted = await viewModel.submitDecision(
            reviewPublicId: "r-1",
            decision: .approve,
            rationale: nil
        )

        XCTAssertFalse(accepted)
        XCTAssertEqual(viewModel.submitError, "Your delegate access changed. Reload before deciding.")
        let calls = await recorder.calls
        XCTAssertTrue(calls.isEmpty, "the request is never sent once the identity is gone")
    }

    func testDecisionAbortsWhenSubmitPermissionLostBetweenRenderAndTap() async {
        let canSubmit = MutablePermission(true)
        let viewModel = AiReviewsViewModel(
            api: mockAPI,
            appState: appState,
            delegatePublicId: { "delegate-1" },
            canReadSignals: { true },
            canSubmitDecision: { canSubmit.value }
        )
        await primeDelegate(viewModel: viewModel)
        let recorder = AiReviewDecisionRecorder()
        mockAPI.submitAiReviewDecisionHandler = { reviewPublicId, decision, rationale in
            await recorder.record(reviewPublicId: reviewPublicId, decision: decision, rationale: rationale)
            return AiReviewDecisionResponse(
                success: true, errorCode: nil, message: "ok", details: JsonObject()
            )
        }

        canSubmit.value = false
        let accepted = await viewModel.submitDecision(
            reviewPublicId: "r-1",
            decision: .reject,
            rationale: nil
        )

        XCTAssertFalse(accepted)
        XCTAssertEqual(viewModel.submitError, "Your delegate access changed. Reload before deciding.")
        let calls = await recorder.calls
        XCTAssertTrue(calls.isEmpty)
    }

    /// The in-flight guard is per REVIEW: a double-tap on one row cannot
    /// double-submit.
    func testInFlightGuardPreventsDoubleSubmitOnSameReview() async {
        let viewModel = makeDelegateViewModel()
        await primeDelegate(viewModel: viewModel)
        let gate = DecisionHandshake()
        let recorder = AiReviewDecisionRecorder()
        mockAPI.submitAiReviewDecisionHandler = { reviewPublicId, decision, rationale in
            await recorder.record(reviewPublicId: reviewPublicId, decision: decision, rationale: rationale)
            await gate.markStartedAndWait()
            return AiReviewDecisionResponse(
                success: true, errorCode: nil, message: "ok", details: JsonObject()
            )
        }

        let first = Task { @MainActor in
            await viewModel.submitDecision(reviewPublicId: "r-1", decision: .approve, rationale: nil)
        }
        await gate.awaitStarted()
        XCTAssertTrue(viewModel.isInFlight("r-1"))
        let second = await viewModel.submitDecision(
            reviewPublicId: "r-1",
            decision: .approve,
            rationale: nil
        )
        await gate.release()
        let firstResult = await first.value

        XCTAssertFalse(second, "the second tap is rejected by the per-review guard")
        XCTAssertTrue(firstResult)
        let calls = await recorder.calls
        XCTAssertEqual(calls.count, 1, "the handler ran exactly once")
        XCTAssertFalse(viewModel.isInFlight("r-1"))
    }

    /// ...and it does NOT cross-block a different review.
    func testConcurrentDecisionsOnDifferentReviewsBothProceed() async {
        let viewModel = makeDelegateViewModel()
        await primeDelegate(viewModel: viewModel, pendingIds: ["r-1", "r-2"])
        let recorder = AiReviewDecisionRecorder()
        mockAPI.submitAiReviewDecisionHandler = { reviewPublicId, decision, rationale in
            await recorder.record(reviewPublicId: reviewPublicId, decision: decision, rationale: rationale)
            return AiReviewDecisionResponse(
                success: true, errorCode: nil, message: "ok", details: JsonObject()
            )
        }

        let taskA = Task { @MainActor in
            await viewModel.submitDecision(reviewPublicId: "r-1", decision: .approve, rationale: nil)
        }
        let taskB = Task { @MainActor in
            await viewModel.submitDecision(reviewPublicId: "r-2", decision: .reject, rationale: nil)
        }
        let okA = await taskA.value
        let okB = await taskB.value

        XCTAssertTrue(okA)
        XCTAssertTrue(okB)
        let ids = await Set(recorder.calls.map(\.reviewPublicId))
        XCTAssertEqual(ids, ["r-1", "r-2"])
    }

    /// The serialized coordinator covers BOTH feeds: while one fetch pass
    /// is gated, a newer request coalesces and the newest response is the
    /// one that commits — a stale pass can never win.
    func testConcurrentReloadsCommitLatestNotStaleAcrossBothFeeds() async {
        let viewModel = makeDelegateViewModel()
        let handshake = DecisionHandshake()
        let staleReviews = [makeReview(reviewPublicId: "audit-stale")]
        let stalePending = [makePending(reviewPublicId: "stale")]
        let freshReviews = [makeReview(reviewPublicId: "audit-fresh")]
        let freshPending = [makePending(reviewPublicId: "fresh")]

        mockAPI.fetchAiReviewsHandler = {
            await handshake.markStartedAndWait()
            return staleReviews
        }
        mockAPI.fetchPendingAiReviewsHandler = {
            PendingReviewListResponse(items: stalePending, count: stalePending.count)
        }

        let first = Task { @MainActor in await viewModel.load() }
        await handshake.awaitStarted()
        mockAPI.fetchAiReviewsHandler = { freshReviews }
        mockAPI.fetchPendingAiReviewsHandler = {
            PendingReviewListResponse(items: freshPending, count: freshPending.count)
        }
        let second = Task { @MainActor in await viewModel.load() }
        await handshake.release()
        _ = await first.value
        _ = await second.value

        XCTAssertEqual(viewModel.reviews.first?.reviewPublicId, "audit-fresh")
        XCTAssertEqual(
            viewModel.pending.first?.reviewPublicId,
            "fresh",
            "the pending feed rides the same serialized worker as the audit feed"
        )
    }

    /// A `decision_ack` pulse landing while the user's own write is still
    /// in flight reconciles through the coordinator instead of racing it:
    /// the write's own post-mutation reload still commits last.
    func testDecisionReloadCoexistsWithConcurrentPulseReload() async {
        let viewModel = makeDelegateViewModel()
        await primeDelegate(viewModel: viewModel, pendingIds: ["r-1", "r-2"])
        let gate = DecisionHandshake()
        let remaining = [makePending(reviewPublicId: "r-2")]
        mockAPI.fetchPendingAiReviewsHandler = {
            PendingReviewListResponse(items: remaining, count: remaining.count)
        }
        mockAPI.submitAiReviewDecisionHandler = { _, _, _ in
            await gate.markStartedAndWait()
            return AiReviewDecisionResponse(
                success: true, errorCode: nil, message: "ok", details: JsonObject()
            )
        }

        let submitTask = Task { @MainActor in
            await viewModel.submitDecision(reviewPublicId: "r-1", decision: .approve, rationale: nil)
        }
        await gate.awaitStarted()
        await viewModel.load()
        await gate.release()
        let accepted = await submitTask.value

        XCTAssertTrue(accepted)
        XCTAssertEqual(
            viewModel.pending.map(\.reviewPublicId),
            ["r-2"],
            "the decided row is gone and the concurrent pulse did not resurrect it"
        )
    }

    func testOutcomeMappingCoversTheBackendErrorCodeTable() {
        XCTAssertEqual(
            AiReviewsViewModel.outcome(for: makeDecisionResponse(success: true)),
            .accepted
        )
        XCTAssertEqual(
            AiReviewsViewModel.outcome(
                for: makeDecisionResponse(success: false, errorCode: "review_already_resolved_by_peer")
            ),
            .resolvedByPeer
        )
        XCTAssertEqual(
            AiReviewsViewModel.outcome(
                for: makeDecisionResponse(success: false, errorCode: "review_id_expired")
            ),
            .expired
        )
        XCTAssertEqual(
            AiReviewsViewModel.outcome(
                for: makeDecisionResponse(success: false, errorCode: "review_not_found")
            ),
            .notFound
        )
        XCTAssertEqual(
            AiReviewsViewModel.outcome(
                for: makeDecisionResponse(success: false, errorCode: "not_authorized")
            ),
            .notAuthorized
        )
        XCTAssertEqual(
            AiReviewsViewModel.outcome(
                for: makeDecisionResponse(success: false, errorCode: "review_state_race")
            ),
            .failed
        )
        XCTAssertEqual(
            AiReviewsViewModel.outcome(for: makeDecisionResponse(success: false, errorCode: nil)),
            .failed
        )
    }

    func testNormalizedRationaleDropsBlankInput() {
        XCTAssertNil(AiReviewsViewModel.normalizedRationale(nil))
        XCTAssertNil(AiReviewsViewModel.normalizedRationale(""))
        XCTAssertNil(AiReviewsViewModel.normalizedRationale("   \n  "))
        XCTAssertEqual(AiReviewsViewModel.normalizedRationale("  ok  "), "ok")
    }

    func testDecisionIntentWireValues() {
        XCTAssertEqual(AiReviewDecisionIntent.approve.wireValue, "approve")
        XCTAssertEqual(AiReviewDecisionIntent.reject.wireValue, "reject")
        XCTAssertEqual(AiReviewDecisionIntent.allCases.count, 2)
    }

    private func makeWebSocketManager() -> WebSocketManager {
        return WebSocketManager(
            authService: FakeAuthService(nextToken: "t"),
            taskFactory: FakeWebSocketTaskFactory(task: FakeWebSocketTask()),
            sleeper: FakeSleeper()
        )
    }

    /// An ai_review activity pulse arriving after the startup reconciliation
    /// settles triggers exactly one additional debounced ``load()``.
    func testLiveAiReviewPulseTriggersOneReload() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = AiReviewsReloadCounter()
        mockAPI.fetchAiReviewsHandler = { await counter.increment(); return [] }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 500_000_000)
        let baseline = await counter.value
        manager.state.lastAiReviewActivityAt = Date()
        try await Task.sleep(nanoseconds: 500_000_000)

        let after = await counter.value
        XCTAssertEqual(after, baseline + 1, "one ai_review pulse triggers exactly one reload")
        viewModel.stopObservingLiveUpdates(token: token)
    }

    /// In delegate mode the SAME pulse must also refresh the pending
    /// inbox — a peer's decision_ack removes the row without the user
    /// touching anything.
    func testLiveAiReviewPulseAlsoReloadsPendingInboxInDelegateMode() async throws {
        let viewModel = makeDelegateViewModel()
        let manager = makeWebSocketManager()
        let counter = AiReviewsReloadCounter()
        mockAPI.fetchAiReviewsHandler = { [] }
        mockAPI.fetchPendingAiReviewsHandler = {
            await counter.increment()
            return PendingReviewListResponse(items: [], count: 0)
        }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 500_000_000)
        let baseline = await counter.value
        manager.state.lastAiReviewActivityAt = Date()
        try await Task.sleep(nanoseconds: 500_000_000)

        let after = await counter.value
        XCTAssertEqual(after, baseline + 1)
        viewModel.stopObservingLiveUpdates(token: token)
    }

    /// Stopping observation before the debounce fires leaves no pending
    /// reload.
    func testStopLeavesNoPendingReload() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = AiReviewsReloadCounter()
        mockAPI.fetchAiReviewsHandler = { await counter.increment(); return [] }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 100_000_000)
        manager.state.lastAiReviewActivityAt = Date()
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.stopObservingLiveUpdates(token: token)
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "stop before the debounce window must cancel the pending reload")
    }
}

private actor AiReviewsReloadCounter {
    var value: Int = 0
    func increment() { value += 1 }
}

private actor AiReviewDecisionRecorder {
    struct Call {
        let reviewPublicId: String
        let decision: String
        let rationale: String?
    }

    var calls: [Call] = []

    func record(reviewPublicId: String, decision: String, rationale: String?) {
        calls.append(Call(reviewPublicId: reviewPublicId, decision: decision, rationale: rationale))
    }
}

/// Deterministic interleave gate — no fixed sleeps. The handler signals
/// that it started and blocks until the test releases it.
private actor DecisionHandshake {
    private var started = false
    private var released = false
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func markStartedAndWait() async {
        started = true
        for waiter in startedWaiters { waiter.resume() }
        startedWaiters.removeAll()
        if released { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func awaitStarted() async {
        if started { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }

    func release() {
        released = true
        for waiter in releaseWaiters { waiter.resume() }
        releaseWaiters.removeAll()
    }
}

private final class MutableIdentity: @unchecked Sendable {
    var value: String?

    init(_ value: String?) {
        self.value = value
    }
}

private final class MutablePermission: @unchecked Sendable {
    var value: Bool

    init(_ value: Bool) {
        self.value = value
    }
}
