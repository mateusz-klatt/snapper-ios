import XCTest
@testable import Snapper

private struct AiReviewsUnexpectedError: Error {}

@MainActor
final class AiReviewsViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() {
        mockAPI = nil
        super.tearDown()
    }

    private func makeViewModel() -> AiReviewsViewModel {
        return AiReviewsViewModel(api: mockAPI)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeReview(
        reviewPublicId: String,
        decision: String? = "approve",
        status: String = "resolved_approved"
    ) -> AdminAiReviewItem {
        return AdminAiReviewItem(
            reviewPublicId: reviewPublicId,
            strategyPublicId: "strategy-1",
            userPublicId: "user-1",
            operatorPublicId: "operator-1",
            walletPublicId: "wallet-1",
            instrumentPublicId: "instrument-1",
            selectedDelegatePublicId: "delegate-1",
            respondingDelegatePublicId: nil,
            status: status,
            decision: decision,
            rationale: "momentum confirmed",
            resolutionMode: nil,
            dispatchVersion: 1,
            createdAt: Self.baseTimestamp,
            resolvedAt: Self.baseTimestamp,
            deadline: Self.baseTimestamp
        )
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.reviews.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
    }

    func testLoadHappyPathPopulatesReviews() async {
        let viewModel = makeViewModel()
        let review = makeReview(reviewPublicId: "r-1")
        mockAPI.fetchAiReviewsHandler = { [review] }
        await viewModel.load()
        XCTAssertEqual(viewModel.reviews.count, 1)
        XCTAssertEqual(viewModel.reviews.first?.decision, "approve")
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadFailureSetsTypedLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchAiReviewsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertTrue(viewModel.reviews.isEmpty)
        guard case .httpError(let code) = viewModel.loadError else {
            return XCTFail("Expected httpError, got \(String(describing: viewModel.loadError))")
        }
        XCTAssertEqual(code, 503)
    }

    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        let viewModel = makeViewModel()
        mockAPI.fetchAiReviewsHandler = { throw AiReviewsUnexpectedError() }
        await viewModel.load()
        guard case .invalidResponse = viewModel.loadError else {
            return XCTFail("Expected invalidResponse fallback, got \(String(describing: viewModel.loadError))")
        }
    }

    func testLoadClearsPreviousError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchAiReviewsHandler = { throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.loadError)

        let review = makeReview(reviewPublicId: "r-1")
        mockAPI.fetchAiReviewsHandler = { [review] }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.reviews.count, 1)
    }

    func testLoadFailurePreservesCachedData() async {
        let viewModel = makeViewModel()
        let review = makeReview(reviewPublicId: "r-1")
        mockAPI.fetchAiReviewsHandler = { [review] }
        await viewModel.load()
        XCTAssertEqual(viewModel.reviews.count, 1)

        mockAPI.fetchAiReviewsHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertEqual(viewModel.reviews.count, 1, "Cached list must survive a failed refresh")
        XCTAssertNotNil(viewModel.loadError)
    }

    private func makeWebSocketManager() -> WebSocketManager {
        return WebSocketManager(
            authService: FakeAuthService(nextToken: "t"),
            taskFactory: FakeWebSocketTaskFactory(task: FakeWebSocketTask()),
            sleeper: FakeSleeper()
        )
    }

    /// An ai_review activity pulse arriving after the startup reconciliation
    /// settles triggers exactly one additional debounced ``load()``.
    func testLiveAiReviewPulseTriggersOneReload() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = AiReviewsReloadCounter()
        mockAPI.fetchAiReviewsHandler = { await counter.increment(); return [] }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 500_000_000)
        let baseline = await counter.value
        manager.state.lastAiReviewActivityAt = Date()
        try await Task.sleep(nanoseconds: 500_000_000)

        let after = await counter.value
        XCTAssertEqual(after, baseline + 1, "one ai_review pulse triggers exactly one reload")
        viewModel.stopObservingLiveUpdates(token: token)
    }

    /// Stopping observation before the debounce fires leaves no pending
    /// reload.
    func testStopLeavesNoPendingReload() async throws {
        let viewModel = makeViewModel()
        let manager = makeWebSocketManager()
        let counter = AiReviewsReloadCounter()
        mockAPI.fetchAiReviewsHandler = { await counter.increment(); return [] }

        let token = viewModel.startObservingLiveUpdates(from: manager)
        try await Task.sleep(nanoseconds: 100_000_000)
        manager.state.lastAiReviewActivityAt = Date()
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.stopObservingLiveUpdates(token: token)
        try await Task.sleep(nanoseconds: 500_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 0, "stop before the debounce window must cancel the pending reload")
    }
}

private actor AiReviewsReloadCounter {
    var value: Int = 0
    func increment() { value += 1 }
}
