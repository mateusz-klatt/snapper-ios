import XCTest
@testable import Snapper

private struct DeskUnexpectedError: Error {}

@MainActor
final class DeskViewModelTests: XCTestCase {

    private static let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
    private var mockAPI: MockAPIClient!

    override func setUp() async throws {
        try await super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() async throws {
        mockAPI = nil
        try await super.tearDown()
    }

    private func makeViewModel() -> DeskViewModel {
        return DeskViewModel(api: mockAPI)
    }

    private func makeUser(
        role: UserRole = .viewer,
        permissions: [Permission]? = nil,
        primaryOperatorPublicId: String? = nil
    ) -> UserProfile {
        return UserProfile(
            sequenceId: 1,
            publicId: "user-1",
            timestamp: Self.timestamp,
            sessionId: "session-1",
            username: "signed-in-user",
            role: role,
            createdAt: Self.timestamp,
            operatorPublicIds: primaryOperatorPublicId.map { [$0] },
            primaryOperatorPublicId: primaryOperatorPublicId,
            effectivePermissions: permissions
        )
    }

    private func makeOperator(
        publicId: String,
        label: String,
        description: String? = nil
    ) -> OperatorInfo {
        return OperatorInfo(
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.timestamp,
            sessionId: "session-1",
            label: label,
            description: description
        )
    }

    private func configureLoad(user: UserProfile, operators: [OperatorInfo]) {
        mockAPI.fetchCurrentUserHandler = { user }
        mockAPI.fetchOperatorsHandler = { operators }
    }

    func testInitialStateIsFailClosedAndEmpty() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.desks.isEmpty)
        XCTAssertFalse(viewModel.canManageMemberships)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.hasLoaded)
        XCTAssertEqual(viewModel.loadStateAccessibilityIdentifier, "desk.state.loading")
        XCTAssertNil(viewModel.loadError)
        XCTAssertNil(viewModel.selectedDeskPublicId)
        XCTAssertFalse(viewModel.canAttemptAttachment)
    }

    func testViewerLoadJoinsPrimaryDeskAndKeepsAttachHidden() async {
        let primary = makeOperator(
            publicId: "desk-primary",
            label: "Zeta",
            description: "Primary trading desk"
        )
        let secondary = makeOperator(
            publicId: "desk-secondary",
            label: "Alpha",
            description: "   "
        )
        let user = makeUser(
            role: .viewer,
            permissions: [.readMarketData],
            primaryOperatorPublicId: primary.publicId
        )
        configureLoad(user: user, operators: [secondary, primary])
        let viewModel = makeViewModel()

        await viewModel.load()

        XCTAssertEqual(viewModel.desks.map(\.id), ["desk-primary", "desk-secondary"])
        XCTAssertEqual(viewModel.desks.map(\.isPrimary), [true, false])
        XCTAssertEqual(viewModel.desks.first?.description, "Primary trading desk")
        XCTAssertNil(viewModel.desks.last?.description)
        XCTAssertEqual(viewModel.selectedDeskPublicId, "desk-primary")
        XCTAssertFalse(viewModel.canManageMemberships)
        XCTAssertTrue(viewModel.hasLoaded)
        XCTAssertEqual(viewModel.loadStateAccessibilityIdentifier, "desk.state.loaded.content")
        XCTAssertNil(viewModel.loadError)
    }

    func testManagerLoadEnablesAttachFromEffectivePermission() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(
            role: .operatorRole,
            permissions: [.manageDeskMemberships],
            primaryOperatorPublicId: desk.publicId
        )
        configureLoad(user: user, operators: [desk])
        let viewModel = makeViewModel()

        await viewModel.load()

        XCTAssertTrue(viewModel.canManageMemberships)
        XCTAssertTrue(viewModel.canAttemptAttachment)
    }

    func testSuccessfulEmptyLoadHasNoSelectionOrLoadError() async {
        let user = makeUser(permissions: [.manageDeskMemberships])
        configureLoad(user: user, operators: [])
        let viewModel = makeViewModel()

        await viewModel.load()

        XCTAssertTrue(viewModel.desks.isEmpty)
        XCTAssertTrue(viewModel.canManageMemberships)
        XCTAssertTrue(viewModel.hasLoaded)
        XCTAssertNil(viewModel.selectedDeskPublicId)
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.loadStateAccessibilityIdentifier, "desk.state.loaded.empty")
        XCTAssertFalse(viewModel.canAttemptAttachment)
    }

    func testCapabilityDecisionNeverBranchesOnRole() {
        let adminWithoutCapability = makeUser(role: .admin, permissions: [])
        let viewerWithCapability = makeUser(
            role: .viewer,
            permissions: [.manageDeskMemberships]
        )

        XCTAssertFalse(DeskViewModel.canManageMemberships(user: adminWithoutCapability))
        XCTAssertTrue(DeskViewModel.canManageMemberships(user: viewerWithCapability))
    }

    func testLoadKeepsValidSelectionAcrossRefresh() async {
        let first = makeOperator(publicId: "desk-a", label: "Alpha")
        let second = makeOperator(publicId: "desk-b", label: "Beta")
        let user = makeUser(
            permissions: [.manageDeskMemberships],
            primaryOperatorPublicId: first.publicId
        )
        configureLoad(user: user, operators: [first, second])
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.selectedDeskPublicId = second.publicId

        await viewModel.load()

        XCTAssertEqual(viewModel.selectedDeskPublicId, second.publicId)
    }

    func testLoadFailureIsTypedFailsClosedAndDropsUnlabelledCachedDesks() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(permissions: [.manageDeskMemberships])
        configureLoad(user: user, operators: [desk])
        let viewModel = makeViewModel()
        await viewModel.load()
        mockAPI.fetchCurrentUserHandler = { throw APIError.httpError(503) }

        await viewModel.load()

        XCTAssertTrue(viewModel.desks.isEmpty)
        XCTAssertNil(viewModel.selectedDeskPublicId)
        XCTAssertFalse(viewModel.canManageMemberships)
        XCTAssertTrue(viewModel.hasLoaded)
        XCTAssertEqual(viewModel.loadStateAccessibilityIdentifier, "desk.state.failed")
        guard case .httpError(let status) = viewModel.loadError else {
            return XCTFail("Expected typed HTTP error")
        }
        XCTAssertEqual(status, 503)

        configureLoad(user: user, operators: [desk])
        await viewModel.load()

        XCTAssertNil(viewModel.loadError)
        XCTAssertTrue(viewModel.canManageMemberships)
    }

    func testUnexpectedLoadFailureMapsToInvalidResponse() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        mockAPI.fetchCurrentUserHandler = { throw DeskUnexpectedError() }
        mockAPI.fetchOperatorsHandler = { [desk] }
        let viewModel = makeViewModel()

        await viewModel.load()

        guard case .invalidResponse = viewModel.loadError else {
            return XCTFail("Expected invalidResponse fallback")
        }
        XCTAssertFalse(viewModel.canManageMemberships)
    }

    func testConcurrentLoadsCollapseToOneCurrentUserRequest() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(permissions: [.manageDeskMemberships])
        let gate = DeskLoadGate(user: user)
        mockAPI.fetchCurrentUserHandler = { await gate.fetch() }
        mockAPI.fetchOperatorsHandler = { [desk] }
        let viewModel = makeViewModel()

        let firstLoad = Task { await viewModel.load() }
        await gate.waitUntilStarted()
        XCTAssertEqual(viewModel.loadStateAccessibilityIdentifier, "desk.state.loading")
        await viewModel.load()
        let fetchCount = await gate.fetchCount
        XCTAssertEqual(fetchCount, 1)
        await gate.finish()
        await firstLoad.value

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.loadStateAccessibilityIdentifier, "desk.state.loaded.content")
        XCTAssertEqual(viewModel.desks.map(\.id), [desk.publicId])
    }

    func testRefreshExposesRefreshingAccessibilityStateUntilItSettles() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(primaryOperatorPublicId: desk.publicId)
        configureLoad(user: user, operators: [desk])
        let viewModel = makeViewModel()
        await viewModel.load()
        let gate = DeskLoadGate(user: user)
        mockAPI.fetchCurrentUserHandler = { await gate.fetch() }

        let refresh = Task { await viewModel.load() }
        await gate.waitUntilStarted()

        XCTAssertEqual(viewModel.loadStateAccessibilityIdentifier, "desk.state.refreshing")
        await gate.finish()
        await refresh.value
        XCTAssertEqual(viewModel.loadStateAccessibilityIdentifier, "desk.state.loaded.content")
    }

    func testWhitespaceUsernameFailsValidationWithoutRequest() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(permissions: [.manageDeskMemberships])
        let recorder = DeskAttachmentRecorder()
        configureLoad(user: user, operators: [desk])
        mockAPI.attachViewerToDeskHandler = { operatorPublicId, username in
            await recorder.record(operatorPublicId: operatorPublicId, username: username)
        }
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.viewerUsername = " \n "

        let attached = await viewModel.attachViewer()
        let requestCount = await recorder.calls.count

        XCTAssertFalse(attached)
        XCTAssertEqual(viewModel.validationErrorKey, "desk.attach.validation.username")
        XCTAssertEqual(requestCount, 0)
    }

    func testViewerCannotSubmitEvenWhenFormValuesArePresent() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(role: .viewer, permissions: [.readMarketData])
        let recorder = DeskAttachmentRecorder()
        configureLoad(user: user, operators: [desk])
        mockAPI.attachViewerToDeskHandler = { operatorPublicId, username in
            await recorder.record(operatorPublicId: operatorPublicId, username: username)
        }
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.viewerUsername = "viewer"

        let attached = await viewModel.attachViewer()
        let requestCount = await recorder.calls.count

        XCTAssertFalse(attached)
        XCTAssertEqual(requestCount, 0)
    }

    func testSuccessfulAttachSendsExactIdentifiersAndShowsReloginState() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(permissions: [.manageDeskMemberships])
        let recorder = DeskAttachmentRecorder()
        configureLoad(user: user, operators: [desk])
        mockAPI.attachViewerToDeskHandler = { operatorPublicId, username in
            await recorder.record(operatorPublicId: operatorPublicId, username: username)
        }
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.viewerUsername = "  Viewer.Exact  "

        let attached = await viewModel.attachViewer()
        let calls = await recorder.calls

        XCTAssertTrue(attached)
        XCTAssertEqual(
            calls,
            [DeskAttachmentCall(operatorPublicId: "desk-1", username: "Viewer.Exact")]
        )
        XCTAssertEqual(viewModel.viewerUsername, "")
        XCTAssertTrue(viewModel.attachmentSucceeded)
        XCTAssertNil(viewModel.attachmentError)
        XCTAssertNil(viewModel.validationErrorKey)
    }

    func testAttachFailurePreservesInputAndSuccessfulRetryClearsError() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(permissions: [.manageDeskMemberships])
        configureLoad(user: user, operators: [desk])
        mockAPI.attachViewerToDeskHandler = { _, _ in
            throw APIError.httpError(503)
        }
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.viewerUsername = "viewer"

        let firstResult = await viewModel.attachViewer()

        XCTAssertFalse(firstResult)
        XCTAssertEqual(viewModel.viewerUsername, "viewer")
        XCTAssertFalse(viewModel.attachmentSucceeded)
        guard case .httpError(let status) = viewModel.attachmentError else {
            return XCTFail("Expected typed HTTP error")
        }
        XCTAssertEqual(status, 503)

        mockAPI.attachViewerToDeskHandler = { _, _ in }
        let retryResult = await viewModel.attachViewer()

        XCTAssertTrue(retryResult)
        XCTAssertNil(viewModel.attachmentError)
        XCTAssertTrue(viewModel.attachmentSucceeded)
    }

    func testUnexpectedAttachFailureMapsToInvalidResponse() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(permissions: [.manageDeskMemberships])
        configureLoad(user: user, operators: [desk])
        mockAPI.attachViewerToDeskHandler = { _, _ in throw DeskUnexpectedError() }
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.viewerUsername = "viewer"

        let attached = await viewModel.attachViewer()

        XCTAssertFalse(attached)
        guard case .invalidResponse = viewModel.attachmentError else {
            return XCTFail("Expected invalidResponse fallback")
        }
    }

    func testOnlyNonEmptyServerValidationDetailIsPresentedVerbatim() {
        XCTAssertEqual(
            DeskViewModel.attachmentServerDetail(for: .serverError("  Target is not a viewer  ")),
            "Target is not a viewer"
        )
        XCTAssertNil(DeskViewModel.attachmentServerDetail(for: .serverError("  ")))
        XCTAssertNil(DeskViewModel.attachmentServerDetail(for: .httpError(503)))
        XCTAssertNil(DeskViewModel.attachmentServerDetail(for: nil))
    }

    func testConcurrentAttachAttemptsCollapseToOneRequest() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(permissions: [.manageDeskMemberships])
        let gate = DeskAttachmentGate()
        configureLoad(user: user, operators: [desk])
        mockAPI.attachViewerToDeskHandler = { operatorPublicId, username in
            await gate.attach(operatorPublicId: operatorPublicId, username: username)
        }
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.viewerUsername = "viewer"

        let firstAttach = Task { await viewModel.attachViewer() }
        await gate.waitUntilStarted()
        let secondResult = await viewModel.attachViewer()
        let requestCount = await gate.calls.count

        XCTAssertFalse(secondResult)
        XCTAssertTrue(viewModel.isAttaching)
        XCTAssertEqual(requestCount, 1)

        await gate.finish()
        let firstResult = await firstAttach.value
        XCTAssertTrue(firstResult)
        XCTAssertFalse(viewModel.isAttaching)
    }

    func testEditingFormClearsPriorSuccessAndErrorFeedback() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(permissions: [.manageDeskMemberships])
        configureLoad(user: user, operators: [desk])
        mockAPI.attachViewerToDeskHandler = { _, _ in }
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.viewerUsername = "viewer"
        let attached = await viewModel.attachViewer()
        XCTAssertTrue(attached)
        XCTAssertTrue(viewModel.attachmentSucceeded)

        viewModel.viewerUsername = "another-viewer"

        XCTAssertFalse(viewModel.attachmentSucceeded)
        XCTAssertNil(viewModel.attachmentError)
        XCTAssertNil(viewModel.validationErrorKey)
    }

    func testBlankSubmitAfterSuccessReplacesSuccessWithValidation() async {
        let desk = makeOperator(publicId: "desk-1", label: "Main")
        let user = makeUser(permissions: [.manageDeskMemberships])
        configureLoad(user: user, operators: [desk])
        mockAPI.attachViewerToDeskHandler = { _, _ in }
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.viewerUsername = "viewer"
        let firstResult = await viewModel.attachViewer()
        XCTAssertTrue(firstResult)
        XCTAssertTrue(viewModel.attachmentSucceeded)

        let secondResult = await viewModel.attachViewer()
        XCTAssertFalse(secondResult)

        XCTAssertFalse(viewModel.attachmentSucceeded)
        XCTAssertEqual(viewModel.validationErrorKey, "desk.attach.validation.username")
    }
}

private struct DeskAttachmentCall: Equatable, Sendable {
    let operatorPublicId: String
    let username: String
}

private actor DeskAttachmentRecorder {
    private(set) var calls: [DeskAttachmentCall] = []

    func record(operatorPublicId: String, username: String) {
        calls.append(DeskAttachmentCall(
            operatorPublicId: operatorPublicId,
            username: username
        ))
    }
}

private actor DeskLoadGate {
    private let user: UserProfile
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var finishContinuation: CheckedContinuation<Void, Never>?
    private var didStart = false
    private(set) var fetchCount = 0

    init(user: UserProfile) {
        self.user = user
    }

    func fetch() async -> UserProfile {
        fetchCount += 1
        didStart = true
        startedContinuation?.resume()
        startedContinuation = nil
        await withCheckedContinuation { continuation in
            finishContinuation = continuation
        }
        return user
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    func finish() {
        finishContinuation?.resume()
        finishContinuation = nil
    }
}

private actor DeskAttachmentGate {
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var finishContinuation: CheckedContinuation<Void, Never>?
    private var didStart = false
    private(set) var calls: [DeskAttachmentCall] = []

    func attach(operatorPublicId: String, username: String) async {
        calls.append(DeskAttachmentCall(
            operatorPublicId: operatorPublicId,
            username: username
        ))
        didStart = true
        startedContinuation?.resume()
        startedContinuation = nil
        await withCheckedContinuation { continuation in
            finishContinuation = continuation
        }
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    func finish() {
        finishContinuation?.resume()
        finishContinuation = nil
    }
}
