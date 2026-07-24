import Combine
import Foundation
import Observation
import os

/// Control routing for one process row, resolved from the joined
/// ``ConfiguredProcess`` discriminators plus the caller's permission.
///
/// - ``none``: no controls — the row has no configured match, the caller
///   lacks ``manage:processes``, the row is a strategy/backtest role (it
///   gets controls on the Strategies screen instead), or it is a
///   config-only executor template (the backend 422s a template start).
/// - ``local``: this node owns the process — ``POST`` start/stop, and a
///   restart is a local stop-then-start sequence (mirrors the web).
/// - ``remote``: another container owns the process — desired-state
///   ``PATCH`` only (enable / disable / restart). A local start/stop on a
///   remote row can spawn a duplicate publisher, so it is never offered.
enum ProcessControlMode: String, Equatable, Sendable {
    case none
    case local
    case remote
}

/// ViewModel for ``ProcessesView`` — the process monitor over
/// ``APIClientProtocol/fetchProcessSummary`` (`GET /api/processes/summary`,
/// gated by `read:system_status`). Surfaces per-category running/total
/// counts plus a per-process list (name, running state, role, memory, CPU).
///
/// Adds the first mutation surface on the read-only screens series:
/// start / stop / restart and desired-state controls. The summary feed
/// lacks the discriminators the controls need, so a reload also fetches
/// ``fetchConfiguredProcesses`` (`GET /api/processes/configured`, gated by
/// `read:processes`) and joins it by name. The summary drives the row list
/// and its metrics; the configured join drives the control decision. A row
/// with no configured match — or a stale/absent join after a failed
/// configured fetch (fail closed) — gets no controls.
///
/// Reload coordination: EVERY reload (initial, retry, pull-to-refresh,
/// live-pulse, post-mutation) funnels through ``load()``, a single
/// serialized/generation-protected worker. No two fetch bodies ever commit
/// concurrently, so a stale response can never overwrite a fresh one and
/// ``isLoading`` is never cleared while another load runs. A request that
/// lands mid-reload coalesces into exactly one follow-up that observes the
/// newest generation.
///
/// Mutations re-resolve permission + configured presence + role + kind +
/// ownership AT EXECUTION TIME (never trusting the confirm-time snapshot),
/// abort with a surfaced error if the row changed, inspect the HTTP-200
/// operational status, and reload-after-mutate. Desired-state writes
/// persist INTENT only; a per-name ``pendingDesiredState`` shows a pending
/// indicator that clears at THAT mutation's completion (post-reload) —
/// never wholesale. An ``inFlight`` set disables a row's controls for the
/// duration of its mutation so a double-tap cannot double-submit.
@MainActor
@Observable
final class ProcessesViewModel {

    var summary: ProcessSummaryData?
    var configuredByName: [String: ConfiguredProcess] = [:]
    var isLoading: Bool = false
    var loadError: APIError?
    var submitError: String?

    private(set) var inFlight: Set<String> = []
    private(set) var pendingDesiredState: Set<String> = []

    @ObservationIgnored private let liveUpdates = LiveUpdateObserver()

    /// Serialized-reload coordinator state. ``reloadRequestedSeq`` is bumped
    /// on every ``load()``; ``reloadServedSeq`` tracks the newest request a
    /// completed fetch has satisfied; a single worker drains requests one at
    /// a time and resumes each caller once a fetch that began at or after
    /// its request has committed.
    @ObservationIgnored private var reloadRequestedSeq: UInt64 = 0
    @ObservationIgnored private var reloadServedSeq: UInt64 = 0
    @ObservationIgnored private var reloadWorkerRunning = false
    @ObservationIgnored private var reloadWaiters: [(seq: UInt64, continuation: CheckedContinuation<Void, Never>)] = []

    private let api: APIClientProtocol
    private let appState: AppState
    private let canManage: @MainActor () -> Bool

    private let logger = AppLogger.make(category: "ProcessesViewModel")

    init(
        api: APIClientProtocol = APIClient.shared,
        appState: AppState = .shared,
        canManageProcesses: @escaping @MainActor () -> Bool = { AuthService.shared.hasPermission(.manageProcesses) }
    ) {
        self.api = api
        self.appState = appState
        self.canManage = canManageProcesses
    }

    /// Begin observing live process-event frames (summary / configured /
    /// run) plus the reconnect heal for a debounced REST reload. Returns
    /// the session token to hand back to ``stopObservingLiveUpdates(token:)``
    /// so a stale view-task teardown cannot stop a newer session.
    @discardableResult
    func startObservingLiveUpdates(from webSocketManager: WebSocketManager) -> UInt64 {
        let state = webSocketManager.state
        return liveUpdates.start(
            slots: [
                LiveUpdateObserver.pulse(state.$lastProcessSummary),
                LiveUpdateObserver.pulse(state.$lastProcessConfigured),
                LiveUpdateObserver.pulse(state.$lastProcessRun),
            ],
            connection: webSocketManager.$connectionState.eraseToAnyPublisher(),
            reload: { [weak self] in await self?.load() }
        )
    }

    /// Cancel observation + any pending debounced reload for `token`. A
    /// stale token (a superseded session) is a no-op.
    func stopObservingLiveUpdates(token: UInt64) {
        liveUpdates.stop(session: token)
    }

    /// Per-process rows, name-sorted for a stable render order.
    var sortedProcesses: [ProcessSummaryItem] {
        return (summary?.processes ?? []).sorted { $0.name < $1.name }
    }

    /// Whether the caller currently holds ``manage:processes`` — resolved
    /// live so a permission change (e.g. a role revoke) is honored.
    var canManageProcesses: Bool {
        return canManage()
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

    /// One fetch pass: the summary feed (row list + metrics) and the
    /// configured rows (control-plane join), concurrently. A summary failure
    /// sets ``loadError`` and preserves the cached summary; a configured
    /// failure CLEARS the join so controls fail closed — the read-only
    /// monitor keeps rendering, but no row exposes controls until a
    /// successful configured fetch restores the join. Never clears pending
    /// state (that is per-name, at each mutation's completion).
    private func performFetch() async {
        async let summaryResult = api.fetchProcessSummary()
        async let configuredResult = api.fetchConfiguredProcesses()

        do {
            summary = try await summaryResult
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch process summary: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch process summary: \(error.localizedDescription, privacy: .public)")
            loadError = .invalidResponse
        }

        do {
            configuredByName = Self.indexByName(try await configuredResult)
        } catch {
            logger.warning("Failed to fetch configured processes (controls fail closed): \(error.localizedDescription, privacy: .public)")
            configuredByName = [:]
        }
    }

    /// Index configured rows by their unique ``name`` for the summary join.
    static func indexByName(_ rows: [ConfiguredProcess]) -> [String: ConfiguredProcess] {
        return Dictionary(rows.map { ($0.name, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    /// Resolve the control routing for one summary row from its configured
    /// join and the caller's permission. Pure so the decision table is
    /// unit-tested directly.
    static func controlMode(
        configured: ConfiguredProcess?,
        canManageProcesses: Bool
    ) -> ProcessControlMode {
        guard canManageProcesses, let configured else { return .none }
        if configured.role == "strategy" || configured.role == "backtest" {
            return .none
        }
        if configured.kind == "template" {
            return .none
        }
        return configured.managedRemotely == true ? .remote : .local
    }

    /// Control routing for a summary row by name, using the live permission.
    func controlMode(for name: String) -> ProcessControlMode {
        return Self.controlMode(
            configured: configuredByName[name],
            canManageProcesses: canManage()
        )
    }

    /// Whether the restart affordance is offered for a row. A local row
    /// can restart only while running; a remote row can also restart while
    /// enabled-but-stopped (the coordinator will bounce it on converge).
    /// Mirrors the web `isRunning || (managedRemotely && enabled)`.
    static func showsRestart(
        mode: ProcessControlMode,
        running: Bool,
        configured: ConfiguredProcess?
    ) -> Bool {
        switch mode {
        case .none:
            return false
        case .local:
            return running
        case .remote:
            return running || configured?.enabled == true
        }
    }

    /// Client-minted restart idempotency token. UUID-derived (v4) — its
    /// 36-character `A-F0-9-` form satisfies the backend
    /// ``^[A-Za-z0-9_-]{8,64}$`` grammar. Minted once per user restart
    /// intent and reused only for a retry of that same intent.
    static func makeRestartNonce() -> String {
        return UUID().uuidString
    }

    /// Validate a restart nonce against the backend grammar
    /// ``^[A-Za-z0-9_-]{8,64}$``. Kept pure so the mint helper is pinned.
    static func isValidRestartNonce(_ nonce: String) -> Bool {
        guard (8...64).contains(nonce.count) else { return false }
        return nonce.allSatisfy { character in
            guard character.isASCII else { return false }
            return character.isLetter || character.isNumber || character == "_" || character == "-"
        }
    }

    /// Map a thrown mutation error to the user-facing message. Backend
    /// ``APIError/serverError`` details (executor-template 422, unknown /
    /// per-wallet-instance 404, disabled-restart 409, missing-nonce 422,
    /// scope 403) are surfaced verbatim.
    static func submitErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        return error.localizedDescription
    }

    /// Inspect a ``POST start`` HTTP-200 payload. ``success`` and
    /// ``already_running`` are benign; any other status (``error``) is an
    /// operational failure whose backend ``message`` is surfaced verbatim.
    static func startFailureMessage(_ data: ProcessStartData) -> String? {
        switch data.status {
        case "success", "already_running":
            return nil
        default:
            return data.message ?? data.status
        }
    }

    /// Inspect a ``POST stop`` HTTP-200 payload. ``success`` and
    /// ``not_running`` are benign; any other status is an operational
    /// failure whose backend ``message`` is surfaced verbatim.
    static func stopFailureMessage(_ data: ProcessStopData) -> String? {
        switch data.status {
        case "success", "not_running":
            return nil
        default:
            return data.message ?? data.status
        }
    }

    /// Whether a row's controls are disabled by an in-flight mutation.
    func isInFlight(_ name: String) -> Bool {
        return inFlight.contains(name)
    }

    /// Whether a row shows a desired-state pending indicator.
    func isPending(_ name: String) -> Bool {
        return pendingDesiredState.contains(name)
    }

    /// Start (local) or enable (remote) a process. Plain, non-destructive
    /// action — no confirmation. Never auto-retried. ``expected`` is the
    /// routing the View rendered; execution re-resolves it and aborts if the
    /// row changed.
    @discardableResult
    func start(name: String, expected: ProcessControlMode) async -> Bool {
        guard expected != .none else { return false }
        guard let mode = executionMode(for: name, expected: expected) else { return false }
        return await withInFlight(name: name, isDesiredState: mode == .remote) {
            switch mode {
            case .local:
                return await self.runLocalStart(name: name)
            case .remote:
                return await self.runRemote(name: name, action: "enable", nonce: nil)
            case .none:
                return false
            }
        }
    }

    /// Stop (local) or disable (remote) a process. Destructive — the View
    /// confirms first. Never auto-retried.
    @discardableResult
    func stop(name: String, expected: ProcessControlMode) async -> Bool {
        guard expected != .none else { return false }
        guard let mode = executionMode(for: name, expected: expected) else { return false }
        return await withInFlight(name: name, isDesiredState: mode == .remote) {
            switch mode {
            case .local:
                return await self.runLocalStop(name: name)
            case .remote:
                return await self.runRemote(name: name, action: "disable", nonce: nil)
            case .none:
                return false
            }
        }
    }

    /// Restart a process. A remote row PATCHes desired-state ``restart``
    /// with a freshly minted nonce; a local row runs a stop-then-start
    /// sequence that re-resolves ownership between the legs. Destructive —
    /// the View confirms first.
    @discardableResult
    func restart(name: String, expected: ProcessControlMode) async -> Bool {
        guard expected != .none else { return false }
        guard let mode = executionMode(for: name, expected: expected) else { return false }
        switch mode {
        case .local:
            return await withInFlight(name: name, isDesiredState: false) {
                await self.runLocalRestart(name: name)
            }
        case .remote:
            let nonce = Self.makeRestartNonce()
            return await withInFlight(name: name, isDesiredState: true) {
                await self.runRemote(name: name, action: "restart", nonce: nonce)
            }
        case .none:
            return false
        }
    }

    /// Re-resolve the routing at execution time and reject a stale intent.
    /// If the row is no longer controllable, or its routing diverged from
    /// what the user acted on (became remote/absent/ineligible), abort with
    /// a surfaced error rather than sending a now-wrong request.
    private func executionMode(for name: String, expected: ProcessControlMode) -> ProcessControlMode? {
        let current = controlMode(for: name)
        guard current != .none, current == expected else {
            submitError = localized("processes.action.staleControl")
            return nil
        }
        return current
    }

    /// Local start leg: POST, inspect the HTTP-200 status, reload on a
    /// benign status, surface (no reload) on an operational or thrown
    /// failure.
    private func runLocalStart(name: String) async -> Bool {
        do {
            let data = try await api.startProcess(name: name, body: ProcessStartBody(mode: nil, parameters: nil))
            if let message = Self.startFailureMessage(data) {
                submitError = message
                return false
            }
            await load()
            return true
        } catch {
            submitError = Self.submitErrorMessage(error)
            return false
        }
    }

    /// Local stop leg: POST, inspect the HTTP-200 status, reload on a benign
    /// status, surface (no reload) on an operational or thrown failure.
    private func runLocalStop(name: String) async -> Bool {
        do {
            let data = try await api.stopProcess(name: name)
            if let message = Self.stopFailureMessage(data) {
                submitError = message
                return false
            }
            await load()
            return true
        } catch {
            submitError = Self.submitErrorMessage(error)
            return false
        }
    }

    /// Desired-state PATCH (enable / disable / restart). Success reloads;
    /// a thrown failure surfaces the backend detail without a reload (no
    /// intent was persisted).
    private func runRemote(name: String, action: String, nonce: String?) async -> Bool {
        do {
            _ = try await api.setProcessDesiredState(
                name: name,
                body: ProcessDesiredStateBody(action: action, restartNonce: nonce)
            )
            await load()
            return true
        } catch {
            submitError = Self.submitErrorMessage(error)
            return false
        }
    }

    /// Local restart, modeled as two honest phases. Phase 1 stops; a stop
    /// failure aborts with the stop error and no reload (nothing changed).
    /// Between the legs the routing is RE-RESOLVED against a FRESH feed —
    /// never the pre-stop cache. Backend ownership treats a locally running
    /// rogue copy as LOCAL only while it runs and REMOTE once stopped, so the
    /// cached row is stale the instant the stop lands; a start POST against
    /// it would spawn a duplicate publisher. The refresh funnels through the
    /// serialized ``load()`` coordinator (NOT a direct fetch — a direct
    /// commit could clobber a newer pulse-driven commit, stale-over-fresh)
    /// which commits the configured feed fail-closed; that reload doubles as
    /// the abort's reload. The start leg is abandoned (report the partial
    /// stopped-not-restarted state) if the feed's committed state is anything
    /// but ``local`` (fetch failed → join cleared, row absent, or flipped
    /// remote). Phase 2 starts; a start failure — operational or thrown —
    /// reports the partial state and still reloads so the UI shows the actual
    /// stopped process.
    private func runLocalRestart(name: String) async -> Bool {
        do {
            let stopData = try await api.stopProcess(name: name)
            if let message = Self.stopFailureMessage(stopData) {
                submitError = message
                return false
            }
        } catch {
            submitError = Self.submitErrorMessage(error)
            return false
        }

        await load()
        guard controlMode(for: name) == .local else {
            submitError = localized("processes.action.restartTargetChanged")
            return false
        }

        do {
            let startData = try await api.startProcess(name: name, body: ProcessStartBody(mode: nil, parameters: nil))
            if let message = Self.startFailureMessage(startData) {
                submitError = partialRestartMessage(detail: message)
                await load()
                return false
            }
            await load()
            return true
        } catch {
            submitError = partialRestartMessage(detail: Self.submitErrorMessage(error))
            await load()
            return false
        }
    }

    /// Shared mutation envelope: reject a double-submit, mark the row
    /// in-flight (and pending for desired-state writes), run the body, then
    /// clear in-flight AND this row's pending indicator at completion —
    /// per-name, never wholesale, and post any reload the body performed.
    private func withInFlight(
        name: String,
        isDesiredState: Bool,
        _ body: () async -> Bool
    ) async -> Bool {
        guard !inFlight.contains(name) else { return false }
        inFlight.insert(name)
        if isDesiredState {
            pendingDesiredState.insert(name)
        }
        defer {
            inFlight.remove(name)
            pendingDesiredState.remove(name)
        }
        return await body()
    }

    private func localized(_ key: String) -> String {
        return LocaleStrings.localized(key, in: appState.locale.catalogLanguage)
    }

    /// "Stopped, but restart failed: <detail>" — the detail is the backend
    /// message (operational status ``error``) or the thrown error verbatim.
    private func partialRestartMessage(detail: String) -> String {
        let language = appState.locale.catalogLanguage
        let template = LocaleStrings.localized("processes.action.partialRestart", in: language)
        return String(format: template, locale: Locale(identifier: language.rawValue), detail)
    }

    /// Surface the "couldn't load" variant only when there is no cached
    /// summary to show and a load has settled.
    static func shouldShowLoadError(
        hasData: Bool,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard loadError != nil else { return false }
        return !hasData
    }

    /// Catalog key for a process's running state — ``running`` /
    /// ``stopped`` — kept pure so the mapping is unit-tested directly.
    static func runningLabelKey(_ running: Bool) -> String {
        return running ? "processes.status.running" : "processes.status.stopped"
    }

    /// Locale-aware memory string for a process's RSS, or ``"—"`` when
    /// the sample is missing (thread-mode / unsampled processes).
    static func formattedMemory(_ rssBytes: Int?) -> String {
        guard let rss = rssBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(rss), countStyle: .memory)
    }

    /// Locale-aware CPU string. ``cpuPercent`` is already a percentage
    /// (``3.5`` means 3.5%), so it is divided by 100 before the percent
    /// formatter — which multiplies back by 100 — renders it. ``"—"``
    /// when the sample is missing.
    static func formattedCpuPercent(_ cpuPercent: Double?, locale: AppLocale) -> String {
        guard let cpu = cpuPercent else { return "—" }
        return (cpu / 100.0).formattedPercent(in: locale, fractionDigits: 1)
    }
}
