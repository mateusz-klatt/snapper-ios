import XCTest
@testable import Snapper

private struct AiIntegrationUnexpectedError: Error {}

@MainActor
final class AiIntegrationViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() {
        mockAPI = nil
        super.tearDown()
    }

    private func makeViewModel() -> AiIntegrationViewModel {
        return AiIntegrationViewModel(api: mockAPI)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDelegate(
        publicId: String,
        label: String = "MCP grant",
        username: String = "ai-mcp",
        isActive: Bool = true
    ) -> DelegateRead {
        return DelegateRead(
            publicId: publicId,
            username: username,
            label: label,
            createdByUserPublicId: "user-1",
            createdAt: Self.baseTimestamp,
            isActive: isActive,
            caps: DelegateCapsBody(maxOpenOrders: 5, maxDailyNotionalUsd: 10_000)
        )
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.delegates.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
    }

    func testLoadHappyPathPopulatesDelegates() async {
        let viewModel = makeViewModel()
        let delegate = makeDelegate(publicId: "d-1")
        mockAPI.fetchDelegatesHandler = { [delegate] }
        await viewModel.load()
        XCTAssertEqual(viewModel.delegates.count, 1)
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadFailureSetsTypedLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchDelegatesHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertTrue(viewModel.delegates.isEmpty)
        guard case .httpError(let code) = viewModel.loadError else {
            return XCTFail("Expected httpError, got \(String(describing: viewModel.loadError))")
        }
        XCTAssertEqual(code, 503)
    }

    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        let viewModel = makeViewModel()
        mockAPI.fetchDelegatesHandler = { throw AiIntegrationUnexpectedError() }
        await viewModel.load()
        guard case .invalidResponse = viewModel.loadError else {
            return XCTFail("Expected invalidResponse fallback, got \(String(describing: viewModel.loadError))")
        }
    }

    func testLoadClearsPreviousError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchDelegatesHandler = { throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.loadError)

        let delegate = makeDelegate(publicId: "d-1")
        mockAPI.fetchDelegatesHandler = { [delegate] }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.delegates.count, 1)
    }

    func testLoadFailurePreservesCachedData() async {
        let viewModel = makeViewModel()
        let delegate = makeDelegate(publicId: "d-1")
        mockAPI.fetchDelegatesHandler = { [delegate] }
        await viewModel.load()
        XCTAssertEqual(viewModel.delegates.count, 1)

        mockAPI.fetchDelegatesHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertEqual(viewModel.delegates.count, 1, "Cached list must survive a failed refresh")
        XCTAssertNotNil(viewModel.loadError)
    }

    func testSortedDelegatesAreLabelOrdered() async {
        let viewModel = makeViewModel()
        let delegates = [
            makeDelegate(publicId: "d-z", label: "Zeta desk"),
            makeDelegate(publicId: "d-a", label: "Alpha desk"),
            makeDelegate(publicId: "d-m", label: "Mike desk"),
        ]
        mockAPI.fetchDelegatesHandler = { delegates }
        await viewModel.load()
        XCTAssertEqual(viewModel.sortedDelegates.map(\.label), ["Alpha desk", "Mike desk", "Zeta desk"])
    }
}
