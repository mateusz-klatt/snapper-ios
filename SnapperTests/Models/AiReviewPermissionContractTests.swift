import XCTest
@testable import Snapper

/// Authorization contract for the AI-review surfaces, pinned in one
/// place so a backend regeneration or a UI refactor cannot silently move
/// the gates.
///
/// **Server truth this file mirrors** (`snapper.server.ai_review_routes`,
/// `snapper.application.ai_review.service`):
///
/// - `POST /api/ai-reviews/{id}/decision` is admitted by the
///   decision-capability projector — the dedicated
///   `submit:ai_review_decision` permission (plus a deliberate legacy
///   scope-v1 compatibility branch that no app session can reach). The
///   service then resolves the CALLER'S USER to an `ai_delegates` row and
///   answers `not_authorized` (403) when that resolution fails or when no
///   scope grant covers the review's wallet + instrument. Holding
///   `create:orders` grants nothing here.
/// - `GET /api/ai-reviews/pending` is gated by `read:signals` AND
///   additionally 422s (`not_a_delegate`) whenever the principal carries
///   no `delegate_public_id`, because the snapshot is KEYED on the
///   delegate identity rather than on a permission. A permission alone
///   can therefore never open the inbox.
/// - `GET /api/ai-reviews` (the audit list) is gated by
///   `read:ai_reviews` and is scoped by operator membership, NOT by the
///   delegate identity.
///
/// The screen-entry requirement is separate from all three: it is the
/// generated `anyPermission([readAiReviews, submitAiReviewDecision])`,
/// which merely decides whether the screen opens at all.
@MainActor
final class AiReviewPermissionContractTests: XCTestCase {

    /// The role × permission truth table, read from the GENERATED
    /// `rolePermissions`. A regeneration that changes any grant relevant
    /// to the AI-review surfaces fails here first, before any gating
    /// code silently changes meaning.
    ///
    /// `aiReviewer` and `aiDelegate` both hold the decision permission
    /// but neither holds `read:ai_reviews`: they act on reviews, they do
    /// not audit them. `viewer` and `operatorRole` are the mirror image.
    /// Only `admin` holds both.
    func testRoleGrantTruthTableForAiReviewSurfaces() {
        let expected: [UserRole: (submit: Bool, createOrders: Bool, readAudit: Bool, readSignals: Bool)] = [
            .aiReviewer: (submit: true, createOrders: false, readAudit: false, readSignals: true),
            .aiDelegate: (submit: true, createOrders: true, readAudit: false, readSignals: true),
            .viewer: (submit: false, createOrders: false, readAudit: true, readSignals: true),
            .operatorRole: (submit: false, createOrders: true, readAudit: true, readSignals: true),
            .admin: (submit: true, createOrders: true, readAudit: true, readSignals: true),
        ]

        for (role, row) in expected {
            let granted = Set(rolePermissions[role] ?? [])
            XCTAssertEqual(
                granted.contains(.submitAiReviewDecision),
                row.submit,
                "submit:ai_review_decision grant drifted for \(role)"
            )
            XCTAssertEqual(
                granted.contains(.createOrders),
                row.createOrders,
                "create:orders grant drifted for \(role)"
            )
            XCTAssertEqual(
                granted.contains(.readAiReviews),
                row.readAudit,
                "read:ai_reviews grant drifted for \(role)"
            )
            XCTAssertEqual(
                granted.contains(.readSignals),
                row.readSignals,
                "read:signals grant drifted for \(role)"
            )
        }
    }

    /// `create:orders` is NOT the decision gate. The backend moved the
    /// write onto the dedicated capability, so an order-creating
    /// principal that lacks it must not be offered the controls.
    func testCreateOrdersDoesNotImplyDecisionCapability() {
        let operatorPermissions = Set(rolePermissions[.operatorRole] ?? [])
        XCTAssertTrue(operatorPermissions.contains(.createOrders))
        XCTAssertFalse(
            operatorPermissions.contains(.submitAiReviewDecision),
            "an operator can place orders but must not be able to veto a review"
        )
    }

    /// The pending inbox needs the delegate IDENTITY as well as
    /// `read:signals`. Every permission-only combination fails closed,
    /// and an empty identity string is treated as absent.
    func testPendingInboxRequiresDelegateIdentityAndReadSignals() {
        XCTAssertTrue(
            AiReviewsViewModel.showsPendingInbox(delegatePublicId: "delegate-1", canReadSignals: true)
        )
        XCTAssertFalse(
            AiReviewsViewModel.showsPendingInbox(delegatePublicId: nil, canReadSignals: true),
            "read:signals alone cannot open a delegate-keyed snapshot (backend 422 not_a_delegate)"
        )
        XCTAssertFalse(
            AiReviewsViewModel.showsPendingInbox(delegatePublicId: "delegate-1", canReadSignals: false)
        )
        XCTAssertFalse(
            AiReviewsViewModel.showsPendingInbox(delegatePublicId: "", canReadSignals: true),
            "an empty identity is not an identity"
        )
        XCTAssertFalse(
            AiReviewsViewModel.showsPendingInbox(delegatePublicId: nil, canReadSignals: false)
        )
    }

    /// The ViewModel resolves the inbox predicate LIVE from the session
    /// so a re-login as a different principal, or a delegate row being
    /// revoked, takes effect without recreating the screen.
    func testViewModelResolvesInboxPredicateFromLiveSession() {
        let identity = MutableBox<String?>(nil)
        let signals = MutableBox<Bool>(false)
        let viewModel = AiReviewsViewModel(
            api: MockAPIClient(),
            appState: AppState(
                userDefaults: UserDefaults(suiteName: "AiReviewPermissionContractTests-\(UUID().uuidString)")!,
                preferredLanguagesProvider: { ["en-US"] }
            ),
            delegatePublicId: { identity.value },
            canReadSignals: { signals.value },
            canSubmitDecision: { false }
        )

        XCTAssertFalse(viewModel.showsPendingInbox)
        identity.value = "delegate-1"
        XCTAssertFalse(viewModel.showsPendingInbox, "identity without read:signals is not enough")
        signals.value = true
        XCTAssertTrue(viewModel.showsPendingInbox)
        identity.value = nil
        XCTAssertFalse(viewModel.showsPendingInbox, "losing the delegate row closes the inbox")
    }

    /// The decision controls are gated on `submit:ai_review_decision` —
    /// the ALIGNED contract. This matches the backend projector that
    /// admits the write; gating on anything else (historically
    /// `create:orders`) would offer buttons the server rejects, or hide
    /// buttons the server would accept.
    func testDecisionControlsGateOnSubmitAiReviewDecision() {
        let canSubmit = MutableBox<Bool>(false)
        let viewModel = AiReviewsViewModel(
            api: MockAPIClient(),
            appState: AppState(
                userDefaults: UserDefaults(suiteName: "AiReviewPermissionContractTests-\(UUID().uuidString)")!,
                preferredLanguagesProvider: { ["en-US"] }
            ),
            delegatePublicId: { "delegate-1" },
            canReadSignals: { true },
            canSubmitDecision: { canSubmit.value }
        )

        XCTAssertFalse(viewModel.canSubmitDecisions)
        canSubmit.value = true
        XCTAssertTrue(viewModel.canSubmitDecisions)
    }

    /// The screen-entry requirement is the generated any-of, distinct
    /// from both the inbox predicate and the decision gate. Pinning the
    /// generated value catches a regeneration that narrows it.
    func testScreenEntryRequirementIsGeneratedAnyPermission() throws {
        let requirement = try XCTUnwrap(resourceRequirements["ai-reviews"])
        guard case .anyPermission(let permissions) = requirement else {
            return XCTFail("ai-reviews must stay an any-of permission requirement")
        }
        XCTAssertEqual(Set(permissions), Set([.readAiReviews, .submitAiReviewDecision]))
    }

    /// Entry-gate behavior end to end: each of the two permissions opens
    /// the screen on its own, neither is implied by the other, and the
    /// gate is independent of whether the session is a delegate.
    func testEntryGateAdmitsEitherPermissionIndependentlyOfDelegateIdentity() {
        let authService = AuthService(session: .shared)

        for permission in [Permission.readAiReviews, .submitAiReviewDecision] {
            authService.currentUser = Self.makeUser(
                role: .viewer,
                delegatePublicId: nil,
                effectivePermissions: [permission]
            )
            XCTAssertTrue(
                authService.canAccess("ai-reviews"),
                "\(permission.rawValue) alone must open the screen"
            )
        }

        authService.currentUser = Self.makeUser(
            role: .aiDelegate,
            delegatePublicId: "delegate-1",
            effectivePermissions: [.readSignals]
        )
        XCTAssertFalse(
            authService.canAccess("ai-reviews"),
            "being a delegate does not by itself satisfy the entry requirement"
        )
    }

    private static func makeUser(
        role: UserRole,
        delegatePublicId: String?,
        effectivePermissions: [Permission]
    ) -> UserProfile {
        return UserProfile(
            sequenceId: 1,
            publicId: "user-1",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            sessionId: "session-test",
            username: "principal",
            role: role,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            effectivePermissions: effectivePermissions,
            delegatePublicId: delegatePublicId
        )
    }
}

/// Minimal mutable cell so a test can flip what the ViewModel's live
/// permission closures observe between assertions.
private final class MutableBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
