import XCTest
@testable import Snapper

/// Non-``APIError`` error to drive the ``load()`` fallback branch that
/// maps any non-typed failure to ``APIError.invalidResponse``.
private struct HealthUnexpectedError: Error {}

@MainActor
final class HealthViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() {
        mockAPI = nil
        super.tearDown()
    }

    private func makeViewModel() -> HealthViewModel {
        return HealthViewModel(api: mockAPI)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeResponse(
        status: String = "healthy",
        version: String = "0.1.0"
    ) -> HealthCheckResponse {
        return HealthCheckResponse(
            type: nil,
            sequenceId: 1,
            publicId: "resp-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            payload: HealthCheckData(
                type: nil,
                sequenceId: 1,
                publicId: "health-1",
                timestamp: Self.baseTimestamp,
                sessionId: "session-test",
                topic: nil,
                status: status,
                version: version,
                connections: ConnectionStats(
                    activeConnections: 3,
                    zmqSubscribers: 2,
                    subscriberTasks: 1,
                    activeTopics: 5,
                    activeClients: 3
                ),
                topics: HealthTopics(active: 5),
                gapDetection: GapDetectionStats(
                    bridge: GapStats(
                        gapsDetected: 0,
                        sessionResets: 0,
                        duplicates: 0,
                        midStreamJoins: 0,
                        rejectedUnstamped: 0
                    ),
                    restClients: nil
                )
            )
        )
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.health)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
    }

    func testLoadHappyPathPopulatesHealthPayload() async {
        let viewModel = makeViewModel()
        let response = makeResponse(status: "healthy", version: "1.2.3")
        mockAPI.fetchHealthHandler = { response }
        await viewModel.load()
        XCTAssertEqual(viewModel.health?.status, "healthy")
        XCTAssertEqual(viewModel.health?.version, "1.2.3")
        XCTAssertEqual(viewModel.health?.connections.activeConnections, 3)
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadFailureSetsTypedLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchHealthHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertNil(viewModel.health)
        guard case .httpError(let code) = viewModel.loadError else {
            return XCTFail("Expected httpError, got \(String(describing: viewModel.loadError))")
        }
        XCTAssertEqual(code, 503)
    }

    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        let viewModel = makeViewModel()
        mockAPI.fetchHealthHandler = { throw HealthUnexpectedError() }
        await viewModel.load()
        guard case .invalidResponse = viewModel.loadError else {
            return XCTFail("Expected invalidResponse fallback, got \(String(describing: viewModel.loadError))")
        }
    }

    func testLoadClearsPreviousError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchHealthHandler = { throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.loadError)

        let response = makeResponse()
        mockAPI.fetchHealthHandler = { response }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError)
        XCTAssertNotNil(viewModel.health)
    }

    /// A refresh failure on top of a good snapshot keeps the cached
    /// data (so the list stays visible) while recording the error —
    /// ``shouldShowLoadError`` then suppresses the full-screen error
    /// variant because ``hasData`` is true.
    func testLoadFailurePreservesCachedData() async {
        let viewModel = makeViewModel()
        let response = makeResponse(status: "healthy")
        mockAPI.fetchHealthHandler = { response }
        await viewModel.load()
        XCTAssertNotNil(viewModel.health)

        mockAPI.fetchHealthHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.health, "Cached snapshot must survive a failed refresh")
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertFalse(
            HealthViewModel.shouldShowLoadError(
                hasData: viewModel.health != nil,
                loadError: viewModel.loadError,
                isLoading: viewModel.isLoading
            )
        )
    }
}
