import XCTest
@testable import Snapper

private struct ProcessesUnexpectedError: Error {}

@MainActor
final class ProcessesViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
        appState = AppState(
            userDefaults: UserDefaults(suiteName: "ProcessesViewModelTests-\(UUID().uuidString)")!,
            preferredLanguagesProvider: { ["en-US"] }
        )
    }

    override func tearDown() {
        mockAPI = nil
        appState = nil
        super.tearDown()
    }

    private func makeViewModel(canManage: Bool = true) -> ProcessesViewModel {
        return ProcessesViewModel(api: mockAPI, appState: appState, canManageProcesses: { canManage })
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeItem(name: String, running: Bool = true) -> ProcessSummaryItem {
        return ProcessSummaryItem(
            name: name,
            running: running,
            enabled: true,
            role: "core",
            lifecycle: "long_running",
            activePublicId: nil,
            rssBytes: 12_345_678,
            cpuPercent: 3.5,
            owned: nil
        )
    }

    private func makeSummary(processes: [ProcessSummaryItem] = []) -> ProcessSummaryData {
        return ProcessSummaryData(
            type: nil,
            sequenceId: 1,
            publicId: "psum-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            coordinator: nil,
            coordinatorLabel: nil,
            feeds: ProcessCategoryCount(running: 1, total: 1),
            strategies: ProcessCategoryCount(running: 2, total: 3),
            executors: ProcessCategoryCount(running: 1, total: 1),
            brokers: ProcessCategoryCount(running: 1, total: 1),
            processes: processes
        )
    }

    private func makeConfigured(
        name: String = "p",
        role: String = "core",
        kind: String = "instance",
        managedRemotely: Bool? = false,
        enabled: Bool = true,
        running: Bool = true,
        coordinatorLabel: String? = nil
    ) -> ConfiguredProcess {
        return ConfiguredProcess(
            type: nil,
            sequenceId: 1,
            publicId: "cfg-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            name: name,
            enabled: enabled,
            running: running,
            mode: "process",
            classPath: "snapper.X",
            method: "run",
            parameters: nil,
            note: nil,
            lifecycle: "long_running",
            role: role,
            tags: nil,
            parametersSchema: nil,
            isOneShot: false,
            activePublicId: nil,
            kind: kind,
            walletPublicId: nil,
            parentTemplate: nil,
            template: nil,
            coordinator: nil,
            coordinatorLabel: coordinatorLabel,
            managedRemotely: managedRemotely
        )
    }

    private func makeStartData(status: String = "success", message: String? = nil) -> ProcessStartData {
        return ProcessStartData(
            type: nil,
            sequenceId: 1,
            publicId: "start-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            status: status,
            name: "p",
            processPublicId: nil,
            message: message
        )
    }

    private func makeStopData(status: String = "success", message: String? = nil) -> ProcessStopData {
        return ProcessStopData(
            type: nil,
            sequenceId: 1,
            publicId: "stop-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            status: status,
            name: "p",
            message: message
        )
    }

    private func makeDesiredData(action: String) -> ProcessDesiredStateData {
        return ProcessDesiredStateData(
            type: nil,
            sequenceId: 1,
            publicId: "desired-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            status: "success",
            name: "p",
            action: action,
            coordinator: nil,
            managedRemotely: true,
            message: nil
        )
    }

    private func configuredList(
        name: String,
        mode: ProcessControlMode,
        running: Bool,
        enabled: Bool
    ) -> [ConfiguredProcess] {
        switch mode {
        case .local:
            return [makeConfigured(name: name, managedRemotely: false, enabled: enabled, running: running)]
        case .remote:
            return [makeConfigured(name: name, managedRemotely: true, enabled: enabled, running: running)]
        case .none:
            return []
        }
    }

    /// Prime the join so ``controlMode(for:)`` resolves to `mode`, then
    /// install counting reload handlers (same data) so a mutation's
    /// reload-after-mutate is observable while the routing stays put.
    @discardableResult
    private func primeAndCount(
        viewModel: ProcessesViewModel,
        name: String = "p",
        mode: ProcessControlMode,
        running: Bool = true,
        enabled: Bool = true
    ) async -> ProcessesReloadCounter {
        let summary = makeSummary(processes: [makeItem(name: name, running: running)])
        let configured = configuredList(name: name, mode: mode, running: running, enabled: enabled)
        mockAPI.fetchProcessSummaryHandler = { summary }
        mockAPI.fetchConfiguredProcessesHandler = { configured }
        await viewModel.load()
        let counter = ProcessesReloadCounter()
        mockAPI.fetchProcessSummaryHandler = {
            await counter.increment()
            return summary
        }
        mockAPI.fetchConfiguredProcessesHandler = { configured }
        return counter
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.summary)
        XCTAssertTrue(viewModel.sortedProcesses.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
    }

    func testLoadHappyPathPopulatesSummary() async {
        let viewModel = makeViewModel()
        let summary = makeSummary(processes: [makeItem(name: "trader")])
        mockAPI.fetchProcessSummaryHandler = { summary }
        await viewModel.load()
        XCTAssertEqual(viewModel.summary?.strategies.total, 3)
        XCTAssertEqual(viewModel.sortedProcesses.count, 1)
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadFailureSetsTypedLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchProcessSummaryHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertNil(viewModel.summary)
        guard case .httpError(let code) = viewModel.loadError else {
            return XCTFail("Expected httpError, got \(String(describing: viewModel.loadError))")
        }
        XCTAssertEqual(code, 503)
    }

    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        let viewModel = makeViewModel()
        mockAPI.fetchProcessSummaryHandler = { throw ProcessesUnexpectedError() }
        await viewModel.load()
        guard case .invalidResponse = viewModel.loadError else {
            return XCTFail("Expected invalidResponse fallback, got \(String(describing: viewModel.loadError))")
        }
    }

    func testLoadClearsPreviousError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchProcessSummaryHandler = { throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.loadError)

        let summary = makeSummary()
        mockAPI.fetchProcessSummaryHandler = { summary }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError)
        XCTAssertNotNil(viewModel.summary)
    }

    func testLoadFailurePreservesCachedSummary() async {
        let viewModel = makeViewModel()
        let summary = makeSummary(processes: [makeItem(name: "trader")])
        mockAPI.fetchProcessSummaryHandler = { summary }
        await viewModel.load()
        XCTAssertNotNil(viewModel.summary)

        mockAPI.fetchProcessSummaryHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.summary, "Cached summary must survive a failed refresh")
        XCTAssertNotNil(viewModel.loadError)
    }

    func testSortedProcessesAreNameOrdered() async {
        let viewModel = makeViewModel()
        let summary = makeSummary(processes: [
            makeItem(name: "zeta"),
            makeItem(name: "alpha"),
            makeItem(name: "mike"),
        ])
        mockAPI.fetchProcessSummaryHandler = { summary }
        await viewModel.load()
        XCTAssertEqual(viewModel.sortedProcesses.map(\.name), ["alpha", "mike", "zeta"])
    }

    private func makeWebSocketManager() -> WebSocketManager {
        return WebSocketManager(
            authService: FakeAuthService(nextToken: "t"),
            taskFactory: FakeWebSocketTaskFactory(task: FakeWebSocketTask()),
            sleeper: FakeSleeper()
        )
    }

    private func makeConfiguredEvent() -> ProcessConfiguredEventData {
        return ProcessConfiguredEventData(
            type: "process_configured_event",
            sequenceId: 1,
            publicId: "pce-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            processNames: ["strategy_macd"],
            snapshotAt: Self.baseTimestamp
        )
    }

    /// A process-event frame arriving after the startup reconciliation
    /// settles triggers exactly one additional debounced reload.
    func testLiveProcessEventTriggersOneReload() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = ProcessesReloadCounter()
        let summary = makeSummary(processes: [makeItem(name: "trader")])
        mockAPI.fetchProcessSummaryHandler = { await counter.increment(); return summary }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 500_000_000)
        let baseline = await counter.value
        manager.state.lastProcessConfigured = makeConfiguredEvent()
        try await Task.sleep(nanoseconds: 500_000_000)

        let after = await counter.value
        XCTAssertEqual(after, baseline + 1, "one process event triggers exactly one reload")
        viewModel.stopObservingLiveUpdates(token: token)
    }

    /// Stopping observation before the debounce fires leaves no pending
    /// reload.
    func testStopLeavesNoPendingReload() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = ProcessesReloadCounter()
        let summary = makeSummary()
        mockAPI.fetchProcessSummaryHandler = { await counter.increment(); return summary }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 100_000_000)
        manager.state.lastProcessConfigured = makeConfiguredEvent()
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.stopObservingLiveUpdates(token: token)
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "stop before the debounce window must cancel the pending reload")
    }

    func testControlModeDecisionTable() {
        XCTAssertEqual(
            ProcessesViewModel.controlMode(configured: nil, canManageProcesses: true),
            .none,
            "no configured match → no controls"
        )
        XCTAssertEqual(
            ProcessesViewModel.controlMode(configured: makeConfigured(), canManageProcesses: false),
            .none,
            "no manage:processes → no controls"
        )
        XCTAssertEqual(
            ProcessesViewModel.controlMode(configured: makeConfigured(role: "strategy"), canManageProcesses: true),
            .none,
            "strategy role is filtered out (Strategies screen owns it)"
        )
        XCTAssertEqual(
            ProcessesViewModel.controlMode(configured: makeConfigured(role: "backtest"), canManageProcesses: true),
            .none,
            "backtest role is filtered out"
        )
        XCTAssertEqual(
            ProcessesViewModel.controlMode(configured: makeConfigured(kind: "template"), canManageProcesses: true),
            .none,
            "config-only template gets no start/stop (backend 422s)"
        )
        XCTAssertEqual(
            ProcessesViewModel.controlMode(configured: makeConfigured(managedRemotely: true), canManageProcesses: true),
            .remote,
            "remotely-owned row → desired-state only"
        )
        XCTAssertEqual(
            ProcessesViewModel.controlMode(configured: makeConfigured(managedRemotely: false), canManageProcesses: true),
            .local
        )
        XCTAssertEqual(
            ProcessesViewModel.controlMode(configured: makeConfigured(managedRemotely: nil), canManageProcesses: true),
            .local,
            "absent managed_remotely defaults to local"
        )
    }

    func testShowsRestartDecision() {
        XCTAssertFalse(ProcessesViewModel.showsRestart(mode: .none, running: true, configured: nil))
        XCTAssertTrue(ProcessesViewModel.showsRestart(mode: .local, running: true, configured: nil))
        XCTAssertFalse(ProcessesViewModel.showsRestart(mode: .local, running: false, configured: nil))
        XCTAssertTrue(
            ProcessesViewModel.showsRestart(mode: .remote, running: true, configured: makeConfigured(enabled: false)),
            "remote running row can restart"
        )
        XCTAssertTrue(
            ProcessesViewModel.showsRestart(mode: .remote, running: false, configured: makeConfigured(enabled: true)),
            "remote enabled-but-stopped row can restart (coordinator bounces on converge)"
        )
        XCTAssertFalse(
            ProcessesViewModel.showsRestart(mode: .remote, running: false, configured: makeConfigured(enabled: false))
        )
    }

    func testRestartNonceValidityAndMint() {
        XCTAssertTrue(ProcessesViewModel.isValidRestartNonce("abcd1234"))
        XCTAssertTrue(ProcessesViewModel.isValidRestartNonce("valid_nonce-1234"))
        XCTAssertFalse(ProcessesViewModel.isValidRestartNonce("short7"), "below 8 chars")
        XCTAssertFalse(ProcessesViewModel.isValidRestartNonce(String(repeating: "a", count: 65)), "above 64 chars")
        XCTAssertFalse(ProcessesViewModel.isValidRestartNonce("has space 1"), "space is illegal")
        XCTAssertFalse(ProcessesViewModel.isValidRestartNonce("bad/slash/123"), "slash is illegal")
        let minted = ProcessesViewModel.makeRestartNonce()
        XCTAssertTrue(ProcessesViewModel.isValidRestartNonce(minted), "minted nonce satisfies the backend grammar")
        XCTAssertEqual(minted.count, 36)
    }

    func testStartStatusInspection() {
        XCTAssertNil(ProcessesViewModel.startFailureMessage(makeStartData(status: "success")))
        XCTAssertNil(ProcessesViewModel.startFailureMessage(makeStartData(status: "already_running")))
        XCTAssertEqual(
            ProcessesViewModel.startFailureMessage(makeStartData(status: "error", message: "template not startable")),
            "template not startable"
        )
    }

    func testStopStatusInspection() {
        XCTAssertNil(ProcessesViewModel.stopFailureMessage(makeStopData(status: "success")))
        XCTAssertNil(ProcessesViewModel.stopFailureMessage(makeStopData(status: "not_running")))
        XCTAssertEqual(
            ProcessesViewModel.stopFailureMessage(makeStopData(status: "error", message: "still busy")),
            "still busy"
        )
    }

    func testLoadJoinsConfiguredByName() async {
        let viewModel = makeViewModel()
        let summary = makeSummary(processes: [makeItem(name: "feed")])
        let configured = [makeConfigured(name: "feed", managedRemotely: true)]
        mockAPI.fetchProcessSummaryHandler = { summary }
        mockAPI.fetchConfiguredProcessesHandler = { configured }
        await viewModel.load()
        XCTAssertEqual(viewModel.configuredByName["feed"]?.managedRemotely, true)
        XCTAssertEqual(viewModel.controlMode(for: "feed"), .remote)
    }

    func testConfiguredFetchFailureFailsClosed() async {
        let viewModel = makeViewModel()
        let summary = makeSummary(processes: [makeItem(name: "feed")])
        mockAPI.fetchProcessSummaryHandler = { summary }
        mockAPI.fetchConfiguredProcessesHandler = { throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.summary, "summary still renders when configured fetch fails")
        XCTAssertNil(viewModel.loadError, "configured failure must not surface as a load error")
        XCTAssertTrue(viewModel.configuredByName.isEmpty, "controls fail closed on a configured-fetch failure")
    }

    func testConfiguredFailureAfterSuccessfulJoinFailsClosed() async {
        let viewModel = makeViewModel()
        _ = await primeAndCount(viewModel: viewModel, mode: .local, running: true)
        XCTAssertEqual(viewModel.controlMode(for: "p"), .local, "join succeeded initially")

        let summary = makeSummary(processes: [makeItem(name: "p")])
        mockAPI.fetchProcessSummaryHandler = { summary }
        mockAPI.fetchConfiguredProcessesHandler = { throw APIError.httpError(500) }
        await viewModel.load()

        XCTAssertNotNil(viewModel.summary, "summary list keeps rendering")
        XCTAssertTrue(viewModel.configuredByName.isEmpty, "a later configured failure clears the join")
        XCTAssertEqual(viewModel.controlMode(for: "p"), .none, "controls disappear until a successful configured fetch")
    }

    func testStartLocalCallsStartAndReloads() async {
        let viewModel = makeViewModel()
        let counter = await primeAndCount(viewModel: viewModel, mode: .local, running: false)
        let recorder = ProcessControlRecorder()
        let startData = makeStartData()
        mockAPI.startProcessHandler = { name, body in
            await recorder.recordStart(name: name, mode: body.mode)
            return startData
        }
        let ok = await viewModel.start(name: "p", expected: .local)
        XCTAssertTrue(ok)
        let starts = await recorder.starts
        XCTAssertEqual(starts.count, 1)
        guard let startCall = starts.first else { return XCTFail("no start recorded") }
        XCTAssertEqual(startCall.name, "p")
        XCTAssertNil(startCall.mode, "iOS v1 passes mode nil to let the backend default")
        let startReloads = await counter.value
        XCTAssertEqual(startReloads, 1, "reload-after-mutate ran once")
    }

    func testStartAlreadyRunningIsBenign() async {
        let viewModel = makeViewModel()
        let counter = await primeAndCount(viewModel: viewModel, mode: .local, running: false)
        let startData = makeStartData(status: "already_running")
        mockAPI.startProcessHandler = { _, _ in startData }
        let ok = await viewModel.start(name: "p", expected: .local)
        XCTAssertTrue(ok, "already_running is a benign HTTP 200 status")
        XCTAssertNil(viewModel.submitError)
        let reloads = await counter.value
        XCTAssertEqual(reloads, 1)
    }

    func testStandaloneStopOperationalErrorSurfacedWithoutReload() async {
        let viewModel = makeViewModel()
        let counter = await primeAndCount(viewModel: viewModel, mode: .local, running: true)
        let stopData = makeStopData(status: "error", message: "cannot stop right now")
        mockAPI.stopProcessHandler = { _ in stopData }
        let ok = await viewModel.stop(name: "p", expected: .local)
        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.submitError, "cannot stop right now", "backend message surfaced verbatim")
        let reloads = await counter.value
        XCTAssertEqual(reloads, 0, "an operational failure does not reload")
        XCTAssertFalse(viewModel.isInFlight("p"))
    }

    func testStartRemoteSetsEnableDesiredState() async {
        let viewModel = makeViewModel()
        let counter = await primeAndCount(viewModel: viewModel, mode: .remote, running: false)
        let recorder = ProcessControlRecorder()
        let desired = makeDesiredData(action: "enable")
        mockAPI.setProcessDesiredStateHandler = { _, body in
            await recorder.recordDesired(action: body.action, nonce: body.restartNonce)
            return desired
        }
        let ok = await viewModel.start(name: "p", expected: .remote)
        XCTAssertTrue(ok)
        let actions = await recorder.desired
        XCTAssertEqual(actions.map(\.action), ["enable"])
        guard let enableCall = actions.first else { return XCTFail("no desired-state recorded") }
        XCTAssertNil(enableCall.nonce, "enable carries no restart nonce")
        let enableReloads = await counter.value
        XCTAssertEqual(enableReloads, 1)
    }

    func testStopRemoteSetsDisableDesiredState() async {
        let viewModel = makeViewModel()
        _ = await primeAndCount(viewModel: viewModel, mode: .remote, running: true)
        let recorder = ProcessControlRecorder()
        let desired = makeDesiredData(action: "disable")
        mockAPI.setProcessDesiredStateHandler = { _, body in
            await recorder.recordDesired(action: body.action, nonce: body.restartNonce)
            return desired
        }
        let ok = await viewModel.stop(name: "p", expected: .remote)
        XCTAssertTrue(ok)
        let disableActions = await recorder.desired.map(\.action)
        XCTAssertEqual(disableActions, ["disable"])
    }

    func testRestartLocalRunsStopThenStart() async {
        let viewModel = makeViewModel()
        let counter = await primeAndCount(viewModel: viewModel, mode: .local, running: true)
        let recorder = ProcessControlRecorder()
        let startData = makeStartData()
        let stopData = makeStopData()
        mockAPI.stopProcessHandler = { _ in
            await recorder.recordSequence("stop")
            return stopData
        }
        mockAPI.startProcessHandler = { _, _ in
            await recorder.recordSequence("start")
            return startData
        }
        let ok = await viewModel.restart(name: "p", expected: .local)
        XCTAssertTrue(ok)
        let sequence = await recorder.sequence
        XCTAssertEqual(sequence, ["stop", "start"], "local restart is a stop-then-start sequence")
        let restartReloads = await counter.value
        XCTAssertGreaterThan(restartReloads, 0)
    }

    func testLocalRestartPartialFailureReportsAndReloads() async {
        let viewModel = makeViewModel()
        let counter = await primeAndCount(viewModel: viewModel, mode: .local, running: true)
        let stopData = makeStopData()
        let startData = makeStartData(status: "error", message: "port busy")
        mockAPI.stopProcessHandler = { _ in stopData }
        mockAPI.startProcessHandler = { _, _ in startData }
        let ok = await viewModel.restart(name: "p", expected: .local)
        XCTAssertFalse(ok)
        XCTAssertEqual(
            viewModel.submitError,
            "The process was stopped but could not be restarted: port busy",
            "partial restart reports the distinct stop-succeeded/start-failed message"
        )
        let reloads = await counter.value
        XCTAssertGreaterThan(reloads, 0, "a partial restart still reloads to show the stopped state")
        XCTAssertFalse(viewModel.isInFlight("p"))
    }

    func testLocalRestartThrownStartFailureStillReloads() async {
        let viewModel = makeViewModel()
        let counter = await primeAndCount(viewModel: viewModel, mode: .local, running: true)
        let stopData = makeStopData()
        mockAPI.stopProcessHandler = { _ in stopData }
        mockAPI.startProcessHandler = { _, _ in throw APIError.serverError("boom") }
        let ok = await viewModel.restart(name: "p", expected: .local)
        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.submitError, "The process was stopped but could not be restarted: boom")
        let reloads = await counter.value
        XCTAssertGreaterThan(reloads, 0, "a thrown start failure also reloads")
    }

    func testRestartRemoteMintsValidNonce() async {
        let viewModel = makeViewModel()
        _ = await primeAndCount(viewModel: viewModel, mode: .remote, running: true)
        let recorder = ProcessControlRecorder()
        let desired = makeDesiredData(action: "restart")
        mockAPI.setProcessDesiredStateHandler = { _, body in
            await recorder.recordDesired(action: body.action, nonce: body.restartNonce)
            return desired
        }
        let ok = await viewModel.restart(name: "p", expected: .remote)
        XCTAssertTrue(ok)
        let actions = await recorder.desired
        XCTAssertEqual(actions.map(\.action), ["restart"])
        guard let restartCall = actions.first, let nonce = restartCall.nonce else {
            return XCTFail("remote restart must mint a nonce")
        }
        XCTAssertTrue(ProcessesViewModel.isValidRestartNonce(nonce))
    }

    func testMutationThrownFailureSurfacesServerDetailAndSkipsReload() async {
        let viewModel = makeViewModel()
        let counter = await primeAndCount(viewModel: viewModel, mode: .local, running: true)
        mockAPI.stopProcessHandler = { _ in
            throw APIError.serverError("Process 'p' is disabled; enable it before requesting a restart")
        }
        let ok = await viewModel.stop(name: "p", expected: .local)
        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.submitError, "Process 'p' is disabled; enable it before requesting a restart")
        let failureReloads = await counter.value
        XCTAssertEqual(failureReloads, 0, "a failed mutation must not reload")
        XCTAssertFalse(viewModel.isInFlight("p"))
        XCTAssertFalse(viewModel.isPending("p"))
    }

    func testForbiddenServerErrorSurfacedAndClearsInFlight() async {
        let viewModel = makeViewModel()
        _ = await primeAndCount(viewModel: viewModel, mode: .local, running: false)
        mockAPI.startProcessHandler = { _, _ in
            throw APIError.serverError("Forbidden: registry-classified strategy")
        }
        let ok = await viewModel.start(name: "p", expected: .local)
        XCTAssertFalse(ok)
        XCTAssertEqual(
            viewModel.submitError,
            "Forbidden: registry-classified strategy",
            "a 403 serverError is surfaced verbatim (registry-classification residual)"
        )
        XCTAssertFalse(viewModel.isInFlight("p"), "the in-flight guard clears after a 403")
    }

    func testStaleOwnershipAbortsBeforeSendingRequest() async {
        let viewModel = makeViewModel()
        _ = await primeAndCount(viewModel: viewModel, mode: .local, running: true)
        viewModel.configuredByName["p"] = makeConfigured(name: "p", managedRemotely: true)
        let recorder = ProcessControlRecorder()
        let stopData = makeStopData()
        mockAPI.stopProcessHandler = { _ in
            await recorder.recordSequence("stop")
            return stopData
        }
        let ok = await viewModel.stop(name: "p", expected: .local)
        XCTAssertFalse(ok)
        XCTAssertEqual(
            viewModel.submitError,
            "This process can no longer be controlled from here. Refresh and try again."
        )
        let calls = await recorder.sequence
        XCTAssertTrue(calls.isEmpty, "no local POST is sent when the row became remote under the user")
        XCTAssertFalse(viewModel.isInFlight("p"))
    }

    /// The stale-routing regression: the FRESH post-stop configured fetch
    /// flips the row local→remote (handler-driven — no manual cache
    /// mutation), so the start POST must never fire and the partial state is
    /// surfaced. A rogue local copy resolves LOCAL only while running and
    /// REMOTE once stopped, so re-reading the pre-stop cache would send the
    /// forbidden duplicate-publisher start.
    func testLocalRestartAbortsWhenPostStopConfiguredFetchFlipsRemote() async {
        let viewModel = makeViewModel()
        let summary = makeSummary(processes: [makeItem(name: "p", running: true)])
        let localRow = [makeConfigured(name: "p", managedRemotely: false)]
        let remoteRow = [makeConfigured(name: "p", managedRemotely: true)]
        let feed = ConfiguredFeedSwitch(first: localRow, rest: remoteRow)
        mockAPI.fetchProcessSummaryHandler = { summary }
        mockAPI.fetchConfiguredProcessesHandler = { await feed.next() }
        await viewModel.load()
        XCTAssertEqual(viewModel.controlMode(for: "p"), .local, "cached routing is local before the stop")

        let counter = ProcessesReloadCounter()
        mockAPI.fetchProcessSummaryHandler = {
            await counter.increment()
            return summary
        }
        let recorder = ProcessControlRecorder()
        let stopData = makeStopData()
        let startData = makeStartData()
        mockAPI.stopProcessHandler = { _ in
            await recorder.recordSequence("stop")
            return stopData
        }
        mockAPI.startProcessHandler = { _, _ in
            await recorder.recordSequence("start")
            return startData
        }

        let ok = await viewModel.restart(name: "p", expected: .local)
        XCTAssertFalse(ok)
        XCTAssertEqual(
            viewModel.submitError,
            "The process was stopped but can no longer be restarted from here. Refresh and try again."
        )
        let sequence = await recorder.sequence
        XCTAssertEqual(sequence, ["stop"], "the fresh fetch flips the row remote → the start POST is never sent")
        let reloads = await counter.value
        XCTAssertGreaterThan(reloads, 0, "the abandoned restart still reloads to show the stopped state")
    }

    func testLocalRestartAbortsWhenPostStopConfiguredFetchFails() async {
        let viewModel = makeViewModel()
        let summary = makeSummary(processes: [makeItem(name: "p", running: true)])
        let localRow = [makeConfigured(name: "p", managedRemotely: false)]
        let feed = ConfiguredFeedSwitch(first: localRow, rest: [], failAfterFirst: true)
        mockAPI.fetchProcessSummaryHandler = { summary }
        mockAPI.fetchConfiguredProcessesHandler = { try await feed.nextOrThrow() }
        await viewModel.load()
        XCTAssertEqual(viewModel.controlMode(for: "p"), .local)

        let recorder = ProcessControlRecorder()
        let stopData = makeStopData()
        let startData = makeStartData()
        mockAPI.fetchProcessSummaryHandler = { summary }
        mockAPI.stopProcessHandler = { _ in
            await recorder.recordSequence("stop")
            return stopData
        }
        mockAPI.startProcessHandler = { _, _ in
            await recorder.recordSequence("start")
            return startData
        }
        let ok = await viewModel.restart(name: "p", expected: .local)
        XCTAssertFalse(ok)
        XCTAssertEqual(
            viewModel.submitError,
            "The process was stopped but can no longer be restarted from here. Refresh and try again.",
            "a failed post-stop configured fetch fails closed and abandons the start leg"
        )
        let sequence = await recorder.sequence
        XCTAssertEqual(sequence, ["stop"], "the start POST is never sent when the fresh fetch fails")
    }

    /// The coordinator-bypass regression: the post-stop refresh funnels
    /// through the serialized ``load()`` (not a direct fetch that could
    /// commit stale-over-fresh). While the stop leg is gated, a concurrent
    /// pulse-load commits remote ownership; when the stop releases, the
    /// funneled refresh observes that committed remote state and the start
    /// POST is never sent. The ReloadHandshake makes the interleave
    /// deterministic — no fixed sleeps.
    func testLocalRestartRefreshFunnelsThroughCoordinatorUnderConcurrentPulse() async {
        let viewModel = makeViewModel()
        let summary = makeSummary(processes: [makeItem(name: "p", running: true)])
        let localRow = [makeConfigured(name: "p", managedRemotely: false)]
        let remoteRow = [makeConfigured(name: "p", managedRemotely: true)]
        let feed = ConfiguredFeedSwitch(first: localRow, rest: remoteRow)
        mockAPI.fetchProcessSummaryHandler = { summary }
        mockAPI.fetchConfiguredProcessesHandler = { await feed.next() }
        await viewModel.load()
        XCTAssertEqual(viewModel.controlMode(for: "p"), .local, "cached routing is local before the stop")

        let stopGate = ReloadHandshake()
        let recorder = ProcessControlRecorder()
        let stopData = makeStopData()
        let startData = makeStartData()
        mockAPI.stopProcessHandler = { _ in
            await recorder.recordSequence("stop")
            await stopGate.markStartedAndWait()
            return stopData
        }
        mockAPI.startProcessHandler = { _, _ in
            await recorder.recordSequence("start")
            return startData
        }

        let restartTask = Task { @MainActor in await viewModel.restart(name: "p", expected: .local) }
        await stopGate.awaitStarted()

        await viewModel.load()
        XCTAssertEqual(viewModel.controlMode(for: "p"), .remote, "the concurrent pulse-load committed remote ownership")

        await stopGate.release()
        let ok = await restartTask.value
        XCTAssertFalse(ok)
        XCTAssertEqual(
            viewModel.submitError,
            "The process was stopped but can no longer be restarted from here. Refresh and try again."
        )
        let sequence = await recorder.sequence
        XCTAssertEqual(
            sequence,
            ["stop"],
            "the coordinator-funneled refresh observes the pulse's remote commit; the start POST never fires"
        )
    }

    func testNoneExpectedIsSilentNoOp() async {
        let viewModel = makeViewModel()
        let counter = await primeAndCount(viewModel: viewModel, mode: .local, running: true)
        let started = await viewModel.start(name: "p", expected: .none)
        let stopped = await viewModel.stop(name: "p", expected: .none)
        let restarted = await viewModel.restart(name: "p", expected: .none)
        XCTAssertFalse(started)
        XCTAssertFalse(stopped)
        XCTAssertFalse(restarted)
        XCTAssertNil(viewModel.submitError, "a .none expected is a silent no-op")
        let reloads = await counter.value
        XCTAssertEqual(reloads, 0, "no-op modes never touch the network")
    }

    func testSimultaneousMutationsOnDifferentRowsBothProceed() async {
        let viewModel = makeViewModel()
        let summary = makeSummary(processes: [
            makeItem(name: "a", running: false),
            makeItem(name: "b", running: false),
        ])
        let configured = [
            makeConfigured(name: "a", managedRemotely: false),
            makeConfigured(name: "b", managedRemotely: false),
        ]
        mockAPI.fetchProcessSummaryHandler = { summary }
        mockAPI.fetchConfiguredProcessesHandler = { configured }
        await viewModel.load()

        let recorder = ProcessControlRecorder()
        let startData = makeStartData()
        mockAPI.startProcessHandler = { name, _ in
            await recorder.recordSequence(name)
            return startData
        }
        let taskA = Task { @MainActor in await viewModel.start(name: "a", expected: .local) }
        let taskB = Task { @MainActor in await viewModel.start(name: "b", expected: .local) }
        let okA = await taskA.value
        let okB = await taskB.value
        XCTAssertTrue(okA)
        XCTAssertTrue(okB)
        let names = await recorder.sequence
        XCTAssertEqual(Set(names), ["a", "b"], "the per-name guard does not cross-block different rows")
    }

    func testInFlightGuardPreventsDoubleSubmit() async {
        let viewModel = makeViewModel()
        _ = await primeAndCount(viewModel: viewModel, mode: .local, running: true)
        let calls = ProcessControlRecorder()
        let stopData = makeStopData()
        mockAPI.stopProcessHandler = { _ in
            await calls.recordSequence("stop")
            try? await Task.sleep(nanoseconds: 200_000_000)
            return stopData
        }
        let task = Task { @MainActor in await viewModel.stop(name: "p", expected: .local) }
        try? await Task.sleep(nanoseconds: 60_000_000)
        let second = await viewModel.stop(name: "p", expected: .local)
        let first = await task.value
        XCTAssertFalse(second, "a concurrent second stop is rejected by the in-flight guard")
        XCTAssertTrue(first)
        let handlerCalls = await calls.sequence
        XCTAssertEqual(handlerCalls, ["stop"], "the handler ran exactly once")
    }

    func testPendingIndicatorLifecycleForDesiredState() async {
        let viewModel = makeViewModel()
        _ = await primeAndCount(viewModel: viewModel, mode: .remote, running: true)
        let gate = ReleaseGate()
        let desired = makeDesiredData(action: "disable")
        mockAPI.setProcessDesiredStateHandler = { _, _ in
            await gate.waitForRelease()
            return desired
        }
        XCTAssertFalse(viewModel.isPending("p"))
        let task = Task { @MainActor in await viewModel.stop(name: "p", expected: .remote) }
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(viewModel.isPending("p"), "desired-state write shows pending during the call")
        XCTAssertTrue(viewModel.isInFlight("p"))
        await gate.release()
        _ = await task.value
        XCTAssertFalse(viewModel.isPending("p"), "pending clears at the mutation's own completion")
        XCTAssertFalse(viewModel.isInFlight("p"))
    }

    func testPendingSurvivesUnrelatedReloadAndClearsPerName() async {
        let viewModel = makeViewModel()
        _ = await primeAndCount(viewModel: viewModel, mode: .remote, running: true)
        let gate = ReleaseGate()
        let desired = makeDesiredData(action: "disable")
        mockAPI.setProcessDesiredStateHandler = { _, _ in
            await gate.waitForRelease()
            return desired
        }
        let task = Task { @MainActor in await viewModel.stop(name: "p", expected: .remote) }
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(viewModel.isPending("p"), "pending set during the desired-state call")
        await viewModel.load()
        XCTAssertTrue(viewModel.isPending("p"), "an unrelated reload must not clear another row's pending indicator")
        await gate.release()
        _ = await task.value
        XCTAssertFalse(viewModel.isPending("p"), "pending clears at the mutation's own completion (per-name)")
    }

    /// Deterministic (no fixed sleeps): the first fetch signals it has
    /// STARTED — proving it captured summary A — then blocks on a gate. Only
    /// after that signal is the handler swapped to B and the second reload
    /// issued. On release, the serialized worker commits A then B; the newest
    /// (B) wins and the stale (A) response never overwrites it.
    func testConcurrentReloadsCommitLatestNotStale() async {
        let viewModel = makeViewModel()
        let summaryA = makeSummary(processes: [makeItem(name: "A")])
        let summaryB = makeSummary(processes: [makeItem(name: "B")])
        let handshake = ReloadHandshake()
        mockAPI.fetchConfiguredProcessesHandler = { [] }
        mockAPI.fetchProcessSummaryHandler = {
            await handshake.markStartedAndWait()
            return summaryA
        }
        let task1 = Task { @MainActor in await viewModel.load() }
        await handshake.awaitStarted()
        mockAPI.fetchProcessSummaryHandler = { summaryB }
        let task2 = Task { @MainActor in await viewModel.load() }
        await handshake.release()
        _ = await task1.value
        _ = await task2.value
        XCTAssertEqual(
            viewModel.sortedProcesses.first?.name,
            "B",
            "the serialized worker commits the newest reload; a stale response never wins"
        )
    }
}

private actor ConfiguredFeedSwitch {
    private let first: [ConfiguredProcess]
    private let rest: [ConfiguredProcess]
    private let failAfterFirst: Bool
    private var calls = 0

    init(first: [ConfiguredProcess], rest: [ConfiguredProcess], failAfterFirst: Bool = false) {
        self.first = first
        self.rest = rest
        self.failAfterFirst = failAfterFirst
    }

    func next() -> [ConfiguredProcess] {
        calls += 1
        return calls == 1 ? first : rest
    }

    func nextOrThrow() throws -> [ConfiguredProcess] {
        calls += 1
        if calls == 1 { return first }
        if failAfterFirst { throw APIError.httpError(500) }
        return rest
    }
}

private actor ReloadHandshake {
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

private actor ProcessesReloadCounter {
    var value: Int = 0
    func increment() { value += 1 }
}

private actor ProcessControlRecorder {
    struct StartCall {
        let name: String
        let mode: String?
    }
    struct DesiredCall {
        let action: String
        let nonce: String?
    }

    var starts: [StartCall] = []
    var desired: [DesiredCall] = []
    var sequence: [String] = []

    func recordStart(name: String, mode: String?) {
        starts.append(StartCall(name: name, mode: mode))
    }
    func recordDesired(action: String, nonce: String?) {
        desired.append(DesiredCall(action: action, nonce: nonce))
    }
    func recordSequence(_ value: String) {
        sequence.append(value)
    }
}

private actor ReleaseGate {
    private var released = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func waitForRelease() async {
        if released { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func release() {
        released = true
        for continuation in continuations {
            continuation.resume()
        }
        continuations.removeAll()
    }
}
