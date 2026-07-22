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
                    "created_at": "2025-01-01T00:00:00Z",
                    "effective_permissions": ["read:market_data", "read:ai_reviews"],
                    "delegate_public_id": null
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
        XCTAssertEqual(response.payload.user.effectivePermissions, [.readMarketData, .readAiReviews])
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

    func testHasPermissionUsesEffectiveSessionPermissions() {
        authService.currentUser = makeUser(
            role: .viewer,
            effectivePermissions: [.readMarketData]
        )

        XCTAssertTrue(authService.hasPermission(.readMarketData))
        XCTAssertFalse(authService.hasPermission(.manageUsers))
    }

    func testHasPermissionDoesNotInferCapabilitiesFromRole() {
        authService.currentUser = makeUser(role: .admin, effectivePermissions: [])
        XCTAssertFalse(authService.hasPermission(.manageUsers))
        XCTAssertFalse(authService.hasPermission(.configureSystem))

        authService.currentUser = makeUser(
            role: .viewer,
            effectivePermissions: [.manageUsers]
        )
        XCTAssertTrue(authService.hasPermission(.manageUsers))
    }

    func testViewerPermissionSetIsFullReadOnlyOperatorAccess() {
        let viewerPermissions = rolePermissions[.viewer] ?? []
        XCTAssertEqual(
            Set(viewerPermissions),
            Set([
                .readAccountState,
                .readAiIntegration,
                .readAiReviews,
                .readBacktests,
                .readMarketData,
                .readMarketViews,
                .readNotifications,
                .readOrders,
                .readPositions,
                .readProcesses,
                .readSignals,
                .readStrategies,
                .readSystemStatus,
                .manageNotificationDevices,
            ])
        )

        authService.currentUser = makeUser(
            role: .viewer,
            effectivePermissions: viewerPermissions
        )

        XCTAssertFalse(authService.hasPermission(.createOrders))
        XCTAssertFalse(authService.hasPermission(.cancelOrders))
        XCTAssertFalse(authService.hasPermission(.managePositions))
        XCTAssertFalse(authService.hasPermission(.manageProcesses))
        XCTAssertFalse(authService.hasPermission(.startStrategies))
        XCTAssertFalse(authService.hasPermission(.stopStrategies))
        XCTAssertFalse(authService.hasPermission(.manageBacktests))
        XCTAssertFalse(authService.hasPermission(.manageAiIntegration))
    }

    func testOperatorAndAdminPermissionSetsRetainTradingMutations() {
        for role in [UserRole.operatorRole, .admin] {
            authService.currentUser = makeUser(
                role: role,
                effectivePermissions: rolePermissions[role] ?? []
            )

            XCTAssertTrue(authService.hasPermission(.createOrders))
            XCTAssertTrue(authService.hasPermission(.cancelOrders))
            XCTAssertTrue(authService.hasPermission(.managePositions))
        }
    }

    func testCanAccessUsesGeneratedResourceRequirements() {
        authService.currentUser = makeUser(role: .viewer, effectivePermissions: [])

        XCTAssertTrue(authService.canAccess("overview"))
        XCTAssertFalse(authService.canAccess("settings"))

        authService.currentUser = makeUser(
            role: .viewer,
            effectivePermissions: [.configureSystem]
        )
        XCTAssertTrue(authService.canAccess("settings"))
    }

    func testCanAccessRejectsUnknownResource() {
        authService.currentUser = makeUser(
            role: .admin,
            effectivePermissions: rolePermissions[.admin] ?? []
        )

        XCTAssertFalse(authService.canAccess("unknown-resource"))
    }

    func testCanAccessFailsClosedWhenEffectivePermissionsAreMissing() {
        authService.currentUser = makeUser(
            role: .admin,
            effectivePermissions: nil
        )

        XCTAssertFalse(authService.hasPermission(.readMarketData))
        XCTAssertFalse(authService.canAccess("market"))
        XCTAssertTrue(authService.canAccess("overview"))
    }

    func testVenueAccountsRequiresReadAccountStateRegardlessOfRole() {
        for role in allUserRoles {
            authService.currentUser = makeUser(
                role: role,
                effectivePermissions: [.readAccountState]
            )
            XCTAssertTrue(authService.hasPermission(.readAccountState))
            XCTAssertTrue(authService.canAccess("accounts"))
        }

        authService.currentUser = makeUser(role: .admin, effectivePermissions: [])
        XCTAssertFalse(authService.hasPermission(.readAccountState))
        XCTAssertFalse(authService.canAccess("accounts"))
    }

    func testCanAccessAiIntegrationRequiresReadPermission() {
        for role in allUserRoles {
            authService.currentUser = makeUser(
                role: role,
                effectivePermissions: [.readAiIntegration]
            )
            XCTAssertTrue(authService.canAccess("ai-integration"))
        }

        authService.currentUser = makeUser(role: .admin, effectivePermissions: [])
        XCTAssertFalse(authService.canAccess("ai-integration"))
    }

    /// The iOS AI-review surface is an audit list, so it requires the
    /// dedicated read permission after the generated any-of resource
    /// requirement is evaluated. A submit-only delegate can act through
    /// its own workflow but cannot open this read-only audit surface.
    func testCanAccessAiReviewAuditRequiresReadPermission() {
        authService.currentUser = makeUser(
            role: .viewer,
            effectivePermissions: [.readAiReviews]
        )
        XCTAssertTrue(authService.canAccess("ai-reviews"))

        authService.currentUser = makeUser(
            role: .aiDelegate,
            effectivePermissions: [.submitAiReviewDecision]
        )
        XCTAssertFalse(authService.canAccess("ai-reviews"))

        authService.currentUser = makeUser(
            role: .aiDelegate,
            effectivePermissions: [.readAiReviews, .submitAiReviewDecision]
        )
        XCTAssertTrue(authService.canAccess("ai-reviews"))
    }

    func testCanAccessBacktestsRequiresActiveWallet() {
        authService.currentUser = makeUser(
            role: .viewer,
            effectivePermissions: [.readBacktests]
        )
        XCTAssertFalse(authService.canAccess("backtests"))

        authService.currentUser = makeUser(
            role: .viewer,
            activeWalletPublicId: "wallet-1",
            effectivePermissions: [.readBacktests]
        )
        XCTAssertTrue(authService.canAccess("backtests"))

        authService.currentUser = makeUser(
            role: .admin,
            activeWalletPublicId: "wallet-1",
            effectivePermissions: []
        )
        XCTAssertFalse(authService.canAccess("backtests"))
    }

    func testPermissionAndResourceChecksReturnFalseWithoutUser() {
        authService.currentUser = nil

        XCTAssertFalse(authService.hasPermission(.readMarketData))
        XCTAssertFalse(authService.canAccess("overview"))
    }

    private func makeUser(
        role: UserRole,
        activeWalletPublicId: String? = nil,
        effectivePermissions: [Permission]? = []
    ) -> UserProfile {
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
            activeWalletPublicId: activeWalletPublicId,
            defaultLanguage: nil,
            effectivePermissions: effectivePermissions,
            delegatePublicId: nil
        )
    }

    private var allUserRoles: [UserRole] {
        [.aiResearcher, .aiReviewer, .aiDelegate, .viewer, .operatorRole, .admin]
    }

}
