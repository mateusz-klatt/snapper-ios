import Foundation
import Observation
import os

/// ViewModel for ``AdminView`` — the read-only platform-users roster
/// from ``APIClientProtocol/fetchUsers`` (`GET /api/auth/users`), the
/// admin-only "User Management" surface.
///
/// Mirrors ``StrategiesViewModel``: typed error handling, pure ``static``
/// decision helpers. Not wallet-scoped: ``UserProfile`` carries no wallet
/// and the endpoint is admin-permission-scoped server-side, so there is
/// no filter and no ``WalletPicker``. Read-only — the web's create /
/// edit / deactivate / password-reset actions are out of scope for this
/// first cut. Pull-to-refresh only.
@MainActor
@Observable
final class AdminViewModel {

    var users: [UserProfile] = []
    var isLoading: Bool = false
    var loadError: APIError?

    private let api: APIClientProtocol

    private let logger = AppLogger.make(category: "AdminViewModel")

    init(api: APIClientProtocol = APIClient.shared) {
        self.api = api
    }

    /// Username-sorted rows for a stable render order.
    var sortedUsers: [UserProfile] {
        return users.sorted { $0.username < $1.username }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await api.fetchUsers()
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch users: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch users: \(error.localizedDescription, privacy: .public)")
            loadError = .invalidResponse
        }
    }

    /// Surface the "couldn't load" variant only when there is nothing
    /// cached to show and a load has settled.
    static func shouldShowLoadError(
        count: Int,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard loadError != nil else { return false }
        return count == 0
    }

    /// Catalog key for an account's active state. ``isActive`` is an
    /// optional flag; anything other than an explicit ``true`` reads as
    /// inactive.
    static func statusLabelKey(isActive: Bool?) -> String {
        return isActive == true ? "admin.status.active" : "admin.status.inactive"
    }
}
