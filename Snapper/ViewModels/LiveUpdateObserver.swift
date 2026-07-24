import Combine
import Foundation

/// Shared debounced live-reload driver for the read-only screens whose
/// WebSocket frames are pure reload pulses (Signals, Processes,
/// Strategies, AI Reviews).
///
/// Responsibilities:
///  1. Observe an arbitrary set of ``WSState`` `@Published` slots. Slots
///     arrive already type-erased to `Void` publishers because the caller
///     does not care about the payload — a frame is a signal to refetch,
///     never a source of list state. ``WSState`` is a Combine
///     `ObservableObject`, so observation goes through the
///     `publisher.values` async-sequence bridge; `withObservationTracking`
///     would silently miss its updates.
///  2. Observe ``WebSocketManager/connectionState`` for a REAL transition
///     into `.connected` (deduplicated against the previous state) and
///     reload so frames missed while the socket was offline are healed.
///  3. A leading-window debounce (250 ms) so a burst of frames coalesces
///     into a single REST reload.
///  4. A startup reconciliation reload fired once per session — a bounded
///     debounce armed at ``start``, NOT gated on any delivered value — so
///     it closes the load→subscribe window (a frame landing before the
///     loops subscribe would be dropped as the replayed initial value)
///     even for a source that never replays. It coalesces with any real
///     frame in the same window.
///
/// Reload serialization: a single serial reload worker persists across
/// sessions. It never cancels an in-flight reload; a pulse that lands mid
/// reload is queued and runs as exactly one follow-up after the current
/// reload completes. The worker rechecks the session generation
/// IMMEDIATELY before every reload invocation, so a superseded session's
/// queued or in-flight follow-up is dropped rather than run — and a new
/// session's reload QUEUES behind an in-flight superseded reload instead
/// of overlapping it. ``stop`` deliberately leaves the serialization state
/// alive for exactly this reason.
///
/// Lifecycle: ``start(slots:connection:reload:)`` mints a new session
/// (returns its token) after stopping any prior one. ``stop(session:)``
/// with a token is a no-op unless the token is the current session, so a
/// stale SwiftUI `.task` teardown cannot stop a newer observation. Every
/// observation loop captures the session generation and bails the moment
/// it is cancelled OR the generation moves on. All captures are weak;
/// ``deinit`` cancels every outstanding task.
///
/// - Important: Every publisher passed to ``start`` (each slot and the
///   connection stream) MUST replay a current value on subscription
///   (Combine `@Published` / `CurrentValueSubject` semantics — see
///   ``pulse(_:)``). Each observation loop treats its first delivered
///   value as that replayed baseline and drops it; a non-replaying source
///   would have its first REAL emission dropped. Every production caller
///   passes `@Published`-backed slots and `$connectionState`, which
///   satisfy the contract. The startup reconciliation itself is
///   source-agnostic and does not depend on replay.
@MainActor
final class LiveUpdateObserver {

    /// Observation-window debounce. 250 ms matches
    /// ``OrdersViewModel/liveReloadDebounceNanos`` and stays at or above
    /// the backend frame throttles (500 ms signals / process summary,
    /// 1000 ms strategy list) so no burst outruns the window.
    static let debounceNanos: UInt64 = 250_000_000

    /// Erase a `Never`-failing Combine publisher to a `Void` pulse stream.
    ///
    /// Declared `nonisolated` on purpose: ``AsyncPublisher`` delivers
    /// values on a background cooperative executor, and a transform
    /// closure inferred as `@MainActor` (the default in a `@MainActor`
    /// caller) would trip the Swift actor-isolation runtime check when
    /// Combine invokes it there. A nonisolated `map` runs safely on any
    /// executor; the resulting `Void` then hops back to the observing
    /// `@MainActor` task.
    ///
    /// - Important: The wrapped publisher MUST replay its current value on
    ///   subscription. The observer's first-value drop relies on it.
    nonisolated static func pulse<P: Publisher>(
        _ publisher: P
    ) -> AnyPublisher<Void, Never> where P.Failure == Never {
        return publisher.map { _ in () }.eraseToAnyPublisher()
    }

    private nonisolated static func isConnected(_ state: WebSocketManager.ConnectionState) -> Bool {
        if case .connected = state { return true }
        return false
    }

    /// Monotonic session token. Bumped on every ``start`` and ``stop`` so a
    /// buffered continuation, a stale teardown, or a superseded in-flight
    /// reload all detect that they are no longer current.
    private var generation: UInt64 = 0
    private var slots: [AnyPublisher<Void, Never>] = []
    private var connection: AnyPublisher<WebSocketManager.ConnectionState, Never>?
    private var reload: (@MainActor () async -> Void)?
    private var observationTasks: [Task<Void, Never>] = []
    private var pendingDebounceTask: Task<Void, Never>?

    /// Serialization state — deliberately PRESERVED across generations so a
    /// session change can never cancel an in-flight reload or start an
    /// overlapping one. ``reloadWorkerRunning`` tracks whether the single
    /// serial worker is alive; ``pendingReloadGeneration`` is the session
    /// under which the most recent reload was requested.
    private var reloadWorkerRunning = false
    private var pendingReloadGeneration: UInt64?
    private var reloadWorkerTask: Task<Void, Never>?

    /// Begin a new observation session over the supplied slots plus the
    /// connection stream. Stops any prior session first and returns the new
    /// session token to pass back to ``stop(session:)``. The `reload`
    /// closure should weakly capture its owner.
    @discardableResult
    func start(
        slots: [AnyPublisher<Void, Never>],
        connection: AnyPublisher<WebSocketManager.ConnectionState, Never>,
        reload: @escaping @MainActor () async -> Void
    ) -> UInt64 {
        stop()
        generation &+= 1
        let gen = generation
        self.slots = slots
        self.connection = connection
        self.reload = reload

        for index in slots.indices {
            observationTasks.append(Task { @MainActor [weak self] in
                guard let publisher = self?.slotPublisher(at: index) else { return }
                var isFirstValue = true
                for await _ in publisher.values {
                    if Task.isCancelled { return }
                    guard self?.isCurrentGeneration(gen) == true else { return }
                    if isFirstValue {
                        isFirstValue = false
                        continue
                    }
                    self?.scheduleDebouncedReload(generation: gen)
                }
            })
        }

        observationTasks.append(Task { @MainActor [weak self] in
            guard let publisher = self?.connectionPublisher() else { return }
            var isFirstValue = true
            var previousConnected = false
            for await newState in publisher.values {
                if Task.isCancelled { return }
                guard self?.isCurrentGeneration(gen) == true else { return }
                let nowConnected = Self.isConnected(newState)
                if isFirstValue {
                    isFirstValue = false
                    previousConnected = nowConnected
                    continue
                }
                if nowConnected && !previousConnected {
                    self?.scheduleDebouncedReload(generation: gen)
                }
                previousConnected = nowConnected
            }
        })

        scheduleDebouncedReload(generation: gen)
        return gen
    }

    /// Stop the observation.
    ///
    /// Cancels every observation task and any pending debounced reload, and
    /// bumps the session generation. The serialization state
    /// (``reloadWorkerRunning`` / ``pendingReloadGeneration`` /
    /// ``reloadWorkerTask``) is intentionally left intact: the worker
    /// checks the generation immediately before each reload, so a stopped
    /// session's queued or in-flight follow-up is dropped without
    /// cancelling an in-flight request or overlapping a new one. When
    /// `token` is supplied, the call is a no-op unless the token is the
    /// current session, so a stale view-task teardown cannot stop a newer
    /// session.
    func stop(session token: UInt64? = nil) {
        if let token, token != generation { return }
        generation &+= 1
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        pendingDebounceTask?.cancel()
        pendingDebounceTask = nil
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
        pendingDebounceTask?.cancel()
        reloadWorkerTask?.cancel()
    }

    private func isCurrentGeneration(_ gen: UInt64) -> Bool {
        return generation == gen
    }

    private func slotPublisher(at index: Int) -> AnyPublisher<Void, Never>? {
        guard slots.indices.contains(index) else { return nil }
        return slots[index]
    }

    private func connectionPublisher() -> AnyPublisher<WebSocketManager.ConnectionState, Never>? {
        return connection
    }

    /// (Re)arm the debounce sleep only — never touches an active reload.
    private func scheduleDebouncedReload(generation gen: UInt64) {
        guard generation == gen else { return }
        pendingDebounceTask?.cancel()
        pendingDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanos)
            guard !Task.isCancelled, self?.isCurrentGeneration(gen) == true else { return }
            self?.requestReload(generation: gen)
        }
    }

    /// Queue a reload for `gen` and ensure the single serial worker runs.
    /// If the worker is already active (possibly draining a superseded
    /// session's in-flight reload), the request simply queues.
    private func requestReload(generation gen: UInt64) {
        pendingReloadGeneration = gen
        guard !reloadWorkerRunning else { return }
        reloadWorkerRunning = true
        reloadWorkerTask = Task { @MainActor [weak self] in
            await self?.runReloadWorker()
        }
    }

    /// Serial reload worker. Drains queued reload requests one at a time,
    /// rechecking the session generation immediately before every reload so
    /// a superseded request is dropped, never run. An in-flight reload is
    /// awaited to completion — never cancelled — so a later pulse cannot
    /// abort a request, and a new session's request cannot overlap it.
    private func runReloadWorker() async {
        while let requestedGeneration = pendingReloadGeneration {
            pendingReloadGeneration = nil
            guard requestedGeneration == generation else { continue }
            let reload = self.reload
            await reload?()
        }
        reloadWorkerRunning = false
        reloadWorkerTask = nil
    }
}
