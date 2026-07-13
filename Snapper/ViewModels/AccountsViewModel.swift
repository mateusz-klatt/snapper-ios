import Foundation
import Observation
import os

/// Read-only venue-account state for ``AccountsView``.
@MainActor
@Observable
final class AccountsViewModel {

    var accounts: [PortfolioAccountState] = []
    var isLoading = false
    var loadError: APIError?
    private(set) var lastSuccessfulFetch: Date?

    private let api: APIClientProtocol
    private let appState: AppState
    private let now: () -> Date
    private let logger = AppLogger.make(category: "AccountsViewModel")

    init(
        api: APIClientProtocol = APIClient.shared,
        appState: AppState = .shared,
        now: @escaping () -> Date = { Date() }
    ) {
        self.api = api
        self.appState = appState
        self.now = now
    }

    var filteredAccounts: [PortfolioAccountState] {
        return Self.filter(
            accounts: accounts,
            selectedWalletPublicId: appState.selectedWalletPublicId
        )
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            accounts = try await api.fetchAccounts()
            lastSuccessfulFetch = now()
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch venue accounts: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch venue accounts: \(error.localizedDescription, privacy: .public)")
            loadError = .invalidResponse
        }
    }

    func truth(for account: PortfolioAccountState, at date: Date) -> AccountTruth {
        return AccountTruth.derive(
            state: account,
            now: date,
            lastSuccessfulFetch: lastSuccessfulFetch
        )
    }

    static func walletMatches(rowWalletId: String?, selected: String?) -> Bool {
        guard let selected else { return true }
        guard let rowWalletId else { return true }
        return rowWalletId == selected
    }

    static func filter(
        accounts: [PortfolioAccountState],
        selectedWalletPublicId: String?
    ) -> [PortfolioAccountState] {
        return accounts.filter { account in
            walletMatches(
                rowWalletId: account.walletPublicId,
                selected: selectedWalletPublicId
            )
        }
    }

    static func shouldShowLoadError(
        filteredCount: Int,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard loadError != nil else { return false }
        return filteredCount == 0
    }
}
