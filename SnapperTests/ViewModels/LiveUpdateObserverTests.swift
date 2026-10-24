import Combine
import Synchronization
import XCTest
@testable import Snapper

/// Behavioural + lifecycle coverage for ``LiveUpdateObserver``: debounced
/// coalescing, connection-heal dedup, the startup reconciliation that
/// closes the load→subscribe window, buffered-value-after-stop safety,
/// non-cancelling reload serialization, and deallocation cleanup.
///
/// The observer fires exactly one startup reconciliation reload once every
/// loop has subscribed (closing the A3 window), so tests that isolate a
/// later event first drain that reconciliation and assert a delta.
@MainActor
final class LiveUpdateObserverTests: XCTestCase {

    private func signalSlots(_ state: WSState) -> [AnyPublisher<Void, Never>] {
        return [LiveUpdateObserver.pulse(state.$lastSignalAt)]
    }

    private func twoSlots(_ state: WSState) -> [AnyPublisher<Void, Never>] {
        return [
            LiveUpdateObserver.pulse(state.$lastSignalAt),
            LiveUpdateObserver.pulse(state.$lastAiReviewActivityAt),
        ]
    }

    private func disconnected() -> CurrentValueSubject<WebSocketManager.ConnectionState, Never> {
        return CurrentValueSubject<WebSocketManager.ConnectionState, Never>(.disconnected)
    }

    /// Each subscription must consume its replay and request the next value before it is ready.
    /// A cancelled prior loop can subscribe late, but exits before making that second request.
    private nonisolated func readyPublisher<Output>(
        _ publisher: AnyPublisher<Output, Never>,
        ready: XCTestExpectation
    ) -> AnyPublisher<Output, Never> {
        return ReadyPublisher(upstream: publisher, ready: ready).eraseToAnyPublisher()
    }

    func testBurstOnSingleSlotCoalescesToOneReload() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()

        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        try await Task.sleep(nanoseconds: 100_000_000)
        for _ in 0..<5 {
            state.lastSignalAt = Date()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 1, "startup reconciliation + burst coalesce to one reload")
        observer.stop()
    }

    func testPulsesAcrossMultipleSlotsCoalesce() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()

        observer.start(slots: twoSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        try await Task.sleep(nanoseconds: 100_000_000)
        state.lastSignalAt = Date()
        try await Task.sleep(nanoseconds: 10_000_000)
        state.lastAiReviewActivityAt = Date()
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 1, "pulses on distinct slots coalesce with reconciliation to one reload")
        observer.stop()
    }

    func testConnectedTransitionTriggersReload() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()

        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        try await Task.sleep(nanoseconds: 500_000_000)
        let baseline = await counter.value

        connection.send(.connected)
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, baseline + 1, "a real transition into .connected heals with one reload")
        observer.stop()
    }

    func testDuplicateConnectedFiresReloadOnce() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()

        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        try await Task.sleep(nanoseconds: 500_000_000)
        let baseline = await counter.value

        connection.send(.connected)
        connection.send(.connected)
        connection.send(.connected)
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, baseline + 1, "repeated .connected emissions must heal only once")
        observer.stop()
    }

    func testNonConnectedTransitionsDoNotReload() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()

        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        try await Task.sleep(nanoseconds: 500_000_000)
        let baseline = await counter.value

        connection.send(.connecting)
        connection.send(.authenticating)
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, baseline, "interim connection states must not heal")
        observer.stop()
    }

    func testStopCancelsPendingReload() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()

        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        try await Task.sleep(nanoseconds: 100_000_000)
        state.lastSignalAt = Date()
        try await Task.sleep(nanoseconds: 50_000_000)
        observer.stop()
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "stop must cancel the pending reconciliation and pulse reload")
    }

    func testStartIsIdempotentNoDoubleObservers() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()

        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        try await Task.sleep(nanoseconds: 100_000_000)
        for _ in 0..<5 {
            state.lastSignalAt = Date()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 1, "restart must not leave a doubled observer behind")
        observer.stop()
    }

    /// A3: a change landing in the load→subscribe window (mutated
    /// synchronously right after ``start`` returns, before the loops
    /// subscribe) is discarded by the initial drop — but the startup
    /// reconciliation reload covers it, so the update is never lost.
    func testStartupGapChangeIsReconciled() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()

        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        state.lastSignalAt = Date()
        try await Task.sleep(nanoseconds: 600_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 1, "a pre-subscription change is reconciled by exactly one reload")
        observer.stop()
    }

    /// A2: a value buffered into an async continuation before ``stop`` must
    /// not schedule a reload after the observation is cancelled.
    func testBufferedValueAfterStopDoesNotReload() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()

        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        try await Task.sleep(nanoseconds: 500_000_000)
        let baseline = await counter.value

        state.lastSignalAt = Date()
        observer.stop()
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, baseline, "a value buffered before stop must not reload afterwards")
    }

    /// A4: an in-flight reload is never cancelled by a later pulse; exactly
    /// one follow-up reload runs after the active one completes.
    func testSlowReloadNotCancelledAndRunsOneFollowup() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let gate = GatedReload()

        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await gate.run() })
        try await Task.sleep(nanoseconds: 500_000_000)
        let startedBefore = await gate.starts()
        let gatedBefore = await gate.isGated()
        XCTAssertEqual(startedBefore, 1, "the startup reconciliation reload is in flight")
        XCTAssertTrue(gatedBefore, "the reconciliation reload is gated (still running)")

        state.lastSignalAt = Date()
        try await Task.sleep(nanoseconds: 400_000_000)
        let startedDuring = await gate.starts()
        let gatedDuring = await gate.isGated()
        XCTAssertEqual(startedDuring, 1, "a pulse must not start a second reload while one is active")
        XCTAssertTrue(gatedDuring, "the active reload must not be cancelled by a later pulse")

        await gate.release()
        try await Task.sleep(nanoseconds: 400_000_000)
        let startedAfter = await gate.starts()
        let finishedAfter = await gate.finishes()
        XCTAssertEqual(startedAfter, 2, "exactly one follow-up reload runs after completion")
        XCTAssertEqual(finishedAfter, 2, "both reloads run to completion — none cancelled")
        observer.stop()
    }

    /// R3: releasing the observer without calling ``stop`` cancels its
    /// observation; a later slot change fires nothing.
    func testDeallocWithoutStopFiresNoReload() async throws {
        var observer: LiveUpdateObserver? = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()

        observer?.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                        reload: { await counter.increment() })
        try await Task.sleep(nanoseconds: 100_000_000)
        observer = nil
        try await Task.sleep(nanoseconds: 100_000_000)
        state.lastSignalAt = Date()
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "a deallocated observer must not reload")
    }

    /// A1: a stale session's stop is a no-op — a superseded token cannot
    /// tear down the current session's observation.
    func testStaleSessionStopIsNoOp() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        let connection = disconnected()
        let counter = ReloadCounter()
        let slotReady = expectation(description: "Current slot awaits a value after its initial replay")
        let connectionReady = expectation(description: "Current connection awaits its next value")
        let startupReload = expectation(description: "Current startup reconciliation completed")
        let pulseReload = expectation(description: "Current session reloaded after the signal pulse")

        let staleToken = observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                                        reload: { await counter.increment() })
        let currentToken = observer.start(
            slots: [readyPublisher(LiveUpdateObserver.pulse(state.$lastSignalAt), ready: slotReady)],
            connection: readyPublisher(connection.eraseToAnyPublisher(), ready: connectionReady),
            reload: {
                await counter.increment()
                let count = await counter.value
                if count == 1 { startupReload.fulfill() }
                if count == 2 { pulseReload.fulfill() }
            }
        )
        defer { observer.stop(session: currentToken) }
        XCTAssertNotEqual(staleToken, currentToken)
        let readiness = await XCTWaiter.fulfillment(
            of: [slotReady, connectionReady, startupReload], timeout: 1.0
        )
        XCTAssertEqual(readiness, .completed, "both current subscriptions must consume their replay")
        let baseline = await counter.value
        XCTAssertEqual(baseline, 1, "the current startup reconciliation must complete once")

        observer.stop(session: staleToken)
        state.lastSignalAt = Date()
        let pulse = await XCTWaiter.fulfillment(of: [pulseReload], timeout: 1.0)
        XCTAssertEqual(pulse, .completed, "the current session must receive and reload the actual pulse")

        let count = await counter.value
        XCTAssertEqual(count, baseline + 1, "a stale-token stop must preserve the current pulse reload")
    }

    /// CRITICAL round-2: session B's reload must not overlap session A's
    /// in-flight reload. With A's reload gated open, starting B queues B's
    /// reload behind A; releasing A lets exactly B's reload run next, under
    /// B's session — and A's completion never re-fires under B.
    func testCrossSessionReloadDoesNotOverlap() async throws {
        let observer = LiveUpdateObserver()
        let stateA = WSState()
        let stateB = WSState()
        let connectionA = disconnected()
        let connectionB = disconnected()
        let gateA = GatedReload()
        let gateB = GatedReload()

        observer.start(slots: signalSlots(stateA), connection: connectionA.eraseToAnyPublisher(),
                       reload: { await gateA.run() })
        try await Task.sleep(nanoseconds: 500_000_000)
        let aStarted = await gateA.starts()
        let aGated = await gateA.isGated()
        XCTAssertEqual(aStarted, 1, "session A's reconciliation reload is in flight")
        XCTAssertTrue(aGated, "session A's reload is gated open")

        observer.start(slots: signalSlots(stateB), connection: connectionB.eraseToAnyPublisher(),
                       reload: { await gateB.run() })
        try await Task.sleep(nanoseconds: 500_000_000)
        let bStartedDuringA = await gateB.starts()
        let aStillOne = await gateA.starts()
        XCTAssertEqual(bStartedDuringA, 0, "session B's reload must not overlap A's in-flight reload")
        XCTAssertEqual(aStillOne, 1, "session A's reload is still the only one running")

        await gateA.release()
        try await Task.sleep(nanoseconds: 500_000_000)
        let aFinal = await gateA.starts()
        let aFinished = await gateA.finishes()
        let bAfterRelease = await gateB.starts()
        XCTAssertEqual(aFinal, 1, "session A's reload does not re-fire under session B")
        XCTAssertEqual(aFinished, 1, "session A's reload completed exactly once")
        XCTAssertEqual(bAfterRelease, 1, "session B's reload runs serially after A completes")

        observer.stop()
        await gateB.release()
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    /// R-A1: a replaying source's initial (current) value is dropped, so it
    /// does not fire a reload of its own — only the source-agnostic startup
    /// reconciliation reloads once. Documents and asserts the replay
    /// contract the observation loops rely on.
    func testReplayingSourceInitialValueIsDropped() async throws {
        let observer = LiveUpdateObserver()
        let state = WSState()
        state.lastSignalAt = Date()
        let connection = CurrentValueSubject<WebSocketManager.ConnectionState, Never>(.connected)
        let counter = ReloadCounter()

        observer.start(slots: signalSlots(state), connection: connection.eraseToAnyPublisher(),
                       reload: { await counter.increment() })
        try await Task.sleep(nanoseconds: 600_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 1, "replayed initial slot/connection values are dropped; only reconciliation reloads")
        observer.stop()
    }
}

/// Wrap each genuine subscription without replacing its replay, events or completion.
private struct ReadyPublisher<Upstream: Publisher>: Publisher {
    typealias Output = Upstream.Output
    typealias Failure = Upstream.Failure

    let upstream: Upstream
    let ready: XCTestExpectation

    func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Output, Downstream.Failure == Failure {
        upstream.receive(subscriber: ReadySubscriber(downstream: subscriber, ready: ready))
    }
}

/// Forward the actual source unchanged while installing a per-subscription demand witness.
private final class ReadySubscriber<Downstream: Subscriber>: Subscriber {
    typealias Input = Downstream.Input
    typealias Failure = Downstream.Failure

    private let downstream: Downstream
    private let ready: XCTestExpectation

    init(downstream: Downstream, ready: XCTestExpectation) {
        self.downstream = downstream
        self.ready = ready
    }

    func receive(subscription: Subscription) {
        downstream.receive(subscription: ReadySubscription(upstream: subscription, ready: ready))
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        return downstream.receive(input)
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        downstream.receive(completion: completion)
    }
}

/// Publish readiness only after the actual upstream request has completed forwarding.
private final class ReadySubscription: Subscription {
    private let upstream: Subscription
    private let ready: XCTestExpectation
    private let count = Mutex(0)

    init(upstream: Subscription, ready: XCTestExpectation) {
        self.upstream = upstream
        self.ready = ready
    }

    func request(_ demand: Subscribers.Demand) {
        upstream.request(demand)
        guard demand > .none else { return }
        let isReady = count.withLock { value in
            value += 1
            return value == 2
        }
        if isReady { ready.fulfill() }
    }

    func cancel() {
        upstream.cancel()
    }
}

private actor ReloadCounter {
    var value: Int = 0
    func increment() { value += 1 }
}

/// Reload driver whose FIRST invocation blocks on a continuation the test
/// releases, so the test can hold a reload "in flight" and prove later
/// pulses neither cancel it nor start a concurrent reload.
private actor GatedReload {
    private var startCount = 0
    private var finishCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func run() async {
        startCount += 1
        if startCount == 1 {
            await withCheckedContinuation { continuation = $0 }
        }
        finishCount += 1
    }

    func starts() -> Int { startCount }
    func finishes() -> Int { finishCount }
    func isGated() -> Bool { continuation != nil }
    func release() {
        continuation?.resume()
        continuation = nil
    }
}
