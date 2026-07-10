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
}
