import XCTest
@testable import Snapper

@MainActor
final class AccountsViewModelTests: XCTestCase {

    private static let now = Date(timeIntervalSince1970: 1_752_408_000)
    private var mockAPI: MockAPIClient!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
        let suiteName = "AccountsViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        appState = AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["en-US"] }
        )
    }

    override func tearDown() {
        mockAPI = nil
        appState = nil
        super.tearDown()
    }

    private func makeViewModel() -> AccountsViewModel {
        return AccountsViewModel(api: mockAPI, appState: appState, now: { Self.now })
    }

    private func makeAccount(publicId: String, walletPublicId: String?) -> PortfolioAccountState {
        return PortfolioAccountState(
            type: "portfolio_account_state",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.now,
            sessionId: "session-1",
            topic: nil,
            walletPublicId: walletPublicId,
            exchange: "kraken",
            mode: "live",
            syncStatus: "observed",
            effectiveStatus: "observed",
            isAuthoritative: true,
            balanceStatus: "observed",
            positionStatus: "not_applicable",
            valuationStatus: "native_only",
            balances: [],
            openPositions: [],
            balanceObservedAt: Self.now.addingTimeInterval(-60),
            positionObservedAt: nil,
            authoritativeUntil: Self.now.addingTimeInterval(300),
            currentAttemptObservationId: 1,
            balancePayloadSourceObservationId: 1,
            positionPayloadSourceObservationId: nil,
            error: nil
        )
    }

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.accounts.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
        XCTAssertNil(viewModel.lastSuccessfulFetch)
    }

    func testLoadPopulatesAccountsAndFetchClock() async {
        let account = makeAccount(publicId: "acct-1", walletPublicId: "wallet-1")
        mockAPI.fetchAccountsHandler = { [account] }
        let viewModel = makeViewModel()

        await viewModel.load()

        XCTAssertEqual(viewModel.accounts.first?.publicId, "acct-1")
        XCTAssertEqual(viewModel.lastSuccessfulFetch, Self.now)
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testAPILoadFailurePreservesCachedRowsAndFetchClock() async {
        let account = makeAccount(publicId: "acct-1", walletPublicId: "wallet-1")
        mockAPI.fetchAccountsHandler = { [account] }
        let viewModel = makeViewModel()
        await viewModel.load()
        mockAPI.fetchAccountsHandler = { throw APIError.httpError(503) }

        await viewModel.load()

        XCTAssertEqual(viewModel.accounts.count, 1)
        XCTAssertEqual(viewModel.lastSuccessfulFetch, Self.now)
        guard case .httpError(let status) = viewModel.loadError else {
            XCTFail("Expected HTTP error")
            return
        }
        XCTAssertEqual(status, 503)
    }

    func testUnexpectedLoadFailureMapsToInvalidResponse() async {
        struct UnexpectedError: Error {}
        mockAPI.fetchAccountsHandler = { throw UnexpectedError() }
        let viewModel = makeViewModel()

        await viewModel.load()

        guard case .invalidResponse = viewModel.loadError else {
            XCTFail("Expected invalid response")
            return
        }
    }

    func testSuccessfulRecoveryClearsLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchAccountsHandler = { throw APIError.invalidResponse }
        await viewModel.load()
        mockAPI.fetchAccountsHandler = { [] }

        await viewModel.load()

        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.lastSuccessfulFetch, Self.now)
    }

    func testFilteredAccountsUsesWalletScopeAndPassesNilWalletRows() {
        let viewModel = makeViewModel()
        appState.selectedWalletPublicId = "wallet-a"
        viewModel.accounts = [
            makeAccount(publicId: "a", walletPublicId: "wallet-a"),
            makeAccount(publicId: "b", walletPublicId: "wallet-b"),
            makeAccount(publicId: "system", walletPublicId: nil),
        ]

        XCTAssertEqual(Set(viewModel.filteredAccounts.map(\.publicId)), Set(["a", "system"]))
    }

    func testFilterPassesAllWithoutWalletSelection() {
        let accounts = [
            makeAccount(publicId: "a", walletPublicId: "wallet-a"),
            makeAccount(publicId: "b", walletPublicId: "wallet-b"),
        ]

        XCTAssertEqual(AccountsViewModel.filter(
            accounts: accounts,
            selectedWalletPublicId: nil
        ).count, 2)
    }

    func testWalletMatchPolicyMirrorsPositions() {
        XCTAssertTrue(AccountsViewModel.walletMatches(rowWalletId: nil, selected: nil))
        XCTAssertTrue(AccountsViewModel.walletMatches(rowWalletId: nil, selected: "a"))
        XCTAssertTrue(AccountsViewModel.walletMatches(rowWalletId: "a", selected: nil))
        XCTAssertTrue(AccountsViewModel.walletMatches(rowWalletId: "a", selected: "a"))
        XCTAssertFalse(AccountsViewModel.walletMatches(rowWalletId: "b", selected: "a"))
    }

    func testTruthUsesLastSuccessfulFetch() async {
        let account = makeAccount(publicId: "acct-1", walletPublicId: "wallet-1")
        mockAPI.fetchAccountsHandler = { [account] }
        let viewModel = makeViewModel()
        await viewModel.load()

        let truth = viewModel.truth(for: account, at: Self.now)

        XCTAssertTrue(truth.isAuthoritative)
    }

    func testLoadErrorVisibilityOnlyWhenSettledAndEmpty() {
        XCTAssertTrue(AccountsViewModel.shouldShowLoadError(
            filteredCount: 0,
            loadError: .httpError(503),
            isLoading: false
        ))
        XCTAssertFalse(AccountsViewModel.shouldShowLoadError(
            filteredCount: 1,
            loadError: .invalidResponse,
            isLoading: false
        ))
        XCTAssertFalse(AccountsViewModel.shouldShowLoadError(
            filteredCount: 0,
            loadError: .invalidResponse,
            isLoading: true
        ))
        XCTAssertFalse(AccountsViewModel.shouldShowLoadError(
            filteredCount: 0,
            loadError: nil,
            isLoading: false
        ))
    }
}
