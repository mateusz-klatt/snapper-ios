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

    func testRecurringPollRefreshesFetchClockAndKeepsLiveRowAuthoritative() async {
        let account = makeAccount(publicId: "acct-1", walletPublicId: "wallet-1")
        let recorder = AccountFetchRecorder(accounts: [account])
        let sleeper = AccountManualSleeper()
        var currentDate = Self.now
        mockAPI.fetchAccountsHandler = { await recorder.fetch() }
        let viewModel = AccountsViewModel(
            api: mockAPI,
            appState: appState,
            now: { currentDate },
            sleeper: sleeper
        )
        await viewModel.load()

        viewModel.startPollingLiveUpdates()
        await sleeper.waitUntilSleeping()
        currentDate = currentDate.addingTimeInterval(AccountsViewModel.livePollingInterval)
        await sleeper.resume()
        await recorder.waitForFetchCount(2)
        await sleeper.waitUntilSleeping()

        let fetchCount = await recorder.fetchCount
        let requestedIntervals = await sleeper.requestedIntervals
        XCTAssertEqual(fetchCount, 2)
        XCTAssertEqual(requestedIntervals.count, 2)
        XCTAssertTrue(requestedIntervals.allSatisfy {
            $0 == AccountsViewModel.livePollingInterval
        })
        XCTAssertEqual(viewModel.lastSuccessfulFetch, currentDate)
        let truth = viewModel.truth(for: account, at: currentDate)
        XCTAssertTrue(truth.isAuthoritative)
        XCTAssertFalse(truth.pollingStalled)

        viewModel.stopPollingLiveUpdates()
        viewModel.stopPollingLiveUpdates()
        await sleeper.resume()
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

private actor AccountFetchRecorder {
    private let accounts: [PortfolioAccountState]
    private(set) var fetchCount = 0
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    init(accounts: [PortfolioAccountState]) {
        self.accounts = accounts
    }

    func fetch() -> [PortfolioAccountState] {
        fetchCount += 1
        let ready = waiters.filter { fetchCount >= $0.0 }
        waiters.removeAll { fetchCount >= $0.0 }
        ready.forEach { $0.1.resume() }
        return accounts
    }

    func waitForFetchCount(_ count: Int) async {
        guard fetchCount < count else { return }
        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }
}

private actor AccountManualSleeper: Sleeper {
    private var sleepContinuation: CheckedContinuation<Void, Never>?
    private var waitingContinuation: CheckedContinuation<Void, Never>?
    private var isSleeping = false
    private(set) var requestedIntervals: [TimeInterval] = []

    func sleep(seconds: TimeInterval) async throws {
        precondition(sleepContinuation == nil, "AccountManualSleeper only supports one active sleep")
        requestedIntervals.append(seconds)
        isSleeping = true
        waitingContinuation?.resume()
        waitingContinuation = nil
        await withCheckedContinuation { continuation in
            sleepContinuation = continuation
        }
    }

    func waitUntilSleeping() async {
        if isSleeping {
            return
        }
        await withCheckedContinuation { continuation in
            precondition(waitingContinuation == nil, "AccountManualSleeper only supports one pending wait")
            waitingContinuation = continuation
        }
    }

    func resume() {
        guard isSleeping else { return }
        isSleeping = false
        let continuation = sleepContinuation
        sleepContinuation = nil
        continuation?.resume()
    }
}
