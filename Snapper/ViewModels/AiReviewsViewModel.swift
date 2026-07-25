import Combine
import Foundation
import Observation
import os

/// How an AI-delegate review ended, as shown on the audit row's badge.
///
/// A review can reach a TERMINAL state without any delegate deciding:
/// the reaper times it out at the deadline, or the strategy supersedes
/// it when the signal expires first. Both carry ``decision == nil`` AND
/// a ``resolvedAt`` timestamp, so a badge derived from ``decision``
/// alone labelled them "Pending" right next to a "Decided" time — a
/// plain lie about a finished review. They get their own labels.
enum AiReviewDecision {
    case approved
    case rejected
    case timedOut
    case superseded
    case pending

    /// Catalog key for the badge label — kept as a plain ``String``
    /// so the mapping is asserted directly in unit tests.
    ///
    /// ``timedOut`` deliberately reuses the inbox's expiry label: a
    /// review the reaper closed at its deadline IS the expired row, and
    /// minting a second string for the same fact would only let the two
    /// drift apart in 45 locales.
    var localizationKey: String {
        switch self {
        case .approved: return "aiReviews.decision.approve"
        case .rejected: return "aiReviews.decision.reject"
        case .timedOut: return "aiReviews.pending.expired"
        case .superseded: return "aiReviews.decision.superseded"
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

/// One surfaced submission failure.
///
/// Identifiable and QUEUED rather than a single shared string: two rows
/// can be decided concurrently, and with one slot the second failure
/// would silently overwrite the first — or dismissing one alert would
/// swallow a sibling the user never saw. Each event is acknowledged
/// individually.
struct AiReviewSubmitAlert: Identifiable, Equatable, Sendable {
    let id: UInt64
    let reviewPublicId: String
    let message: String
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

    private(set) var submitAlerts: [AiReviewSubmitAlert] = []
    private(set) var inFlight: Set<String> = []

    @ObservationIgnored private let liveUpdates = LiveUpdateObserver()

    /// Screen-session state. Every reload commit, decision commit, and
    /// surfaced alert is stamped with the generation it began under and
    /// discarded if the screen has since gone away or reappeared — the
    /// View's `.task`, its retry button, and each submission all spawn
    /// tasks that outlive a disappearance otherwise.
    ///
    /// A freshly constructed ViewModel is ACTIVE: the screen builds it on
    /// appear, so the first load must be allowed to commit before
    /// ``beginSession()`` is even reached.
    @ObservationIgnored private var sessionGeneration: UInt64 = 0
    @ObservationIgnored private(set) var isSessionActive = true

    /// Live-update observation owned by the current appearance, so
    /// ``endSession(token:)`` is the single teardown point.
    @ObservationIgnored private var liveUpdatesToken: UInt64?

    /// Bumped once per fetch pass so a feed that resolves after a newer
    /// pass has started cannot commit over it. The serial worker already
    /// prevents overlapping passes; this also covers the window opened by
    /// committing the two feeds independently.
    @ObservationIgnored private var fetchGeneration: UInt64 = 0

    @ObservationIgnored private var nextAlertId: UInt64 = 0

    /// Reviews THIS session resolved successfully.
    ///
    /// The decision write and the `/pending` query are not one
    /// transaction, so a snapshot already in flight when the decision
    /// lands can still carry the row and would resurrect something the
    /// user has already dealt with. Such ids are filtered out of every
    /// committed snapshot until a snapshot stops carrying them — at that
    /// point the server has caught up and the entry is dropped, so the
    /// filter can never hide a legitimately re-opened review forever.
    @ObservationIgnored private var locallyResolved: Set<String> = []

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

    /// Drive one screen appearance end to end: open the session, run the
    /// initial load, observe live pulses, and hold until the view's task
    /// is cancelled — then tear the session down.
    ///
    /// The whole appearance lives INSIDE the cancellation handler. An
    /// earlier shape called ``beginSession()``, then awaited the initial
    /// load, and only installed the teardown afterwards — so a view that
    /// disappeared while that first load was slow or gated was never torn
    /// down at all: the session stayed active and the unstructured reload
    /// worker could still commit into a screen the user had left. The
    /// ordering is the correctness property, so it lives here where a test
    /// can drive it, rather than in the View where nothing can.
    func runSession(observing webSocketManager: WebSocketManager) async {
        let session = beginSession()
        await withTaskCancellationHandler {
            await load()
            guard !Task.isCancelled else { return }
            startObservingLiveUpdates(from: webSocketManager)
            try? await Task.sleep(nanoseconds: .max)
        } onCancel: {
            Task { @MainActor in
                self.endSession(token: session)
            }
        }
    }

    /// Mark the screen as on-screen and open a new work generation.
    ///
    /// Returns the token to hand back to ``endSession(token:)``; a stale
    /// token (a superseded appearance) is a no-op there, so a late
    /// teardown from a previous appearance cannot deactivate the current
    /// one. Work started under an older generation stops committing as
    /// soon as this is called.
    @discardableResult
    func beginSession() -> UInt64 {
        sessionGeneration &+= 1
        isSessionActive = true
        return sessionGeneration
    }

    /// Mark the screen as gone. In-flight reloads and submissions still
    /// run to completion — cancelling a decision mid-write would be
    /// worse than letting it land — but none of them may touch published
    /// state or raise an alert afterwards.
    ///
    /// Also stops live observation and DROPS any unacknowledged failure
    /// alerts. An alert is a transient notice scoped to the screen that
    /// raised it: the user leaving is itself a dismissal, and carrying the
    /// queue into the next appearance would ambush them with a failure
    /// from a visit they had already walked away from.
    func endSession(token: UInt64) {
        guard token == sessionGeneration else { return }
        isSessionActive = false
        submitAlerts.removeAll()
        if let token = liveUpdatesToken {
            liveUpdates.stop(session: token)
            liveUpdatesToken = nil
        }
    }

    /// Whether work stamped with `session` may still write. False once
    /// the screen went away or a newer appearance superseded it.
    private func isCurrent(session: UInt64) -> Bool {
        return isSessionActive && session == sessionGeneration
    }

    /// Whether a feed that began in fetch pass `fetch` may commit.
    private func canCommitFetch(session: UInt64, fetch: UInt64) -> Bool {
        return isCurrent(session: session) && fetch == fetchGeneration
    }

    /// Begin observing live ai_review activity pulses plus the reconnect
    /// heal for a debounced REST reload. Returns the session token to hand
    /// back to ``stopObservingLiveUpdates(token:)`` so a stale view-task
    /// teardown cannot stop a newer session.
    ///
    /// The token is also retained so ``endSession(token:)`` can stop
    /// observation itself — one teardown call, one thing to get right.
    ///
    /// The pulse drives the serialized ``load()``, so in delegate mode it
    /// refreshes the PENDING feed as well as the audit list — a
    /// ``decision_ack`` frame from a peer delegate removes the row here
    /// without the user touching anything.
    @discardableResult
    func startObservingLiveUpdates(from webSocketManager: WebSocketManager) -> UInt64 {
        let state = webSocketManager.state
        let token = liveUpdates.start(
            slots: [LiveUpdateObserver.pulse(state.$lastAiReviewActivityAt)],
            connection: webSocketManager.$connectionState.eraseToAnyPublisher(),
            reload: { [weak self] in await self?.load() }
        )
        liveUpdatesToken = token
        return token
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
    /// it the endpoint would 422).
    ///
    /// Each feed commits THE MOMENT IT COMPLETES, never waiting on its
    /// sibling. This is what makes them genuinely independent: a pure
    /// ``aiDelegate`` holds no ``read:ai_reviews``, so its audit request
    /// can hang or crawl, and its already-successful inbox must still
    /// reach the screen — the earlier "await audit, then await pending"
    /// shape left that delegate staring at an empty inbox for as long as
    /// the audit call took. The reverse holds for an operator.
    ///
    /// The pass still does not RETURN until both feeds settle, so the
    /// serialized coordinator keeps its "a completed fetch satisfies the
    /// waiter" contract. Never touches ``inFlight`` — that is per-review
    /// and cleared at each write's own completion.
    private func performFetch() async {
        guard isSessionActive else { return }
        fetchGeneration &+= 1
        let fetch = fetchGeneration
        let session = sessionGeneration
        let delegateMode = showsPendingInbox

        async let auditDone: Void = commitAuditFeed(session: session, fetch: fetch)
        async let pendingDone: Void = commitPendingFeed(
            enabled: delegateMode,
            session: session,
            fetch: fetch
        )
        await auditDone
        await pendingDone
    }

    /// Fetch and commit the audit list on its own completion.
    private func commitAuditFeed(session: UInt64, fetch: UInt64) async {
        do {
            let items = try await api.fetchAiReviews()
            guard canCommitFetch(session: session, fetch: fetch) else { return }
            reviews = items
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch AI reviews: \(error.localizedDescription, privacy: .public)")
            guard canCommitFetch(session: session, fetch: fetch) else { return }
            loadError = error
        } catch {
            logger.error("Failed to fetch AI reviews: \(error.localizedDescription, privacy: .public)")
            guard canCommitFetch(session: session, fetch: fetch) else { return }
            loadError = .invalidResponse
        }
    }

    /// Fetch and commit the delegate inbox on its own completion. Outside
    /// delegate mode the feed is cleared without a request. A failure
    /// keeps the previously committed rows so a transient error does not
    /// blank an inbox the user is working through.
    private func commitPendingFeed(enabled: Bool, session: UInt64, fetch: UInt64) async {
        guard enabled else {
            guard canCommitFetch(session: session, fetch: fetch) else { return }
            pending = []
            locallyResolved.removeAll()
            pendingLoadError = nil
            return
        }
        do {
            let items = try await api.fetchPendingAiReviews().items
            guard canCommitFetch(session: session, fetch: fetch) else { return }
            applyPendingSnapshot(items)
            pendingLoadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch pending AI reviews: \(error.localizedDescription, privacy: .public)")
            guard canCommitFetch(session: session, fetch: fetch) else { return }
            pendingLoadError = error
        } catch {
            logger.error("Failed to fetch pending AI reviews: \(error.localizedDescription, privacy: .public)")
            guard canCommitFetch(session: session, fetch: fetch) else { return }
            pendingLoadError = .invalidResponse
        }
    }

    /// Commit a server snapshot, subtracting reviews this session already
    /// resolved, and forget the ids the server itself has stopped
    /// returning. Ordering matters: the intersection runs FIRST so an id
    /// that has aged out of the snapshot leaves the filter with it.
    private func applyPendingSnapshot(_ items: [PendingReviewSummaryItem]) {
        locallyResolved.formIntersection(items.map(\.reviewPublicId))
        pending = items.filter { !locallyResolved.contains($0.reviewPublicId) }
    }

    /// Whether a row's decision controls are disabled by its own
    /// in-flight write.
    func isInFlight(_ reviewPublicId: String) -> Bool {
        return inFlight.contains(reviewPublicId)
    }

    /// Record a verdict for one pending review.
    ///
    /// Everything that can be decided locally is decided BEFORE the
    /// request goes out, in this order: reject a double-submit on the
    /// same review; re-resolve the delegate identity and the submit
    /// permission (never trusting the render-time snapshot); confirm the
    /// review is STILL in the inbox, so a confirmation the user left open
    /// while a peer resolved the row cannot fire a doomed write; and
    /// refuse an over-long rationale rather than let the backend answer
    /// with a 422 shape the decision contract does not model. The outcome
    /// mapping lives in ``applyDecisionOutcome``; nothing is ever
    /// auto-retried.
    @discardableResult
    func submitDecision(
        reviewPublicId: String,
        decision: AiReviewDecisionIntent,
        rationale: String?
    ) async -> Bool {
        guard !inFlight.contains(reviewPublicId) else { return false }
        let session = sessionGeneration
        guard isSessionActive else { return false }
        guard showsPendingInbox, canSubmitDecision() else {
            surface(
                reviewPublicId: reviewPublicId,
                message: localized("aiReviews.decision.error.notDelegate"),
                session: session
            )
            return false
        }
        guard pending.contains(where: { $0.reviewPublicId == reviewPublicId }) else {
            surface(
                reviewPublicId: reviewPublicId,
                message: localized("aiReviews.decision.error.notFound"),
                session: session
            )
            return false
        }

        let normalized = Self.normalizedRationale(rationale)
        guard !AiReviewRationale.exceedsLimit(normalized) else {
            surface(
                reviewPublicId: reviewPublicId,
                message: rationaleTooLongMessage(),
                session: session
            )
            return false
        }

        inFlight.insert(reviewPublicId)
        defer { inFlight.remove(reviewPublicId) }

        do {
            let response = try await api.submitAiReviewDecision(
                reviewPublicId: reviewPublicId,
                decision: decision,
                rationale: normalized
            )
            return await applyDecisionOutcome(
                reviewPublicId: reviewPublicId,
                response: response,
                session: session
            )
        } catch {
            surface(
                reviewPublicId: reviewPublicId,
                message: genericSubmitMessage(detail: Self.submitErrorMessage(error)),
                session: session
            )
            return false
        }
    }

    /// Queue one failure for the user, unless the screen it belongs to is
    /// gone. Appending (rather than overwriting a single slot) is what
    /// lets two concurrently-failing rows both be seen.
    private func surface(reviewPublicId: String, message: String, session: UInt64) {
        guard isCurrent(session: session) else { return }
        nextAlertId &+= 1
        submitAlerts.append(
            AiReviewSubmitAlert(id: nextAlertId, reviewPublicId: reviewPublicId, message: message)
        )
    }

    /// The failure currently presented — the OLDEST unacknowledged one,
    /// so alerts are shown in the order they happened.
    var currentSubmitAlert: AiReviewSubmitAlert? {
        return submitAlerts.first
    }

    /// Acknowledge exactly ONE failure. A queued sibling still gets its
    /// turn; dismissing can never clear an alert the user has not seen.
    func dismissSubmitAlert(_ alert: AiReviewSubmitAlert) {
        submitAlerts.removeAll { $0.id == alert.id }
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
        response: AiReviewDecisionResponse,
        session: UInt64
    ) async -> Bool {
        switch Self.outcome(for: response) {
        case .accepted:
            /// The tick fires even if this screen is gone: the verdict IS
            /// recorded server-side, so Home's cached badge is stale
            /// whether or not anyone is still looking at the inbox.
            appState.aiReviewDecisionTick &+= 1
            guard isCurrent(session: session) else { return true }
            locallyResolved.insert(reviewPublicId)
            pending.removeAll { $0.reviewPublicId == reviewPublicId }
            await load()
            return true
        case .resolvedByPeer:
            surface(
                reviewPublicId: reviewPublicId,
                message: localized("aiReviews.decision.error.peerResolved"),
                session: session
            )
            await reloadIfCurrent(session: session)
            return false
        case .expired:
            surface(
                reviewPublicId: reviewPublicId,
                message: localized("aiReviews.decision.error.expired"),
                session: session
            )
            await reloadIfCurrent(session: session)
            return false
        case .notFound:
            surface(
                reviewPublicId: reviewPublicId,
                message: localized("aiReviews.decision.error.notFound"),
                session: session
            )
            await reloadIfCurrent(session: session)
            return false
        case .notAuthorized:
            surface(reviewPublicId: reviewPublicId, message: response.message, session: session)
            return false
        case .failed:
            surface(
                reviewPublicId: reviewPublicId,
                message: genericSubmitMessage(detail: response.message),
                session: session
            )
            return false
        }
    }

    /// Reconcile after a stale outcome, but only while the screen that
    /// asked for it is still on-screen.
    private func reloadIfCurrent(session: UInt64) async {
        guard isCurrent(session: session) else { return }
        await load()
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

    /// Derive the badge verdict for an audit row from its TERMINAL
    /// STATE, not from ``decision`` alone.
    ///
    /// ``status`` is the lifecycle authority — it is the state machine's
    /// own field, and it is the only one that distinguishes the two ways
    /// a review can finish with nobody having decided (`timeout` from the
    /// reaper, `superseded` from the strategy abandoning the signal).
    /// ``decision`` is consulted only as a forward-compatible fallback
    /// for a status this build does not recognise, so a future backend
    /// state degrades to something truthful rather than to "Pending".
    ///
    /// ``resolutionMode`` is deliberately NOT used: it records WHICH
    /// delegate answered (primary, fanout secondary, first responder) or
    /// that nobody did, which the status already implies for badge
    /// purposes. Feeding it in would add a second source of truth for
    /// one label.
    ///
    /// Both inputs are lowered defensively.
    static func verdict(decision: String?, status: String) -> AiReviewDecision {
        switch status.lowercased() {
        case "resolved_approved": return .approved
        case "resolved_rejected": return .rejected
        case "timeout": return .timedOut
        case "superseded": return .superseded
        case "pending", "fanout_dispatched": return .pending
        default: break
        }
        switch decision?.lowercased() {
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

    /// "Rationale is too long …" — states the limit so the user knows how
    /// much to cut instead of guessing.
    private func rationaleTooLongMessage() -> String {
        let language = appState.locale.catalogLanguage
        let template = LocaleStrings.localized("aiReviews.decision.error.rationaleTooLong", in: language)
        return String(
            format: template,
            locale: Locale(identifier: language.rawValue),
            AiReviewRationale.characterLimit
        )
    }
}
