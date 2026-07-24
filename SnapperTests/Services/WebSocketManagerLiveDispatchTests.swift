import XCTest
@testable import Snapper

/// Dispatcher coverage for the shared live-update layer: the frame types
/// added for Signals, Processes, Strategies, and AI Reviews, plus the
/// per-component heartbeat map. Each new ``dispatchTypedFrame`` arm must
/// land its typed payload (or pulse) in the correct ``WSState`` slot, and
/// a malformed payload of a known type must neither crash nor mutate.
@MainActor
final class WebSocketManagerLiveDispatchTests: XCTestCase {

    private func makeManager() -> WebSocketManager {
        return WebSocketManager(
            authService: FakeAuthService(nextToken: "t"),
            taskFactory: FakeWebSocketTaskFactory(task: FakeWebSocketTask()),
            sleeper: FakeSleeper()
        )
    }

    private func frame(_ json: [String: Any]) -> URLSessionWebSocketTask.Message {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return .string(String(data: data, encoding: .utf8)!)
    }

    private func envelope(type: String, extra: [String: Any]) -> [String: Any] {
        var json: [String: Any] = [
            "type": type,
            "sequence_id": 1,
            "public_id": "01961234-5678-7000-8000-000000000099",
            "timestamp": "2025-11-22T10:00:00Z",
            "session_id": "session-live",
            "topic": "live.updates.test",
        ]
        for (key, value) in extra {
            json[key] = value
        }
        return json
    }

    private func signalExtra() -> [String: Any] {
        return [
            "instrument": "BTC-USD",
            "exchange": "kraken",
            "side": "buy",
            "strength": 0.82,
            "reason": "momentum breakout",
            "fired_at": "2025-11-22T10:00:00Z",
        ]
    }

    func testSignalFramePulsesLastSignalAt() {
        let manager = makeManager()
        XCTAssertNil(manager.state.lastSignalAt)

        manager.handleRawMessage(frame(envelope(type: "signal", extra: signalExtra())))

        XCTAssertNotNil(manager.state.lastSignalAt)
    }

    func testMalformedSignalFrameDoesNotPulse() {
        let manager = makeManager()

        manager.handleRawMessage(frame(envelope(type: "signal", extra: [
            "instrument": "BTC-USD",
            "exchange": "kraken",
        ])))

        XCTAssertNil(manager.state.lastSignalAt, "a signal frame that fails SignalData decode must not pulse")
    }

    func testProcessSummaryEventDispatchedToSlot() {
        let manager = makeManager()

        manager.handleRawMessage(frame(envelope(type: "process_summary_event", extra: [
            "coordinator": "supervisor",
            "processes": [[
                "name": "feed_kraken",
                "running": true,
                "enabled": true,
                "role": "feed",
                "lifecycle": "process",
            ]],
            "snapshot_at": "2025-11-22T10:00:00Z",
        ])))

        XCTAssertEqual(manager.state.lastProcessSummary?.coordinator, "supervisor")
        XCTAssertEqual(manager.state.lastProcessSummary?.processes.first?.name, "feed_kraken")
    }

    func testProcessConfiguredEventDispatchedToSlot() {
        let manager = makeManager()

        manager.handleRawMessage(frame(envelope(type: "process_configured_event", extra: [
            "process_names": ["strategy_macd", "feed_kraken"],
            "snapshot_at": "2025-11-22T10:00:00Z",
        ])))

        XCTAssertEqual(manager.state.lastProcessConfigured?.processNames, ["strategy_macd", "feed_kraken"])
    }

    func testProcessRunEventDispatchedToSlot() {
        let manager = makeManager()

        manager.handleRawMessage(frame(envelope(type: "process_run_event", extra: [
            "process_name": "strategy_macd",
            "run_id": "run-1",
            "status": "running",
            "started_at": "2025-11-22T10:00:00Z",
        ])))

        XCTAssertEqual(manager.state.lastProcessRun?.processName, "strategy_macd")
        XCTAssertEqual(manager.state.lastProcessRun?.runId, "run-1")
    }

    func testStrategyListEventDispatchedToSlot() {
        let manager = makeManager()

        manager.handleRawMessage(frame(envelope(type: "strategy_list_event", extra: [
            "strategy_classes": ["MacdStrategy", "RsiStrategy"],
            "snapshot_at": "2025-11-22T10:00:00Z",
        ])))

        XCTAssertEqual(manager.state.lastStrategyList?.strategyClasses, ["MacdStrategy", "RsiStrategy"])
    }

    func testAiReviewRequestFramePulsesActivity() {
        let manager = makeManager()
        XCTAssertNil(manager.state.lastAiReviewActivityAt)

        manager.handleRawMessage(frame(envelope(type: "ai_review.request", extra: [
            "review_public_id": "rev-1",
            "user_public_id": "user-1",
            "strategy_public_id": "strat-1",
            "wallet_public_id": "wallet-1",
            "instrument_public_id": "inst-1",
            "selected_delegate_public_id": "del-1",
            "deadline": "2025-11-22T10:05:00Z",
            "signal_envelope": ["source": "macd"],
            "instrument_metadata": ["tick": "0.01"],
            "dispatch_version": 3,
        ])))

        XCTAssertNotNil(manager.state.lastAiReviewActivityAt)
    }

    func testAiReviewDecisionAckFramePulsesActivity() {
        let manager = makeManager()

        manager.handleRawMessage(frame(envelope(type: "ai_review.decision_ack", extra: [
            "review_public_id": "rev-1",
            "user_public_id": "user-1",
            "strategy_public_id": "strat-1",
            "wallet_public_id": "wallet-1",
            "instrument_public_id": "inst-1",
            "responding_delegate_public_id": "del-1",
            "decision": "approve",
            "new_status": "approved",
            "resolution_mode": "manual",
            "dispatch_version": 3,
        ])))

        XCTAssertNotNil(manager.state.lastAiReviewActivityAt)
    }

    func testAiReviewCapsViolationFramePulsesActivity() {
        let manager = makeManager()

        manager.handleRawMessage(frame(envelope(type: "ai_review.caps_violation", extra: [
            "review_public_id": "rev-1",
            "user_public_id": "user-1",
            "strategy_public_id": "strat-1",
            "wallet_public_id": "wallet-1",
            "instrument_public_id": "inst-1",
            "cap_type": "daily_notional",
            "attempted": 1200.0,
            "limit": 1000.0,
            "dispatch_version": 3,
        ])))

        XCTAssertNotNil(manager.state.lastAiReviewActivityAt)
    }

    func testUnknownFrameTypeStillIgnored() {
        let manager = makeManager()

        manager.handleRawMessage(frame(envelope(type: "totally_unbound_type", extra: ["value": 1])))

        XCTAssertNil(manager.state.lastProcessSummary)
        XCTAssertNil(manager.state.lastProcessConfigured)
        XCTAssertNil(manager.state.lastProcessRun)
        XCTAssertNil(manager.state.lastStrategyList)
        XCTAssertNil(manager.state.lastSignalAt)
        XCTAssertNil(manager.state.lastAiReviewActivityAt)
    }

    func testMalformedKnownTypesDoNotCrashOrMutate() {
        let manager = makeManager()

        manager.handleRawMessage(frame(["type": "signal"]))
        manager.handleRawMessage(frame(["type": "process_summary_event"]))
        manager.handleRawMessage(frame(["type": "process_configured_event"]))
        manager.handleRawMessage(frame(["type": "process_run_event"]))
        manager.handleRawMessage(frame(["type": "strategy_list_event"]))
        manager.handleRawMessage(frame(["type": "ai_review.request"]))
        manager.handleRawMessage(frame(["type": "ai_review.decision_ack"]))
        manager.handleRawMessage(frame(["type": "ai_review.caps_violation"]))

        XCTAssertNil(manager.state.lastSignalAt)
        XCTAssertNil(manager.state.lastProcessSummary)
        XCTAssertNil(manager.state.lastProcessConfigured)
        XCTAssertNil(manager.state.lastProcessRun)
        XCTAssertNil(manager.state.lastStrategyList)
        XCTAssertNil(manager.state.lastAiReviewActivityAt)
    }

    /// R5: a near-miss type resembling a subscribed one (`ai_research.request`
    /// vs `ai_review.request`) must fall through to the default arm and
    /// mutate nothing.
    func testNonSubscribedNearMissTypeIgnored() {
        let manager = makeManager()

        manager.handleRawMessage(frame(envelope(type: "ai_research.request", extra: ["value": 1])))

        XCTAssertNil(manager.state.lastAiReviewActivityAt)
        XCTAssertNil(manager.state.lastSignalAt)
        XCTAssertNil(manager.state.lastProcessSummary)
    }

    /// R6: seeding every slot with a valid frame, then pumping a malformed
    /// frame of each known type, must leave every seeded value, pulse
    /// timestamp, and heartbeat entry UNCHANGED — not merely nil.
    func testMalformedFramesPreserveSeededState() {
        let manager = makeManager()

        manager.handleRawMessage(frame(envelope(type: "signal", extra: signalExtra())))
        manager.handleRawMessage(frame(envelope(type: "process_summary_event", extra: [
            "processes": [[
                "name": "feed_kraken", "running": true, "enabled": true,
                "role": "feed", "lifecycle": "process",
            ]],
            "snapshot_at": "2025-11-22T10:00:00Z",
        ])))
        manager.handleRawMessage(frame(envelope(type: "process_configured_event", extra: [
            "process_names": ["strategy_macd"], "snapshot_at": "2025-11-22T10:00:00Z",
        ])))
        manager.handleRawMessage(frame(envelope(type: "process_run_event", extra: [
            "process_name": "strategy_macd", "run_id": "run-9", "status": "running",
            "started_at": "2025-11-22T10:00:00Z",
        ])))
        manager.handleRawMessage(frame(envelope(type: "strategy_list_event", extra: [
            "strategy_classes": ["MacdStrategy"], "snapshot_at": "2025-11-22T10:00:00Z",
        ])))
        manager.handleRawMessage(frame(envelope(type: "ai_review.request", extra: [
            "review_public_id": "rev-1", "user_public_id": "user-1", "strategy_public_id": "strat-1",
            "wallet_public_id": "wallet-1", "instrument_public_id": "inst-1",
            "selected_delegate_public_id": "del-1", "deadline": "2025-11-22T10:05:00Z",
            "signal_envelope": ["k": "v"], "instrument_metadata": ["k": "v"], "dispatch_version": 3,
        ])))
        manager.handleRawMessage(heartbeatFrame(component: "feed_kraken", lagMs: 5, sequence: 1))

        let signalAt = manager.state.lastSignalAt
        let summaryId = manager.state.lastProcessSummary?.processes.first?.name
        let configuredNames = manager.state.lastProcessConfigured?.processNames
        let runId = manager.state.lastProcessRun?.runId
        let strategyClasses = manager.state.lastStrategyList?.strategyClasses
        let aiReviewAt = manager.state.lastAiReviewActivityAt
        let heartbeatLag = manager.state.componentHeartbeats["feed_kraken"]?.lagMs
        let lastHeartbeatComponent = manager.state.lastHeartbeat?.component
        let lastHeartbeatLag = manager.state.lastHeartbeat?.lagMs
        let lastHeartbeatAt = manager.state.lastHeartbeatAt
        XCTAssertNotNil(signalAt)
        XCTAssertNotNil(aiReviewAt)
        XCTAssertNotNil(lastHeartbeatAt)

        manager.handleRawMessage(frame(["type": "signal"]))
        manager.handleRawMessage(frame(["type": "process_summary_event"]))
        manager.handleRawMessage(frame(["type": "process_configured_event"]))
        manager.handleRawMessage(frame(["type": "process_run_event"]))
        manager.handleRawMessage(frame(["type": "strategy_list_event"]))
        manager.handleRawMessage(frame(["type": "ai_review.request"]))
        manager.handleRawMessage(frame(["type": "ai_review.decision_ack"]))
        manager.handleRawMessage(frame(["type": "ai_review.caps_violation"]))
        manager.handleRawMessage(frame(["type": "heartbeat"]))

        XCTAssertEqual(manager.state.lastSignalAt, signalAt)
        XCTAssertEqual(manager.state.lastProcessSummary?.processes.first?.name, summaryId)
        XCTAssertEqual(manager.state.lastProcessConfigured?.processNames, configuredNames)
        XCTAssertEqual(manager.state.lastProcessRun?.runId, runId)
        XCTAssertEqual(manager.state.lastStrategyList?.strategyClasses, strategyClasses)
        XCTAssertEqual(manager.state.lastAiReviewActivityAt, aiReviewAt)
        XCTAssertEqual(manager.state.componentHeartbeats["feed_kraken"]?.lagMs, heartbeatLag)
        XCTAssertEqual(manager.state.componentHeartbeats.count, 1)
        XCTAssertEqual(manager.state.lastHeartbeat?.component, lastHeartbeatComponent)
        XCTAssertEqual(manager.state.lastHeartbeat?.lagMs, lastHeartbeatLag)
        XCTAssertEqual(manager.state.lastHeartbeatAt, lastHeartbeatAt)
    }

    private func heartbeatFrame(component: String, lagMs: Int, sequence: Int) -> URLSessionWebSocketTask.Message {
        return frame(envelope(type: "heartbeat", extra: [
            "component": component,
            "sequence": sequence,
            "status": "ok",
            "lag_ms": lagMs,
        ]))
    }

    func testComponentHeartbeatsKeyedByComponent() {
        let manager = makeManager()

        manager.handleRawMessage(heartbeatFrame(component: "feed_kraken", lagMs: 5, sequence: 1))
        manager.handleRawMessage(heartbeatFrame(component: "executor", lagMs: 9, sequence: 2))

        XCTAssertEqual(manager.state.componentHeartbeats["feed_kraken"]?.lagMs, 5)
        XCTAssertEqual(manager.state.componentHeartbeats["executor"]?.lagMs, 9)
        XCTAssertEqual(manager.state.componentHeartbeats.count, 2)
    }

    func testComponentHeartbeatOverwritesPerComponentAndKeepsLastHeartbeat() {
        let manager = makeManager()

        manager.handleRawMessage(heartbeatFrame(component: "feed_kraken", lagMs: 5, sequence: 1))
        manager.handleRawMessage(heartbeatFrame(component: "feed_kraken", lagMs: 12, sequence: 2))

        XCTAssertEqual(manager.state.componentHeartbeats["feed_kraken"]?.lagMs, 12)
        XCTAssertEqual(manager.state.componentHeartbeats.count, 1)
        XCTAssertEqual(manager.state.lastHeartbeat?.component, "feed_kraken")
        XCTAssertEqual(manager.state.lastHeartbeat?.lagMs, 12)
        XCTAssertNotNil(manager.state.lastHeartbeatAt)
    }

    func testMalformedHeartbeatLeavesComponentMapUntouched() {
        let manager = makeManager()

        manager.handleRawMessage(heartbeatFrame(component: "feed_kraken", lagMs: 5, sequence: 1))
        manager.handleRawMessage(frame(["type": "heartbeat"]))

        XCTAssertEqual(manager.state.componentHeartbeats.count, 1)
        XCTAssertEqual(manager.state.componentHeartbeats["feed_kraken"]?.lagMs, 5)
    }

    private static let allLiveRoots: Set<String> = [
        "system.heartbeats.", "orders.events.", "signals.", "ai_reviews.",
        "processes.events.summary.", "processes.events.configured.",
        "processes.events.runs.", "strategies.events.list.",
    ]

    private func makeManagerWithTask() -> (WebSocketManager, FakeWebSocketTask) {
        let fakeTask = FakeWebSocketTask()
        let manager = WebSocketManager(
            authService: FakeAuthService(nextToken: "t"),
            taskFactory: FakeWebSocketTaskFactory(task: fakeTask),
            sleeper: FakeSleeper()
        )
        return (manager, fakeTask)
    }

    private func authComplete(availableTopics: [String]) -> URLSessionWebSocketTask.Message {
        return frame([
            "type": "auth_complete",
            "sequence_id": 1,
            "public_id": "01961234-5678-7000-8000-0000000000aa",
            "timestamp": "2025-11-22T10:00:00Z",
            "session_id": "session-live",
            "available_topics": availableTopics,
            "user_role": "operator",
            "ws_token_exp": "2025-11-22T11:00:00Z",
        ])
    }

    private func decodeFrame(_ message: URLSessionWebSocketTask.Message) -> [String: Any]? {
        guard case let .string(text) = message,
              let data = text.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return parsed
    }

    private func drainSendTasks() async {
        for _ in 0..<10 { await Task.yield() }
    }

    private func subscribedTopics(_ fakeTask: FakeWebSocketTask) -> Set<String> {
        return Set(
            fakeTask.sentMessages
                .compactMap(decodeFrame)
                .filter { ($0["type"] as? String) == "subscribe" }
                .compactMap { $0["topics"] as? [String] }
                .flatMap { $0 }
        )
    }

    func testAuthCompleteOfferingAllRootsSubscribesExactSet() async {
        let (manager, fakeTask) = makeManagerWithTask()
        manager.connect()
        manager.handleRawMessage(authComplete(availableTopics: Array(Self.allLiveRoots)))
        await drainSendTasks()

        XCTAssertEqual(subscribedTopics(fakeTask), Self.allLiveRoots)
        XCTAssertFalse(subscribedTopics(fakeTask).contains("strategy."))
    }

    func testMixedCapabilityExcludesUnavailableRoots() async {
        let (manager, fakeTask) = makeManagerWithTask()
        let available = ["system.heartbeats.", "orders.events.", "signals."]
        manager.connect()
        manager.handleRawMessage(authComplete(availableTopics: available))
        await drainSendTasks()

        let subscribed = subscribedTopics(fakeTask)
        XCTAssertEqual(subscribed, Set(available))
        XCTAssertFalse(subscribed.contains("ai_reviews."))
        XCTAssertFalse(subscribed.contains("processes.events.summary."))
        XCTAssertFalse(subscribed.contains("processes.events.configured."))
        XCTAssertFalse(subscribed.contains("processes.events.runs."))
        XCTAssertFalse(subscribed.contains("strategies.events.list."))
        XCTAssertFalse(subscribed.contains("strategy."))
    }

    func testLegacyStrategyPrefixNeverSubscribedEvenWhenOffered() async {
        let (manager, fakeTask) = makeManagerWithTask()
        manager.connect()
        manager.handleRawMessage(authComplete(availableTopics: ["strategy.", "strategies.events.list."]))
        await drainSendTasks()

        let subscribed = subscribedTopics(fakeTask)
        XCTAssertTrue(subscribed.contains("strategies.events.list."))
        XCTAssertFalse(subscribed.contains("strategy."), "iOS must never subscribe the web's dead strategy. prefix")
    }
}
