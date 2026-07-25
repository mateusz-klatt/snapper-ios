import Combine
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

/// The two feeds the AI-reviews screen can show. Only a delegate session
/// sees the segmented control; everyone else gets ``decisions`` alone.
enum AiReviewsSegment: String, CaseIterable, Identifiable, Sendable {
    case pending
    case decisions

    var id: String { return rawValue }

    /// Catalog key for the segment title — drives the Picker's
    /// localized rendering via ``LocalizedStringKey``. Reuses each
    /// feed's own title rather than minting segment-only duplicates, so
    /// the segment and the section header it reveals always agree.
    var titleKey: String {
        switch self {
        case .pending: return "aiReviews.pending.title"
        case .decisions: return "aiReviews.decisions.title"
        }
    }
}

/// A verdict the user can submit. Modeled as a closed enum rather than a
/// raw string so the client can never produce the backend's
/// ``invalid_decision`` (422) outcome.
enum AiReviewDecisionIntent: String, CaseIterable, Sendable {
    case approve
    case reject

    /// Wire value for ``AiReviewDecisionRequest/decision`` — the backend
    /// validates it against ``AiReviewDecisionEnum``.
    var wireValue: String { return rawValue }
}

/// How the backend classified a submitted decision, derived from the
/// canonical ``error_code`` contract of
/// ``POST /api/ai-reviews/{id}/decision``.
///
/// - ``accepted``: the verdict is recorded. Covers BOTH the first valid
///   decision (200, ``error_code == nil``) and the idempotent retry
///   (200, ``success == true``, ``decision_already_recorded``) — the
///   review is resolved either way, so the row leaves the inbox.
/// - ``resolvedByPeer`` (409) / ``expired`` (410) / ``notFound`` (404):
///   the row is stale; the user gets a specific explanation and the feed
///   is reloaded.
/// - ``notAuthorized`` (403): the caller is not a delegate for this
///   review or holds no scope grant on the wallet/instrument. The
///   backend message is the only accurate explanation, so it is
///   surfaced verbatim.
/// - ``failed``: anything else, including the backend's defensive 503
///   race default. Generic message; never retried automatically.
enum AiReviewDecisionOutcome: String, Equatable, Sendable {
    case accepted
    case resolvedByPeer
    case expired
    case notFound
    case notAuthorized
    case failed
}

/// ViewModel for ``AiReviewsView`` — two feeds behind one screen.
///
/// **Decisions** (every session that can open the screen): the read-only
/// audit list from ``APIClientProtocol/fetchAiReviews``
/// (`GET /api/ai-reviews`, gated by `read:ai_reviews`). **Not**
/// client-side wallet-scoped: the backend scopes results server-side, so
/// filtering by the local wallet selection could wrongly hide rows.
///
/// **Pending** (delegate sessions only): the actionable inbox from
/// ``APIClientProtocol/fetchPendingAiReviews``
/// (`GET /api/ai-reviews/pending`, gated by `read:signals`) plus per-row
/// approve / reject writes. That endpoint is keyed SERVER-SIDE on the
/// caller's AI-delegate identity and 422s a non-delegate principal, so
/// the inbox is gated on ``delegatePublicId != nil && read:signals`` —
/// exactly the web inbox's predicate — and no wallet parameter is ever
/// sent.
///
/// Reload coordination: EVERY reload (initial, retry, pull-to-refresh,
/// live-pulse, post-decision) funnels through ``load()``, a single
/// serialized/generation-protected worker covering BOTH feeds. No two
/// fetch bodies ever commit concurrently, so a stale response can never
/// overwrite a fresh one, and the ``decision_ack`` WebSocket pulse that
/// follows the user's own write reconciles instead of racing it. The
/// pending feed is fetched only in delegate mode; the audit feed always,
/// and the two commit independently so one failing does not blank the
/// other.
///
/// Decisions re-resolve the delegate identity AND the submit permission
/// AT EXECUTION TIME (never trusting the render-time snapshot), abort
/// with a surfaced error if either was lost, and are NEVER retried
/// automatically. A per-review ``inFlight`` set disables that row's
/// controls for the duration of its own write — per review, so two
/// different rows can be decided concurrently, and a double-tap on one
/// row cannot double-submit.
@MainActor
@Observable
final class AiReviewsViewModel {

    var reviews: [AdminAiReviewItem] = []
    var pending: [PendingReviewSummaryItem] = []
    var isLoading: Bool = false
    var loadError: APIError?
    var pendingLoadError: APIError?
    var submitError: String?

    private(set) var inFlight: Set<String> = []

    @ObservationIgnored private let liveUpdates = LiveUpdateObserver()

    /// Serialized-reload coordinator state. ``reloadRequestedSeq`` is
    /// bumped on every ``load()``; ``reloadServedSeq`` tracks the newest
    /// request a completed fetch has satisfied; a single worker drains
    /// requests one at a time and resumes each caller once a fetch that
    /// began at or after its request has committed.
    @ObservationIgnored private var reloadRequestedSeq: UInt64 = 0
    @ObservationIgnored private var reloadServedSeq: UInt64 = 0
    @ObservationIgnored private var reloadWorkerRunning = false
    @ObservationIgnored private var reloadWaiters: [(seq: UInt64, continuation: CheckedContinuation<Void, Never>)] = []

    private let api: APIClientProtocol
    private let appState: AppState
    private let delegatePublicId: @MainActor () -> String?
    private let canReadSignals: @MainActor () -> Bool
    private let canSubmitDecision: @MainActor () -> Bool

    private let logger = AppLogger.make(category: "AiReviewsViewModel")

    init(
        api: APIClientProtocol = APIClient.shared,
        appState: AppState = .shared,
        delegatePublicId: @escaping @MainActor () -> String? = { AuthService.shared.currentUser?.delegatePublicId },
        canReadSignals: @escaping @MainActor () -> Bool = { AuthService.shared.hasPermission(.readSignals) },
        canSubmitDecision: @escaping @MainActor () -> Bool = { AuthService.shared.hasPermission(.submitAiReviewDecision) }
    ) {
        self.api = api
        self.appState = appState
        self.delegatePublicId = delegatePublicId
        self.canReadSignals = canReadSignals
        self.canSubmitDecision = canSubmitDecision
    }

    /// Begin observing live ai_review activity pulses plus the reconnect
    /// heal for a debounced REST reload. Returns the session token to hand
    /// back to ``stopObservingLiveUpdates(token:)`` so a stale view-task
    /// teardown cannot stop a newer session.
    ///
    /// The pulse drives the serialized ``load()``, so in delegate mode it
    /// refreshes the PENDING feed as well as the audit list — a
    /// ``decision_ack`` frame from a peer delegate removes the row here
    /// without the user touching anything.
    @discardableResult
    func startObservingLiveUpdates(from webSocketManager: WebSocketManager) -> UInt64 {
        let state = webSocketManager.state
        return liveUpdates.start(
            slots: [LiveUpdateObserver.pulse(state.$lastAiReviewActivityAt)],
            connection: webSocketManager.$connectionState.eraseToAnyPublisher(),
            reload: { [weak self] in await self?.load() }
        )
    }

    /// Cancel observation + any pending debounced reload for `token`. A
    /// stale token (a superseded session) is a no-op.
    func stopObservingLiveUpdates(token: UInt64) {
        liveUpdates.stop(session: token)
    }

    /// Whether this session sees the delegate pending inbox. Resolved
    /// live so a re-login as a different principal is honored.
    var showsPendingInbox: Bool {
        return Self.showsPendingInbox(
            delegatePublicId: delegatePublicId(),
            canReadSignals: canReadSignals()
        )
    }

    /// Whether this session may record verdicts. Resolved live so a role
    /// revoke takes effect without a restart.
    var canSubmitDecisions: Bool {
        return canSubmitDecision()
    }

    /// Pending-inbox visibility predicate, kept pure so the contract test
    /// pins it directly.
    ///
    /// BOTH conditions are load-bearing and mirror the backend:
    /// ``GET /api/ai-reviews/pending`` is gated by ``read:signals`` and
    /// additionally 422s (`not_a_delegate`) whenever the principal
    /// carries no ``delegate_public_id``, because the snapshot is keyed
    /// on the delegate identity rather than on a permission.
    static func showsPendingInbox(delegatePublicId: String?, canReadSignals: Bool) -> Bool {
        guard let delegatePublicId, !delegatePublicId.isEmpty else { return false }
        return canReadSignals
    }

    /// The single serialized reload entry point. Every reload path funnels
    /// through here; the caller awaits until a fetch that began at or after
    /// its request has committed. Concurrent callers coalesce onto one
    /// follow-up fetch that observes the newest generation, so responses are
    /// committed strictly in order (never stale-over-fresh).
    func load() async {
        isLoading = true
        reloadRequestedSeq &+= 1
        let target = reloadRequestedSeq
        startReloadWorkerIfNeeded()
        await withCheckedContinuation { continuation in
            reloadWaiters.append((seq: target, continuation: continuation))
        }
    }

    private func startReloadWorkerIfNeeded() {
        guard !reloadWorkerRunning else { return }
        reloadWorkerRunning = true
        Task { @MainActor in
            await self.drainReloads()
        }
    }

    /// Serial reload worker. Runs one ``performFetch()`` at a time, always
    /// against the newest requested generation, and resumes every waiter a
    /// completed fetch has satisfied. Never overlaps fetches, so no stale
    /// response can overwrite a fresh one.
    private func drainReloads() async {
        defer {
            reloadWorkerRunning = false
            isLoading = false
        }
        while reloadRequestedSeq > reloadServedSeq {
            let target = reloadRequestedSeq
            await performFetch()
            reloadServedSeq = target
            resumeReloadWaiters()
        }
    }

    private func resumeReloadWaiters() {
        let ready = reloadWaiters.filter { $0.seq <= reloadServedSeq }
        reloadWaiters.removeAll { $0.seq <= reloadServedSeq }
        for waiter in ready {
            waiter.continuation.resume()
        }
    }

    /// One fetch pass over both feeds, concurrently. The audit list is
    /// always fetched; the pending inbox only in delegate mode (outside
    /// it the endpoint would 422). The two commit INDEPENDENTLY: a pure
    /// ``aiDelegate`` holds no ``read:ai_reviews``, so its audit fetch
    /// legitimately fails while its inbox loads fine, and the reverse
    /// holds for an operator. Never touches ``inFlight`` — that is
    /// per-review and cleared at each write's own completion.
    private func performFetch() async {
        let delegateMode = showsPendingInbox
        async let auditResult = api.fetchAiReviews()
        async let pendingResult = fetchPendingSnapshot(enabled: delegateMode)

        do {
            reviews = try await auditResult
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch AI reviews: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch AI reviews: \(error.localizedDescription, privacy: .public)")
            loadError = .invalidResponse
        }

        switch await pendingResult {
        case nil:
            pending = []
            pendingLoadError = nil
        case .success(let items):
            pending = items
            pendingLoadError = nil
        case .failure(let error):
            logger.error("Failed to fetch pending AI reviews: \(error.localizedDescription, privacy: .public)")
            pendingLoadError = error
        }
    }

    /// Fetch the delegate inbox, or return ``nil`` when this session is
    /// not in delegate mode. Returns an outcome instead of throwing so
    /// the caller commits the two feeds independently. A failure keeps
    /// the previously committed rows so a transient error does not blank
    /// an inbox the user is working through.
    private func fetchPendingSnapshot(
        enabled: Bool
    ) async -> Result<[PendingReviewSummaryItem], APIError>? {
        guard enabled else { return nil }
        do {
            return .success(try await api.fetchPendingAiReviews().items)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.invalidResponse)
        }
    }

    /// Whether a row's decision controls are disabled by its own
    /// in-flight write.
    func isInFlight(_ reviewPublicId: String) -> Bool {
        return inFlight.contains(reviewPublicId)
    }

    /// Record a verdict for one pending review.
    ///
    /// Rejects a double-submit on the SAME review, re-resolves the
    /// delegate identity and the submit permission at execution time
    /// (aborting with a surfaced error if either was lost between render
    /// and tap), then submits exactly once. The outcome mapping lives in
    /// ``applyDecisionOutcome``; nothing here is ever auto-retried.
    @discardableResult
    func submitDecision(
        reviewPublicId: String,
        decision: AiReviewDecisionIntent,
        rationale: String?
    ) async -> Bool {
        guard !inFlight.contains(reviewPublicId) else { return false }
        guard showsPendingInbox, canSubmitDecision() else {
            submitError = localized("aiReviews.decision.error.notDelegate")
            return false
        }

        inFlight.insert(reviewPublicId)
        defer { inFlight.remove(reviewPublicId) }

        do {
            let response = try await api.submitAiReviewDecision(
                reviewPublicId: reviewPublicId,
                decision: decision.wireValue,
                rationale: Self.normalizedRationale(rationale)
            )
            return await applyDecisionOutcome(reviewPublicId: reviewPublicId, response: response)
        } catch {
            submitError = genericSubmitMessage(detail: Self.submitErrorMessage(error))
            return false
        }
    }

    /// Apply the backend's classification of a submitted decision.
    ///
    /// Accepted → the row is dropped optimistically (so the inbox reacts
    /// instantly) and the serialized reload reconciles against the
    /// server. Stale outcomes explain themselves and reload too, because
    /// the whole snapshot may have moved. An authorization failure and
    /// the defensive race default do NOT reload: nothing about the feed
    /// changed, and a reload would only mask the failure.
    private func applyDecisionOutcome(
        reviewPublicId: String,
        response: AiReviewDecisionResponse
    ) async -> Bool {
        switch Self.outcome(for: response) {
        case .accepted:
            pending.removeAll { $0.reviewPublicId == reviewPublicId }
            await load()
            return true
        case .resolvedByPeer:
            submitError = localized("aiReviews.decision.error.peerResolved")
            await load()
            return false
        case .expired:
            submitError = localized("aiReviews.decision.error.expired")
            await load()
            return false
        case .notFound:
            submitError = localized("aiReviews.decision.error.notFound")
            await load()
            return false
        case .notAuthorized:
            submitError = response.message
            return false
        case .failed:
            submitError = genericSubmitMessage(detail: response.message)
            return false
        }
    }

    /// Classify a decision response. Pure so the error-code contract is
    /// pinned in unit tests against the backend's table.
    ///
    /// ``success`` is authoritative for the accepted case: the backend
    /// sets it for the first valid decision AND for the idempotent
    /// retry, which also carries ``decision_already_recorded``. That code
    /// is matched explicitly as well so a future backend that reports the
    /// retry with ``success == false`` still resolves the row.
    static func outcome(for response: AiReviewDecisionResponse) -> AiReviewDecisionOutcome {
        if response.success { return .accepted }
        switch response.errorCode {
        case "decision_already_recorded": return .accepted
        case "review_already_resolved_by_peer": return .resolvedByPeer
        case "review_id_expired": return .expired
        case "review_not_found": return .notFound
        case "not_authorized": return .notAuthorized
        default: return .failed
        }
    }

    /// Trim an optional rationale to the value actually worth sending:
    /// whitespace-only input becomes ``nil`` so the backend stores no
    /// rationale rather than a blank string.
    static func normalizedRationale(_ rationale: String?) -> String? {
        guard let trimmed = rationale?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// Whether a pending row is already past its deadline and must be
    /// pre-disabled. The backend applies an inline timeout and answers
    /// ``review_id_expired`` (410) for such a row, so offering the
    /// controls would only produce a guaranteed failure.
    ///
    /// Pure and inclusive at the boundary — a deadline exactly equal to
    /// ``now`` has elapsed.
    static func isExpired(deadline: Date, now: Date) -> Bool {
        return deadline <= now
    }

    /// Map a thrown mutation error to the user-facing detail. Backend
    /// ``APIError/serverError`` copy is surfaced verbatim.
    static func submitErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        return error.localizedDescription
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

    /// Locale-aware deadline rendering. The locale is passed explicitly
    /// because the process locale is unrelated to the in-app language
    /// selection.
    static func formattedDeadline(_ deadline: Date, locale: AppLocale) -> String {
        return deadline.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(locale.nativeLocale)
        )
    }

    private func localized(_ key: String) -> String {
        return LocaleStrings.localized(key, in: appState.locale.catalogLanguage)
    }

    /// "Submit failed: <detail>" — the detail is the backend message or
    /// the thrown error, never a code the user cannot act on.
    private func genericSubmitMessage(detail: String) -> String {
        let language = appState.locale.catalogLanguage
        let template = LocaleStrings.localized("aiReviews.decision.error.generic", in: language)
        return String(format: template, locale: Locale(identifier: language.rawValue), detail)
    }
}
