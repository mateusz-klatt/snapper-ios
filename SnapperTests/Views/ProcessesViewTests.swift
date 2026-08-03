import XCTest
@testable import Snapper

@MainActor
final class ProcessesViewTests: XCTestCase {

    func testShouldShowLoadErrorWhenNoDataAndError() {
        XCTAssertTrue(
            ProcessesViewModel.shouldShowLoadError(hasData: false, loadError: .httpError(503), isLoading: false)
        )
    }

    func testShouldNotShowLoadErrorWhenHasData() {
        XCTAssertFalse(
            ProcessesViewModel.shouldShowLoadError(hasData: true, loadError: .invalidResponse, isLoading: false)
        )
    }

    func testShouldNotShowLoadErrorWhileLoading() {
        XCTAssertFalse(
            ProcessesViewModel.shouldShowLoadError(hasData: false, loadError: .invalidResponse, isLoading: true)
        )
    }

    func testShouldNotShowLoadErrorWhenNoError() {
        XCTAssertFalse(
            ProcessesViewModel.shouldShowLoadError(hasData: false, loadError: nil, isLoading: false)
        )
    }

    func testRunningLabelKey() {
        XCTAssertEqual(ProcessesViewModel.runningLabelKey(true), "processes.status.running")
        XCTAssertEqual(ProcessesViewModel.runningLabelKey(false), "processes.status.stopped")
    }

    /// CPU is already a percentage, so the formatter must divide by 100
    /// before the percent style multiplies it back — 3.5 renders as
    /// "3.5%", not "350%" or "0.035%". ``nil`` renders as a dash.
    func testFormattedCpuPercentDividesByHundred() {
        XCTAssertEqual(ProcessesViewModel.formattedCpuPercent(nil, locale: .us), "—")
        let mid = ProcessesViewModel.formattedCpuPercent(3.5, locale: .us)
        XCTAssertTrue(mid.contains("3.5"), "expected 3.5%, got \(mid)")
        XCTAssertFalse(mid.contains("350"), "must not read as 350%, got \(mid)")
        let zero = ProcessesViewModel.formattedCpuPercent(0.0, locale: .us)
        XCTAssertTrue(zero.contains("0"), "expected 0%, got \(zero)")
    }

    func testFormattedMemoryNilIsDash() {
        XCTAssertEqual(ProcessesViewModel.formattedMemory(nil), "—")
        XCTAssertNotEqual(ProcessesViewModel.formattedMemory(12_345_678), "—")
    }

    private func configured(
        role: String = "core",
        kind: String = "instance",
        managedRemotely: Bool? = false,
        enabled: Bool = true,
        running: Bool = true
    ) -> ConfiguredProcess {
        return ConfiguredProcess(
            type: nil,
            sequenceId: 1,
            publicId: "cfg-1",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "s",
            topic: nil,
            name: "p",
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
            coordinatorLabel: nil,
            managedRemotely: managedRemotely
        )
    }

    /// A viewer (no ``manage:processes``) never sees controls, whatever
    /// the row is.
    func testViewerSeesNoControls() {
        let mode = ProcessesViewModel.controlMode(
            configured: configured(managedRemotely: false),
            canManageProcesses: false
        )
        XCTAssertEqual(mode, .none)
        XCTAssertFalse(ProcessesViewModel.showsRestart(mode: mode, running: true, configured: nil))
    }

    /// A local running row renders start-vs-stop as stop, plus restart.
    func testLocalRunningRowRendersStopAndRestart() {
        let cfg = configured(managedRemotely: false, running: true)
        let mode = ProcessesViewModel.controlMode(configured: cfg, canManageProcesses: true)
        XCTAssertEqual(mode, .local)
        XCTAssertTrue(ProcessesViewModel.showsRestart(mode: mode, running: true, configured: cfg))
    }

    /// A remote enabled-but-stopped row still offers restart (the
    /// coordinator bounces it on converge) and routes to desired-state.
    func testRemoteEnabledStoppedRowRendersRestart() {
        let cfg = configured(managedRemotely: true, enabled: true, running: false)
        let mode = ProcessesViewModel.controlMode(configured: cfg, canManageProcesses: true)
        XCTAssertEqual(mode, .remote)
        XCTAssertTrue(ProcessesViewModel.showsRestart(mode: mode, running: false, configured: cfg))
    }

    /// A config-only executor template exposes no lifecycle controls.
    func testTemplateRowRendersNoControls() {
        let mode = ProcessesViewModel.controlMode(
            configured: configured(kind: "template"),
            canManageProcesses: true
        )
        XCTAssertEqual(mode, .none)
    }
}
