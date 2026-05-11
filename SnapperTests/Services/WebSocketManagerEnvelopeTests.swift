import XCTest
@testable import Snapper

@MainActor
final class WebSocketManagerEnvelopeTests: XCTestCase {

    private func makeManager() -> (WebSocketManager, FakeWebSocketTask) {
        let fakeTask = FakeWebSocketTask()
        let factory = FakeWebSocketTaskFactory(task: fakeTask)
        let manager = WebSocketManager(
            authService: FakeAuthService(nextToken: "test-token"),
            taskFactory: factory,
            sleeper: FakeSleeper()
        )
        return (manager, fakeTask)
    }

    private func authCompleteFrame(sessionId: String) -> URLSessionWebSocketTask.Message {
        let json: [String: Any] = [
            "type": "auth_complete",
            "sequence_id": 1,
            "public_id": "01961234-5678-7000-8000-000000000ENV",
            "timestamp": "2099-01-01T10:00:00Z",
            "session_id": sessionId,
            "available_topics": [],
            "user_role": "viewer",
            "ws_token_exp": "2099-01-01T11:00:00Z"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return .string(String(data: data, encoding: .utf8)!)
    }

    /// `sendJSON` bounces through a detached `Task { try await task.send(...) }`,
    /// so outbound frames land in `sentMessages` only after the cooperative
    /// scheduler runs each task to completion. A fixed yield count is racey
    /// under CI load (observed on macOS-runner when two envelopes are minted
    /// back-to-back), so this drain polls the expected count with a generous
    /// upper bound on yields. Any test that calls this must pass the *total*
    /// number of frames it expects to have been sent up to this point.
    ///
    /// Reads ``FakeWebSocketTask.sentMessagesCount`` (lock-serialized)
    /// rather than the underlying ``sentMessages`` array — ``send(_:)``
    /// appends to that storage under the same lock from a detached task,
    /// so an unlocked count read would be a TSan data race.
    ///
    /// On exhaustion ``XCTFail`` is raised with the observed/expected
    /// counts so a real regression surfaces with a precise diagnostic
    /// here, instead of cascading into a less-informative ``XCTAssertNotNil``
    /// downstream.
    private func waitForFrames(
        _ fakeTask: FakeWebSocketTask,
        count: Int,
        iterations: Int = 200,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<iterations {
            await Task.yield()
            if fakeTask.sentMessagesCount >= count { return }
        }
        /// Capture the count ONCE here so the diagnostic message reflects
        /// the state the loop saw. A late-arriving ``send`` task could land
        /// between the loop's last check and this read; if it bumps the
        /// count to ``>= count`` we treat that as a successful (slow)
        /// drain rather than a misleading "expected N, observed N" failure.
        let observed = fakeTask.sentMessagesCount
        if observed >= count { return }
        XCTFail(
            "waitForFrames timed out: expected \(count) frames, observed \(observed) after \(iterations) yields",
            file: file,
            line: line
        )
    }

    private func decodeFrame(_ message: URLSessionWebSocketTask.Message) -> [String: Any]? {
        guard case let .string(text) = message,
              let data = text.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return parsed
    }

    private func assertProvenance(
        _ frame: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(frame["public_id"] as? String, "public_id missing", file: file, line: line)
        XCTAssertNotNil(frame["session_id"] as? String, "session_id missing", file: file, line: line)
        XCTAssertNotNil(frame["sequence_id"] as? Int ?? (frame["sequence_id"] as? NSNumber)?.intValue,
                        "sequence_id missing", file: file, line: line)
        XCTAssertNotNil(frame["timestamp"] as? String, "timestamp missing", file: file, line: line)

        if let timestamp = frame["timestamp"] as? String {
            let parser = ISO8601DateFormatter()
            parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            XCTAssertNotNil(
                parser.date(from: timestamp),
                "timestamp \(timestamp) is not millisecond ISO 8601",
                file: file,
                line: line
            )
        }
    }

    func testSubscribeFrameCarriesEnvelopeProvenance() async {
        let (manager, fakeTask) = makeManager()
        manager.connect()
        manager.handleRawMessage(authCompleteFrame(sessionId: "s-sub"))
        manager.subscribe(topics: ["orders.events.kraken."])
        await waitForFrames(fakeTask, count: 1)

        let subscribeFrame = fakeTask.sentMessagesSnapshot().compactMap(decodeFrame).first { ($0["type"] as? String) == "subscribe" }
        XCTAssertNotNil(subscribeFrame, "subscribe frame not found in outbound queue")
        guard let frame = subscribeFrame else { return }
        XCTAssertEqual(frame["topics"] as? [String], ["orders.events.kraken."])
        assertProvenance(frame)
    }

    func testUnsubscribeFrameCarriesEnvelopeProvenance() async {
        let (manager, fakeTask) = makeManager()
        manager.connect()
        manager.handleRawMessage(authCompleteFrame(sessionId: "s-unsub"))
        manager.subscribe(topics: ["orders.events.kraken."])
        await waitForFrames(fakeTask, count: 1)
        manager.unsubscribe(topics: ["orders.events.kraken."])
        await waitForFrames(fakeTask, count: 2)

        let unsubscribeFrame = fakeTask.sentMessagesSnapshot().compactMap(decodeFrame).first { ($0["type"] as? String) == "unsubscribe" }
        XCTAssertNotNil(unsubscribeFrame, "unsubscribe frame not found in outbound queue")
        guard let frame = unsubscribeFrame else { return }
        XCTAssertEqual(frame["topics"] as? [String], ["orders.events.kraken."])
        assertProvenance(frame)
    }

    /// `authenticate`/`reauth` frames are minted by the same
    /// `sendEnvelope(_, counter: .control)` path that `subscribe`
    /// uses (verified by code review of
    /// ``WebSocketManager.performAuthentication`` and
    /// ``performReauthentication``). Drive the helper directly so
    /// the test does not need to spin up the full auth state
    /// machine via inbound `auth_required` pumps.
    func testAuthenticateFrameStampsProvenanceViaSendEnvelope() async {
        let (manager, fakeTask) = makeManager()
        manager.connect()
        manager.sendEnvelope(["type": "authenticate", "ws_token": "test-token"], counter: .control)
        manager.sendEnvelope(["type": "reauth", "ws_token": "renewed-token"], counter: .control)
        await waitForFrames(fakeTask, count: 2)

        let frames = fakeTask.sentMessagesSnapshot().compactMap(decodeFrame)
        let authFrame = frames.first { ($0["type"] as? String) == "authenticate" }
        let reauthFrame = frames.first { ($0["type"] as? String) == "reauth" }

        XCTAssertNotNil(authFrame)
        XCTAssertNotNil(reauthFrame)
        if let authFrame {
            XCTAssertEqual(authFrame["ws_token"] as? String, "test-token")
            assertProvenance(authFrame)
        }
        if let reauthFrame {
            XCTAssertEqual(reauthFrame["ws_token"] as? String, "renewed-token")
            assertProvenance(reauthFrame)
        }
    }

    /// Ping uses the telemetry counter — control-vs-telemetry counter
    /// independence itself is unit-tested at the minter level
    /// (``EnvelopeMinterTests.testControlAndTelemetryCountersAreIndependent``).
    /// Here we just confirm that pings reach the wire as a stamped
    /// envelope frame.
    func testPingFrameCarriesEnvelopeProvenance() async {
        let (manager, fakeTask) = makeManager()
        manager.connect()
        manager.handleRawMessage(authCompleteFrame(sessionId: "s-ping"))
        manager.sendEnvelope(["type": "ping"], counter: .telemetry)
        await waitForFrames(fakeTask, count: 1)

        let pingFrame = fakeTask.sentMessagesSnapshot().compactMap(decodeFrame).first { ($0["type"] as? String) == "ping" }
        XCTAssertNotNil(pingFrame, "ping frame not found in outbound queue")
        guard let frame = pingFrame else { return }
        assertProvenance(frame)
    }
}
