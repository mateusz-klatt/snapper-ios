import Foundation
import Observation
import os

/// A server-scoped desk prepared for presentation in ``DeskView``.
struct AccessibleDesk: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let description: String?
    let isPrimary: Bool
}

/// Loads the caller's accessible desks and owns the viewer-attachment form.
///
/// Desk visibility is entirely server-scoped. The client never expands the
/// result based on role: admins receive every desk from `fetchOperators`, while
/// operators and viewers receive only the desks the backend authorizes. The
/// mutation form is separately fail-closed behind the effective
/// `manage:desk_memberships` capability returned by `/auth/me`.
@MainActor
@Observable
final class DeskViewModel {

    private(set) var desks: [AccessibleDesk] = []
    private(set) var canManageMemberships = false
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var loadError: APIError?

    var viewerUsername = "" {
        didSet {
            guard viewerUsername != oldValue else { return }
            clearAttachmentFeedback()
        }
    }

    var selectedDeskPublicId: String? {
        didSet {
            guard selectedDeskPublicId != oldValue else { return }
            clearAttachmentFeedback()
        }
    }

    private(set) var isAttaching = false
    private(set) var attachmentSucceeded = false
    private(set) var attachmentError: APIError?
    private(set) var validationErrorKey: String?

    private let api: APIClientProtocol
    private let logger = AppLogger.make(category: "DeskViewModel")

    init(api: APIClientProtocol = APIClient.shared) {
        self.api = api
    }

    /// Whether the form may start a request. Username validation deliberately
    /// happens on submit so an empty field can produce actionable feedback.
    var canAttemptAttachment: Bool {
        guard canManageMemberships, !isAttaching else { return false }
        guard let selectedDeskPublicId else { return false }
        return desks.contains { $0.id == selectedDeskPublicId }
    }

    /// Stable UI-test signal for the catalogue request lifecycle.
    var loadStateAccessibilityIdentifier: String {
        if !hasLoaded {
            return "desk.state.loading"
        }
        if isLoading {
            return "desk.state.refreshing"
        }
        if loadError != nil {
            return "desk.state.failed"
        }
        return desks.isEmpty ? "desk.state.loaded.empty" : "desk.state.loaded.content"
    }

    /// Fetch the caller and their server-filtered desk catalogue together.
    /// Concurrent invocations collapse while a load is already in flight.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            async let userRequest = api.fetchCurrentUser()
            async let deskRequest = api.fetchOperators()
            let (user, operators) = try await (userRequest, deskRequest)
            let joinedDesks = Self.join(
                operators: operators,
                primaryOperatorPublicId: user.primaryOperatorPublicId
            )
            desks = joinedDesks
            canManageMemberships = Self.canManageMemberships(user: user)
            selectedDeskPublicId = Self.preferredSelection(
                current: selectedDeskPublicId,
                desks: joinedDesks
            )
            loadError = nil
        } catch let error as APIError {
            desks = []
            selectedDeskPublicId = nil
            canManageMemberships = false
            loadError = error
            logger.error("Failed to load desks: \(error.localizedDescription, privacy: .public)")
        } catch {
            desks = []
            selectedDeskPublicId = nil
            canManageMemberships = false
            loadError = .invalidResponse
            logger.error("Failed to load desks: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Attach the exact viewer username to the selected desk.
    ///
    /// The in-flight guard collapses a double tap into one request. A failed
    /// request preserves both form values for retry; a successful request clears
    /// the username and leaves a re-login notice visible.
    @discardableResult
    func attachViewer() async -> Bool {
        guard canAttemptAttachment else { return false }
        guard let username = Self.normalizedUsername(viewerUsername) else {
            clearAttachmentFeedback()
            validationErrorKey = "desk.attach.validation.username"
            return false
        }
        guard let operatorPublicId = selectedDeskPublicId else { return false }

        isAttaching = true
        attachmentSucceeded = false
        attachmentError = nil
        validationErrorKey = nil
        defer { isAttaching = false }

        do {
            try await api.attachViewerToDesk(
                operatorPublicId: operatorPublicId,
                username: username
            )
            viewerUsername = ""
            attachmentSucceeded = true
            return true
        } catch let error as APIError {
            attachmentError = error
            logger.error("Failed to attach viewer to desk: \(error.localizedDescription, privacy: .public)")
            return false
        } catch {
            attachmentError = .invalidResponse
            logger.error("Failed to attach viewer to desk: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func canManageMemberships(user: UserProfile) -> Bool {
        return user.effectivePermissions?.contains(.manageDeskMemberships) == true
    }

    static func normalizedUsername(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Preserve actionable backend validation details while keeping transport
    /// and decoding failures behind localized generic copy.
    static func attachmentServerDetail(for error: APIError?) -> String? {
        guard case .serverError(let detail) = error else { return nil }
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func join(
        operators: [OperatorInfo],
        primaryOperatorPublicId: String?
    ) -> [AccessibleDesk] {
        return operators
            .map { desk in
                AccessibleDesk(
                    id: desk.publicId,
                    label: desk.label,
                    description: normalizedDescription(desk.description),
                    isPrimary: desk.publicId == primaryOperatorPublicId
                )
            }
            .sorted(by: deskComesBefore)
    }

    static func shouldShowLoadError(
        deskCount: Int,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        return deskCount == 0 && loadError != nil && !isLoading
    }

    private static func preferredSelection(
        current: String?,
        desks: [AccessibleDesk]
    ) -> String? {
        if let current, desks.contains(where: { $0.id == current }) {
            return current
        }
        return desks.first(where: \.isPrimary)?.id ?? desks.first?.id
    }

    private static func normalizedDescription(_ description: String?) -> String? {
        guard let description else { return nil }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func deskComesBefore(_ lhs: AccessibleDesk, _ rhs: AccessibleDesk) -> Bool {
        if lhs.isPrimary != rhs.isPrimary {
            return lhs.isPrimary
        }
        let labelOrder = lhs.label.localizedCaseInsensitiveCompare(rhs.label)
        if labelOrder == .orderedSame {
            return lhs.id < rhs.id
        }
        return labelOrder == .orderedAscending
    }

    private func clearAttachmentFeedback() {
        attachmentSucceeded = false
        attachmentError = nil
        validationErrorKey = nil
    }
}
