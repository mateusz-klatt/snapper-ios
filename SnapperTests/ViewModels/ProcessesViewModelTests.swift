import XCTest
@testable import Snapper

private struct ProcessesUnexpectedError: Error {}

@MainActor
final class ProcessesViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() {
        mockAPI = nil
        super.tearDown()
    }

    private func makeViewModel() -> ProcessesViewModel {
        return ProcessesViewModel(api: mockAPI)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeItem(name: String, running: Bool = true) -> ProcessSummaryItem {
        return ProcessSummaryItem(
            name: name,
            running: running,
            enabled: true,
            role: "core",
            lifecycle: "long_running",
            rssBytes: 12_345_678,
            cpuPercent: 3.5
        )
    }

    private func makeSummary(processes: [ProcessSummaryItem] = []) -> ProcessSummaryData {
        return ProcessSummaryData(
            sequenceId: 1,
            publicId: "psum-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            feeds: ProcessCategoryCount(running: 1, total: 1),
            strategies: ProcessCategoryCount(running: 2, total: 3),
            executors: ProcessCategoryCount(running: 1, total: 1),
            brokers: ProcessCategoryCount(running: 1, total: 1),
            processes: processes
        )
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
}
