import XCTest
@testable import Snapper

private struct AdminUnexpectedError: Error {}

@MainActor
final class AdminViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() {
        mockAPI = nil
        super.tearDown()
    }

    private func makeViewModel() -> AdminViewModel {
        return AdminViewModel(api: mockAPI)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeUser(
        publicId: String,
        username: String = "viewer",
        role: UserRole = .viewer,
        isActive: Bool? = true
    ) -> UserProfile {
        return UserProfile(
            type: nil,
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            username: username,
            email: "user@example.com",
            role: role,
            isActive: isActive,
            createdAt: Self.baseTimestamp,
            operatorPublicIds: nil,
            primaryOperatorPublicId: nil,
            activeWalletPublicId: nil,
            defaultLanguage: nil,
            effectivePermissions: nil,
            delegatePublicId: nil
        )
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.users.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
    }

    func testLoadHappyPathPopulatesUsers() async {
        let viewModel = makeViewModel()
        let user = makeUser(publicId: "u-1")
        mockAPI.fetchUsersHandler = { [user] }
        await viewModel.load()
        XCTAssertEqual(viewModel.users.count, 1)
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadFailureSetsTypedLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchUsersHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertTrue(viewModel.users.isEmpty)
        guard case .httpError(let code) = viewModel.loadError else {
            return XCTFail("Expected httpError, got \(String(describing: viewModel.loadError))")
        }
        XCTAssertEqual(code, 503)
    }

    func testLoadNonAPIErrorFallsBackToInvalidResponse() async {
        let viewModel = makeViewModel()
        mockAPI.fetchUsersHandler = { throw AdminUnexpectedError() }
        await viewModel.load()
        guard case .invalidResponse = viewModel.loadError else {
            return XCTFail("Expected invalidResponse fallback, got \(String(describing: viewModel.loadError))")
        }
    }

    func testLoadClearsPreviousError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchUsersHandler = { throw APIError.httpError(500) }
        await viewModel.load()
        XCTAssertNotNil(viewModel.loadError)

        let user = makeUser(publicId: "u-1")
        mockAPI.fetchUsersHandler = { [user] }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.users.count, 1)
    }

    func testLoadFailurePreservesCachedData() async {
        let viewModel = makeViewModel()
        let user = makeUser(publicId: "u-1")
        mockAPI.fetchUsersHandler = { [user] }
        await viewModel.load()
        XCTAssertEqual(viewModel.users.count, 1)

        mockAPI.fetchUsersHandler = { throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertEqual(viewModel.users.count, 1, "Cached list must survive a failed refresh")
        XCTAssertNotNil(viewModel.loadError)
    }

    func testSortedUsersAreUsernameOrdered() async {
        let viewModel = makeViewModel()
        let users = [
            makeUser(publicId: "u-z", username: "zoe"),
            makeUser(publicId: "u-a", username: "alice"),
            makeUser(publicId: "u-m", username: "mallory"),
        ]
        mockAPI.fetchUsersHandler = { users }
        await viewModel.load()
        XCTAssertEqual(viewModel.sortedUsers.map(\.username), ["alice", "mallory", "zoe"])
    }
}
