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
}
