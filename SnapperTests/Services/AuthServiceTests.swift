import XCTest
@testable import Snapper

@MainActor
final class AuthServiceTests: XCTestCase {

    var authService: AuthService!

    override func setUp() async throws {
        try await super.setUp()
        authService = AuthService(session: .shared)
    }

    override func tearDown() async throws {
        authService = nil
        try await super.tearDown()
    }

    func testLoginResponseDecoding() throws {
        let json = """
        {
            "sequence_id": 1,
            "public_id": "01961234-5678-7000-8000-000000000001",
            "timestamp": "2025-01-01T00:00:00Z",
            "session_id": "session-1",
            "payload": {
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000002",
                "timestamp": "2025-01-01T00:00:00Z",
                "session_id": "session-1",
                "message": "Login successful",
                "expires_in": 900,
                "user": {
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000003",
                    "timestamp": "2025-01-01T00:00:00Z",
                    "session_id": "session-1",
                    "username": "testuser",
                    "email": "test@example.com",
                    "role": "viewer",
                    "is_active": true,
                    "created_at": "2025-01-01T00:00:00Z"
                }
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(LoginResponse.self, from: json)

        XCTAssertEqual(response.payload.message, "Login successful")
        XCTAssertEqual(response.payload.expiresIn, 900)
        XCTAssertEqual(response.payload.user.username, "testuser")
        XCTAssertEqual(response.payload.user.email, "test@example.com")
        XCTAssertEqual(response.payload.user.role, .viewer)
    }

    func testErrorResponseDecoding() throws {
        let json = """
        {
            "detail": "Invalid credentials"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(ErrorResponse.self, from: json)

        XCTAssertEqual(response.detail, "Invalid credentials")
    }

    func testHasRoleHierarchy() {
        authService.currentUser = makeUser(role: .operatorRole)

        XCTAssertTrue(authService.hasRole(.viewer))
        XCTAssertTrue(authService.hasRole(.operatorRole))
        XCTAssertFalse(authService.hasRole(.admin))
    }

    func testHasPermissionUsesGeneratedRolePermissions() {
        authService.currentUser = makeUser(role: .viewer)

        XCTAssertTrue(authService.hasPermission(.readMarketData))
        XCTAssertFalse(authService.hasPermission(.manageUsers))
    }

    /// UI-gating contract for the trading mutation surfaces
    /// (OrdersView / PositionsView toolbar + action sheet). Viewer
    /// role must NOT have any of the three mutation permissions —
    /// the iOS UI hides New Order / Cancel swipe / Close / Reduce /
    /// Attach SL+TP / Attach trailing stop based on these flags so
    /// Apple Reviewer's read-only account doesn't surface buttons
    /// that 403 against the backend capability guard.
    func testViewerRoleLacksTradingMutationPermissions() {
        authService.currentUser = makeUser(role: .viewer)

        XCTAssertFalse(
            authService.hasPermission(.createOrders),
            "Viewer must not have createOrders — UI gates the New Order toolbar button on this."
        )
        XCTAssertFalse(
            authService.hasPermission(.cancelOrders),
            "Viewer must not have cancelOrders — UI gates the Cancel swipe action on this."
        )
        XCTAssertFalse(
            authService.hasPermission(.managePositions),
            "Viewer must not have managePositions — UI gates the position-row tap + action-sheet (Close/Reduce/Attach) on this."
        )
    }

    /// Mirror assertion for the operator + admin paths so any
    /// future role-permission table refactor that accidentally
    /// drops mutation perms from those roles fails loudly here
    /// rather than silently hiding the buttons in production.
    func testOperatorAndAdminRolesRetainTradingMutationPermissions() {
        authService.currentUser = makeUser(role: .operatorRole)

        XCTAssertTrue(authService.hasPermission(.createOrders))
        XCTAssertTrue(authService.hasPermission(.cancelOrders))
        XCTAssertTrue(authService.hasPermission(.managePositions))

        authService.currentUser = makeUser(role: .admin)

        XCTAssertTrue(authService.hasPermission(.createOrders))
        XCTAssertTrue(authService.hasPermission(.cancelOrders))
        XCTAssertTrue(authService.hasPermission(.managePositions))
    }

    func testHasPermissionAdminAllowsAll() {
        authService.currentUser = makeUser(role: .admin)

        XCTAssertTrue(authService.hasPermission(.manageUsers))
        XCTAssertTrue(authService.hasPermission(.configureSystem))
    }

    func testCanAccessUsesGeneratedResourceAccess() {
        authService.currentUser = makeUser(role: .viewer)

        XCTAssertTrue(authService.canAccess("overview"))
        XCTAssertFalse(authService.canAccess("settings"))
    }

    func testCanAccessRejectsUnknownResource() {
        authService.currentUser = makeUser(role: .admin)

        XCTAssertFalse(authService.canAccess("unknown-resource"))
    }

    /// The AI-integration (delegates) surface is operator/admin only —
    /// guards the generated ``resourceAccess["ai-integration"]`` mapping
    /// that the Home entry card's ``canAccess("ai-integration")`` gate
    /// depends on.
    func testCanAccessAiIntegrationIsOperatorAdminOnly() {
        authService.currentUser = makeUser(role: .operatorRole)
        XCTAssertTrue(authService.canAccess("ai-integration"))

        authService.currentUser = makeUser(role: .admin)
        XCTAssertTrue(authService.canAccess("ai-integration"))

        authService.currentUser = makeUser(role: .viewer)
        XCTAssertFalse(authService.canAccess("ai-integration"))

        authService.currentUser = makeUser(role: .aiDelegate)
        XCTAssertFalse(authService.canAccess("ai-integration"))
    }

    func testRoleAndPermissionChecksReturnFalseWithoutUser() {
        authService.currentUser = nil

        XCTAssertFalse(authService.hasRole(.viewer))
        XCTAssertFalse(authService.hasPermission(.readMarketData))
        XCTAssertFalse(authService.canAccess("overview"))
    }

    private func makeUser(role: UserRole) -> UserProfile {
        UserProfile(
            type: nil,
            sequenceId: 0,
            publicId: "01961234-5678-7000-8000-000000000099",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "test-session",
            topic: nil,
            username: "testuser",
            email: "test@example.com",
            role: role,
            isActive: true,
            createdAt: Date(timeIntervalSince1970: 0),
            operatorPublicIds: nil,
            primaryOperatorPublicId: nil,
            activeWalletPublicId: nil,
            defaultLanguage: nil
        )
    }

}
