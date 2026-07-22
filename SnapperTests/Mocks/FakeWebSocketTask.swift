import Foundation
@testable import Snapper

/// `@unchecked Sendable` + NSLock fake for `WebSocketTaskProtocol`.
///
/// Actor isolation is unworkable: the protocol's `cancel` and `resume`
/// are synchronous nonisolated requirements. Actor conformance would need
/// `nonisolated` wrappers that cannot safely touch isolated state.
/// NSLock-serialized mutable state is the honest pragmatic choice —
/// production `URLSessionWebSocketTask` has the same constraint.
///
/// Tests drive inbound frames by calling `pumpInbound(_:)`. A pending
/// `receive()` caller is parked on an async continuation and resumed
/// once a frame lands in the queue.
final class FakeWebSocketTask: @unchecked Sendable, WebSocketTaskProtocol {
    private let lock = NSLock()
    private let sendError: Error?
    private var inboundQueue: [URLSessionWebSocketTask.Message] = []
    private var waiter: CheckedContinuation<URLSessionWebSocketTask.Message, Error>?
    private var receivePendingWaiter: CheckedContinuation<Void, Never>?
    private var sentMessageWaiters: [SentMessageWaiter] = []
    private var nextSentMessageWaiterID: UInt64 = 0
    private(set) var sentMessages: [URLSessionWebSocketTask.Message] = []
    private(set) var resumeCount = 0
    private(set) var cancelCount = 0
    private(set) var lastCancelCode: URLSessionWebSocketTask.CloseCode?

    private struct SentMessageWaiter {
        let id: UInt64
        let predicate: @Sendable (URLSessionWebSocketTask.Message) -> Bool
        let continuation: CheckedContinuation<Bool, Never>
    }

    /// Lock-serialized read of ``sentMessages.count``. ``send(_:)``
    /// appends under ``lock`` from a detached ``Task``, so polling
    /// the underlying ``private(set)`` storage directly is a data race
    /// (compiler is silenced by ``@unchecked Sendable``, TSan is not).
    /// Tests that observe outbound frames while send tasks may still be
    /// appending must use this accessor.
    var sentMessagesCount: Int {
        lock.withLock { sentMessages.count }
    }

    /// Lock-serialized snapshot of ``sentMessages``. Returns a value-type
    /// copy taken under the lock so callers iterate a stable array even
    /// while a detached ``send`` task is still appending. Same rationale
    /// as ``sentMessagesCount``.
    func sentMessagesSnapshot() -> [URLSessionWebSocketTask.Message] {
        lock.withLock { sentMessages }
    }

    /// Resolves ``true`` once a sent message satisfying ``predicate`` has been
    /// captured (already-sent messages are checked first), or ``false`` if the
    /// timeout elapses. Waiting on the specific frame — rather than a raw count —
    /// is race-free even when unrelated frames (auth/reauth) share the outbound
    /// queue, so `count >= N` cannot be satisfied early by the wrong frame.
    func waitUntilSentMessage(
        where predicate: @escaping @Sendable (URLSessionWebSocketTask.Message) -> Bool,
        timeoutNanoseconds: UInt64 = 5_000_000_000
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let waiterID: UInt64? = lock.withLock {
                if sentMessages.contains(where: predicate) {
                    return nil
                }
                nextSentMessageWaiterID += 1
                let id = nextSentMessageWaiterID
                sentMessageWaiters.append(
                    SentMessageWaiter(
                        id: id,
                        predicate: predicate,
                        continuation: continuation
                    )
                )
                return id
            }

            guard let waiterID else {
                continuation.resume(returning: true)
                return
            }

            Task {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                let continuationToResume: CheckedContinuation<Bool, Never>? = self.lock.withLock {
                    guard let index = self.sentMessageWaiters.firstIndex(where: { $0.id == waiterID }) else {
                        return nil
                    }
                    return self.sentMessageWaiters.remove(at: index).continuation
                }
                continuationToResume?.resume(returning: false)
            }
        }
    }

    init(sendError: Error? = nil) {
        self.sendError = sendError
    }

    func pumpInbound(_ msg: URLSessionWebSocketTask.Message) {
        let resumed: CheckedContinuation<URLSessionWebSocketTask.Message, Error>? = lock.withLock {
            if let w = waiter {
                waiter = nil
                return w
            }
            inboundQueue.append(msg)
            return nil
        }
        resumed?.resume(returning: msg)
    }

    func pumpError(_ error: Error) {
        let resumed: CheckedContinuation<URLSessionWebSocketTask.Message, Error>? = lock.withLock {
            let w = waiter
            waiter = nil
            return w
        }
        resumed?.resume(throwing: error)
    }

    func waitUntilReceivePending() async {
        await withCheckedContinuation { continuation in
            let resumeImmediately = lock.withLock {
                if waiter != nil {
                    return true
                }
                precondition(receivePendingWaiter == nil, "FakeWebSocketTask only supports one pending receive waiter")
                receivePendingWaiter = continuation
                return false
            }
            if resumeImmediately {
                continuation.resume()
            }
        }
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        if let sendError {
            throw sendError
        }
        let waitersToResume: [CheckedContinuation<Bool, Never>] = lock.withLock {
            sentMessages.append(message)
            let satisfiedIDs = Set(sentMessageWaiters.filter { $0.predicate(message) }.map(\.id))
            let satisfied = sentMessageWaiters.filter { satisfiedIDs.contains($0.id) }
            sentMessageWaiters.removeAll { satisfiedIDs.contains($0.id) }
            return satisfied.map(\.continuation)
        }
        waitersToResume.forEach { $0.resume(returning: true) }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        return try await withCheckedThrowingContinuation { continuation in
            var receiveWaiterToResume: CheckedContinuation<Void, Never>?
            /// Single atomic critical section: either consume a queued
            /// message OR install the waiter. Splitting the lock would leave
            /// a gap where `pumpInbound` enqueues after our empty-check but
            /// before waiter install — the continuation would then hang
            /// forever even though a message is sitting in the queue.
            let immediate: URLSessionWebSocketTask.Message? = lock.withLock {
                if !inboundQueue.isEmpty {
                    return inboundQueue.removeFirst()
                }
                waiter = continuation
                receiveWaiterToResume = receivePendingWaiter
                receivePendingWaiter = nil
                return nil
            }
            receiveWaiterToResume?.resume()
            if let msg = immediate {
                continuation.resume(returning: msg)
            }
        }
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let resumed: CheckedContinuation<URLSessionWebSocketTask.Message, Error>? = lock.withLock {
            cancelCount += 1
            lastCancelCode = closeCode
            let w = waiter
            waiter = nil
            return w
        }
        resumed?.resume(throwing: CancellationError())
    }

    func resume() {
        lock.withLock { resumeCount += 1 }
    }
}
