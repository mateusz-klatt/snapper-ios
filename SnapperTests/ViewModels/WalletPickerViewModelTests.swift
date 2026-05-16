import XCTest
@testable import Snapper

/// Async / instance-state tests for `WalletPickerViewModel`.
///
/// Pure-helper coverage (currentLabel, shouldShowLoadError,
/// walletDisplayName) lives in `Views/WalletPickerTests.swift` and
/// exercises the static surface. The tests here drive the live VM
/// through `loadWallets()` against a deterministic `MockAPIClient`
/// + an ephemeral `AppState` so production `AppState.shared` /
/// `UserDefaults.standard` are never touched.
@MainActor
final class WalletPickerViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
        /// Each test gets a fresh in-memory UserDefaults so wallet
        /// selection writes from one test don't bleed into the next.
        let suiteName = "WalletPickerViewModelTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        appState = AppState(userDefaults: userDefaults)
        /// Pin the locale to ``.us`` so the picker's catalog lookups
        /// resolve to English regardless of the host machine's
        /// preferred-language list. ``.us`` maps to ``CatalogLanguage.en``.
        appState.locale = .us
    }

    override func tearDown() {
        mockAPI = nil
        appState = nil
        super.tearDown()
    }

    private func makeViewModel() -> WalletPickerViewModel {
        return WalletPickerViewModel(api: mockAPI, appState: appState)
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeWallet(
        publicId: String,
        label: String = "main",
        isPaper: Bool = false
    ) -> WalletInfo {
        return WalletInfo(
            type: "wallet_info",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            label: label,
            description: nil,
            isPaper: isPaper
        )
    }

    func testInitialStateHasNoLoadError() {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.loadError)
    }

    func testInitialAvailableWalletsAreEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.availableWallets.isEmpty)
    }

    func testLoadWalletsSuccessPopulatesAppState() async {
        let viewModel = makeViewModel()
        let live = makeWallet(publicId: "p-1", label: "default")
        let paper = makeWallet(publicId: "p-2", label: "default-paper", isPaper: true)
        mockAPI.fetchWalletsHandler = { [live, paper] }
        await viewModel.loadWallets()
        XCTAssertEqual(viewModel.availableWallets.count, 2)
        XCTAssertEqual(appState.availableWallets.count, 2)
        XCTAssertEqual(appState.availableWallets.first?.publicId, "p-1")
        XCTAssertNil(viewModel.loadError)
    }

    /// First-launch UX: no prior wallet selection cached → the
    /// successful load must fall through to the first wallet so
    /// the rest of the app has something to filter on without the
    /// user having to interact with the picker.
    func testLoadWalletsAutoPicksFirstWalletWhenNoSelectionCached() async {
        let viewModel = makeViewModel()
        XCTAssertNil(appState.selectedWalletPublicId)
        let wallets = [
            makeWallet(publicId: "p-first"),
            makeWallet(publicId: "p-second"),
        ]
        mockAPI.fetchWalletsHandler = { wallets }
        await viewModel.loadWallets()
        XCTAssertEqual(appState.selectedWalletPublicId, "p-first")
    }

    /// Returning user with a cached selection — the picker must
    /// preserve their previous pick instead of resetting it to
    /// the first row of the fresh fetch.
    func testLoadWalletsKeepsCachedSelection() async {
        appState.selectedWalletPublicId = "p-cached"
        let viewModel = makeViewModel()
        let wallets: [WalletInfo] = [
            makeWallet(publicId: "p-fresh"),
            makeWallet(publicId: "p-cached"),
        ]
        mockAPI.fetchWalletsHandler = { wallets }
        await viewModel.loadWallets()
        XCTAssertEqual(
            appState.selectedWalletPublicId,
            "p-cached",
            "A cached selection must NOT be replaced by the first row of a fresh fetch"
        )
    }

    /// Empty fetch result with no prior cache: do not fabricate a
    /// selection. The picker capsule then surfaces "Select wallet"
    /// or "Wallets unavailable" depending on the error state.
    func testLoadWalletsEmptyResultLeavesSelectionNil() async {
        let viewModel = makeViewModel()
        mockAPI.fetchWalletsHandler = { [] }
        await viewModel.loadWallets()
        XCTAssertNil(appState.selectedWalletPublicId)
        XCTAssertTrue(appState.availableWallets.isEmpty)
    }

    func testLoadWalletsFailureSetsAPIErrorOnLoadError() async {
        let viewModel = makeViewModel()
        mockAPI.fetchWalletsHandler = {
            throw APIError.httpError(503)
        }
        await viewModel.loadWallets()
        guard case .httpError(let code) = viewModel.loadError else {
            XCTFail("Expected APIError.httpError; got \(String(describing: viewModel.loadError))")
            return
        }
        XCTAssertEqual(code, 503)
    }

    /// A non-`APIError` thrown from the API layer (e.g. a decoder
    /// surfacing `DecodingError`) must funnel into `.invalidResponse`
    /// so the UI presents a single, predictable error variant
    /// instead of leaking a raw Foundation error string.
    func testLoadWalletsNonAPIErrorFallsBackToInvalidResponse() async {
        struct UnexpectedError: Error {}
        let viewModel = makeViewModel()
        mockAPI.fetchWalletsHandler = { throw UnexpectedError() }
        await viewModel.loadWallets()
        guard case .invalidResponse = viewModel.loadError else {
            XCTFail("Expected APIError.invalidResponse; got \(String(describing: viewModel.loadError))")
            return
        }
    }

    /// A successful load AFTER a failure must clear the sticky
    /// error banner. Mirrors the Q9a regression guard pattern from
    /// `NewOrderSheetViewModel`.
    func testLoadWalletsClearsLoadErrorOnRecovery() async {
        let viewModel = makeViewModel()
        mockAPI.fetchWalletsHandler = { throw APIError.httpError(503) }
        await viewModel.loadWallets()
        XCTAssertNotNil(viewModel.loadError)
        let wallet = makeWallet(publicId: "p-recovered")
        mockAPI.fetchWalletsHandler = { [wallet] }
        await viewModel.loadWallets()
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.availableWallets.count, 1)
    }

    func testSelectWalletWritesAppStateSelection() {
        let viewModel = makeViewModel()
        viewModel.selectWallet("p-pick")
        XCTAssertEqual(appState.selectedWalletPublicId, "p-pick")
        XCTAssertEqual(viewModel.selectedWalletPublicId, "p-pick")
    }

    func testSelectWalletReplacesPriorSelection() {
        appState.selectedWalletPublicId = "p-old"
        let viewModel = makeViewModel()
        viewModel.selectWallet("p-new")
        XCTAssertEqual(appState.selectedWalletPublicId, "p-new")
    }

    func testCurrentLabelFromAppStateSnapshot() {
        let viewModel = makeViewModel()
        /// Empty + no error: loading state.
        XCTAssertEqual(viewModel.currentLabel, "Loading wallets...")
        /// Cached wallets + no selection: select-prompt.
        appState.availableWallets = [
            makeWallet(publicId: "p-1", label: "default"),
        ]
        XCTAssertEqual(viewModel.currentLabel, "Select wallet")
        /// Cached wallets + matching selection: the wallet display name.
        appState.selectedWalletPublicId = "p-1"
        XCTAssertEqual(viewModel.currentLabel, "default")
        /// Empty + error state: collapses to "Wallets unavailable".
        appState.availableWallets = []
        appState.selectedWalletPublicId = nil
        viewModel.loadError = .httpError(503)
        XCTAssertEqual(viewModel.currentLabel, "Wallets unavailable")
    }

    func testShouldShowLoadErrorReflectsCachedWalletsAndError() {
        let viewModel = makeViewModel()
        /// No error: never show the error prompt.
        XCTAssertFalse(viewModel.shouldShowLoadError)
        /// Error + no cached wallets: show.
        viewModel.loadError = .httpError(503)
        XCTAssertTrue(viewModel.shouldShowLoadError)
        /// Error + cached wallets: stay quiet (cached data > error).
        appState.availableWallets = [makeWallet(publicId: "p-1")]
        XCTAssertFalse(viewModel.shouldShowLoadError)
    }
}
