import Foundation
@testable import Snapper

/// Lock-protected, closure-overridable test double for
/// `APIClientProtocol`.
///
/// Established in iOS v0.3.1 alongside the MVVM extraction so VM
/// tests can drive every async branch without going through the URL
/// stack. Each method backs onto a `Sendable` closure slot defaulting
/// to a thrown `APIError.invalidResponse` — tests are explicit about
/// which calls they care about, and any unexpected method call fails
/// loudly instead of silently returning junk.
///
/// Concurrency: `final class @unchecked Sendable` with an
/// `NSLock`-protected backing storage. Reads + writes of every
/// handler slot go through `withLock`, so a ViewModel that fans out
/// via `async let` (e.g. `OrdersViewModel.load()` calling
/// `fetchOrders` + `fetchExecutions` in parallel) cannot race the
/// mock's handler reads. Tests typically configure handlers
/// up-front + leave them static for the rest of the test, but the
/// lock keeps mid-test reconfiguration race-free as well.
///
/// Pattern:
///
///     let mock = MockAPIClient()
///     mock.fetchPositionsHandler = { [PositionSnapshot.fixture] }
///     let viewModel = PositionsViewModel(api: mock, appState: AppState())
///     await viewModel.load()
///     XCTAssertEqual(viewModel.positions.count, 1)
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    /// All mutable handler closures live in a single struct guarded
    /// by `lock`. Generic `read(_:)` / `write(_:_:)` keypath helpers
    /// keep the per-slot getter / setter boilerplate to one line each.
    private struct HandlerStorage {

        var fetchOrders: @Sendable () async throws -> [OrderStatus] = {
            throw APIError.invalidResponse
        }
        var fetchPositions: @Sendable () async throws -> [PositionSnapshot] = {
            throw APIError.invalidResponse
        }
        var fetchAccounts: @Sendable () async throws -> [PortfolioAccountState] = {
            throw APIError.invalidResponse
        }
        var fetchSignals: @Sendable () async throws -> [TradingSignal] = {
            throw APIError.invalidResponse
        }
        var fetchBacktests: @Sendable () async throws -> [BacktestRunData] = {
            throw APIError.invalidResponse
        }
        var fetchProcessSummary: @Sendable () async throws -> ProcessSummaryData = {
            throw APIError.invalidResponse
        }
        var fetchConfiguredProcesses: @Sendable () async throws -> [ConfiguredProcess] = {
            throw APIError.invalidResponse
        }
        var fetchAiReviews: @Sendable () async throws -> [AdminAiReviewItem] = {
            throw APIError.invalidResponse
        }
        var fetchPendingAiReviews: @Sendable () async throws -> PendingReviewListResponse = {
            throw APIError.invalidResponse
        }
        var submitAiReviewDecision: @Sendable (String, AiReviewDecisionIntent, String?) async throws -> AiReviewDecisionResponse = { _, _, _ in
            throw APIError.invalidResponse
        }
        var fetchStrategies: @Sendable () async throws -> [StrategyProcess] = {
            throw APIError.invalidResponse
        }
        var fetchCurrentUser: @Sendable () async throws -> UserProfile = {
            throw APIError.invalidResponse
        }
        var fetchUsers: @Sendable () async throws -> [UserProfile] = {
            throw APIError.invalidResponse
        }
        var attachViewerToDesk: @Sendable (String, String) async throws -> Void = { _, _ in
            throw APIError.invalidResponse
        }
        var fetchDelegates: @Sendable () async throws -> [DelegateRead] = {
            throw APIError.invalidResponse
        }
        var fetchExecutions: @Sendable () async throws -> [ExecutionRecord] = {
            throw APIError.invalidResponse
        }
        var fetchWallets: @Sendable () async throws -> [WalletInfo] = {
            throw APIError.invalidResponse
        }
        var fetchOperators: @Sendable () async throws -> [OperatorInfo] = {
            throw APIError.invalidResponse
        }
        var fetchPnlSeries: @Sendable (String, String, String, Date, Date, String) async throws -> PnlSeriesData = { _, _, _, _, _, _ in
            throw APIError.invalidResponse
        }

        var createOrder: @Sendable (CreateOrderCommand) async throws -> ExecutionPlanResponse = { _ in
            throw APIError.invalidResponse
        }
        var cancelOrder: @Sendable (String, String?) async throws -> ExecutionPlanResponse = { _, _ in
            throw APIError.invalidResponse
        }
        var createBracket: @Sendable (BracketCreateCommand) async throws -> ExecutionPlanResponse = { _ in
            throw APIError.invalidResponse
        }
        var createTrailingStop: @Sendable (TrailingStopCreateCommand) async throws -> ExecutionPlanResponse = { _ in
            throw APIError.invalidResponse
        }

        var startProcess: @Sendable (String, ProcessStartBody) async throws -> ProcessStartData = { _, _ in
            throw APIError.invalidResponse
        }
        var stopProcess: @Sendable (String) async throws -> ProcessStopData = { _ in
            throw APIError.invalidResponse
        }
        var setProcessDesiredState: @Sendable (String, ProcessDesiredStateBody) async throws -> ProcessDesiredStateData = { _, _ in
            throw APIError.invalidResponse
        }

        var fetchInstruments: @Sendable (String) async throws -> [InstrumentDetailData] = { _ in
            throw APIError.invalidResponse
        }
        var fetchExchanges: @Sendable () async throws -> [String] = {
            throw APIError.invalidResponse
        }
        var fetchRelatedInstruments: @Sendable (String, String) async throws -> RelatedInstrumentsResponse = { _, _ in
            throw APIError.invalidResponse
        }
        var updateDefaultLanguage: @Sendable (String) async throws -> Void = { _ in
            throw APIError.invalidResponse
        }
        var fetchCachedCandles: @Sendable (String, String, MarketTimeframe, Int) async throws -> CachedCandlesResponse = { _, _, _, _ in
            throw APIError.invalidResponse
        }
        var fetchAllConfiguredPairStats: @Sendable () async throws -> ListedCachedStatsResponse = {
            throw APIError.invalidResponse
        }
        var fetchCacheHealth: @Sendable () async throws -> CacheHealthResponse = {
            throw APIError.invalidResponse
        }
        var fetchCandles: @Sendable (String, String, MarketTimeframe, Int, Date?) async throws -> [MarketCandle] = { _, _, _, _, _ in
            throw APIError.invalidResponse
        }
        var fetchSystemStatus: @Sendable () async throws -> SystemStatus = {
            throw APIError.invalidResponse
        }
        var fetchHealth: @Sendable () async throws -> HealthCheckResponse = {
            throw APIError.invalidResponse
        }

        var registerDevice: @Sendable (RegisterDeviceCommand) async throws -> NotificationDeviceResponse = { _ in
            throw APIError.invalidResponse
        }

        var fetchAlertHistory: @Sendable (Int?, String?) async throws -> AlertHistoryResponse = { _, _ in
            throw APIError.invalidResponse
        }
        var fetchAlert: @Sendable (String) async throws -> AlertEventResponse = { _ in
            throw APIError.invalidResponse
        }
        var fetchDevicePrefs: @Sendable (String) async throws -> DeviceAlertPrefListResponse = { _ in
            throw APIError.invalidResponse
        }
        var updateDevicePref: @Sendable (String, UpdateDevicePrefCommand) async throws -> DeviceAlertPrefResponse = { _, _ in
            throw APIError.invalidResponse
        }
        var revokeDevicePref: @Sendable (String, String, RevokeDevicePrefCommand) async throws -> RevokeDevicePrefResponse = { _, _, _ in
            throw APIError.invalidResponse
        }
        var fetchAlertDefaults: @Sendable () async throws -> UserAlertDefaultListResponse = {
            throw APIError.invalidResponse
        }
        var updateAlertDefault: @Sendable (UpdateUserAlertDefaultCommand) async throws -> UserAlertDefaultResponse = { _ in
            throw APIError.invalidResponse
        }
    }

    private let lock = NSLock()
    private var storage = HandlerStorage()

    private func read<T>(_ keyPath: KeyPath<HandlerStorage, T>) -> T {
        return lock.withLock { storage[keyPath: keyPath] }
    }

    private func write<T>(_ keyPath: WritableKeyPath<HandlerStorage, T>, _ value: T) {
        lock.withLock { storage[keyPath: keyPath] = value }
    }
    var fetchOrdersHandler: @Sendable () async throws -> [OrderStatus] {
        get { read(\.fetchOrders) }
        set { write(\.fetchOrders, newValue) }
    }
    var fetchPositionsHandler: @Sendable () async throws -> [PositionSnapshot] {
        get { read(\.fetchPositions) }
        set { write(\.fetchPositions, newValue) }
    }
    var fetchAccountsHandler: @Sendable () async throws -> [PortfolioAccountState] {
        get { read(\.fetchAccounts) }
        set { write(\.fetchAccounts, newValue) }
    }
    var fetchSignalsHandler: @Sendable () async throws -> [TradingSignal] {
        get { read(\.fetchSignals) }
        set { write(\.fetchSignals, newValue) }
    }
    var fetchBacktestsHandler: @Sendable () async throws -> [BacktestRunData] {
        get { read(\.fetchBacktests) }
        set { write(\.fetchBacktests, newValue) }
    }
    var fetchProcessSummaryHandler: @Sendable () async throws -> ProcessSummaryData {
        get { read(\.fetchProcessSummary) }
        set { write(\.fetchProcessSummary, newValue) }
    }
    var fetchConfiguredProcessesHandler: @Sendable () async throws -> [ConfiguredProcess] {
        get { read(\.fetchConfiguredProcesses) }
        set { write(\.fetchConfiguredProcesses, newValue) }
    }
    var fetchAiReviewsHandler: @Sendable () async throws -> [AdminAiReviewItem] {
        get { read(\.fetchAiReviews) }
        set { write(\.fetchAiReviews, newValue) }
    }
    var fetchPendingAiReviewsHandler: @Sendable () async throws -> PendingReviewListResponse {
        get { read(\.fetchPendingAiReviews) }
        set { write(\.fetchPendingAiReviews, newValue) }
    }
    var submitAiReviewDecisionHandler: @Sendable (String, AiReviewDecisionIntent, String?) async throws -> AiReviewDecisionResponse {
        get { read(\.submitAiReviewDecision) }
        set { write(\.submitAiReviewDecision, newValue) }
    }
    var fetchStrategiesHandler: @Sendable () async throws -> [StrategyProcess] {
        get { read(\.fetchStrategies) }
        set { write(\.fetchStrategies, newValue) }
    }
    var fetchCurrentUserHandler: @Sendable () async throws -> UserProfile {
        get { read(\.fetchCurrentUser) }
        set { write(\.fetchCurrentUser, newValue) }
    }
    var fetchUsersHandler: @Sendable () async throws -> [UserProfile] {
        get { read(\.fetchUsers) }
        set { write(\.fetchUsers, newValue) }
    }
    var attachViewerToDeskHandler: @Sendable (String, String) async throws -> Void {
        get { read(\.attachViewerToDesk) }
        set { write(\.attachViewerToDesk, newValue) }
    }
    var fetchDelegatesHandler: @Sendable () async throws -> [DelegateRead] {
        get { read(\.fetchDelegates) }
        set { write(\.fetchDelegates, newValue) }
    }
    var fetchExecutionsHandler: @Sendable () async throws -> [ExecutionRecord] {
        get { read(\.fetchExecutions) }
        set { write(\.fetchExecutions, newValue) }
    }
    var fetchWalletsHandler: @Sendable () async throws -> [WalletInfo] {
        get { read(\.fetchWallets) }
        set { write(\.fetchWallets, newValue) }
    }
    var fetchOperatorsHandler: @Sendable () async throws -> [OperatorInfo] {
        get { read(\.fetchOperators) }
        set { write(\.fetchOperators, newValue) }
    }
    var fetchPnlSeriesHandler: @Sendable (String, String, String, Date, Date, String) async throws -> PnlSeriesData {
        get { read(\.fetchPnlSeries) }
        set { write(\.fetchPnlSeries, newValue) }
    }

    var createOrderHandler: @Sendable (CreateOrderCommand) async throws -> ExecutionPlanResponse {
        get { read(\.createOrder) }
        set { write(\.createOrder, newValue) }
    }
    var cancelOrderHandler: @Sendable (String, String?) async throws -> ExecutionPlanResponse {
        get { read(\.cancelOrder) }
        set { write(\.cancelOrder, newValue) }
    }
    var createBracketHandler: @Sendable (BracketCreateCommand) async throws -> ExecutionPlanResponse {
        get { read(\.createBracket) }
        set { write(\.createBracket, newValue) }
    }
    var createTrailingStopHandler: @Sendable (TrailingStopCreateCommand) async throws -> ExecutionPlanResponse {
        get { read(\.createTrailingStop) }
        set { write(\.createTrailingStop, newValue) }
    }

    var startProcessHandler: @Sendable (String, ProcessStartBody) async throws -> ProcessStartData {
        get { read(\.startProcess) }
        set { write(\.startProcess, newValue) }
    }
    var stopProcessHandler: @Sendable (String) async throws -> ProcessStopData {
        get { read(\.stopProcess) }
        set { write(\.stopProcess, newValue) }
    }
    var setProcessDesiredStateHandler: @Sendable (String, ProcessDesiredStateBody) async throws -> ProcessDesiredStateData {
        get { read(\.setProcessDesiredState) }
        set { write(\.setProcessDesiredState, newValue) }
    }

    var fetchInstrumentsHandler: @Sendable (String) async throws -> [InstrumentDetailData] {
        get { read(\.fetchInstruments) }
        set { write(\.fetchInstruments, newValue) }
    }
    var fetchExchangesHandler: @Sendable () async throws -> [String] {
        get { read(\.fetchExchanges) }
        set { write(\.fetchExchanges, newValue) }
    }
    var fetchRelatedInstrumentsHandler: @Sendable (String, String) async throws -> RelatedInstrumentsResponse {
        get { read(\.fetchRelatedInstruments) }
        set { write(\.fetchRelatedInstruments, newValue) }
    }
    var updateDefaultLanguageHandler: @Sendable (String) async throws -> Void {
        get { read(\.updateDefaultLanguage) }
        set { write(\.updateDefaultLanguage, newValue) }
    }
    var fetchCachedCandlesHandler: @Sendable (String, String, MarketTimeframe, Int) async throws -> CachedCandlesResponse {
        get { read(\.fetchCachedCandles) }
        set { write(\.fetchCachedCandles, newValue) }
    }
    var fetchAllConfiguredPairStatsHandler: @Sendable () async throws -> ListedCachedStatsResponse {
        get { read(\.fetchAllConfiguredPairStats) }
        set { write(\.fetchAllConfiguredPairStats, newValue) }
    }
    var fetchCacheHealthHandler: @Sendable () async throws -> CacheHealthResponse {
        get { read(\.fetchCacheHealth) }
        set { write(\.fetchCacheHealth, newValue) }
    }
    var fetchCandlesHandler: @Sendable (String, String, MarketTimeframe, Int, Date?) async throws -> [MarketCandle] {
        get { read(\.fetchCandles) }
        set { write(\.fetchCandles, newValue) }
    }
    var fetchSystemStatusHandler: @Sendable () async throws -> SystemStatus {
        get { read(\.fetchSystemStatus) }
        set { write(\.fetchSystemStatus, newValue) }
    }
    var fetchHealthHandler: @Sendable () async throws -> HealthCheckResponse {
        get { read(\.fetchHealth) }
        set { write(\.fetchHealth, newValue) }
    }

    var registerDeviceHandler: @Sendable (RegisterDeviceCommand) async throws -> NotificationDeviceResponse {
        get { read(\.registerDevice) }
        set { write(\.registerDevice, newValue) }
    }

    var fetchAlertHistoryHandler: @Sendable (Int?, String?) async throws -> AlertHistoryResponse {
        get { read(\.fetchAlertHistory) }
        set { write(\.fetchAlertHistory, newValue) }
    }
    var fetchAlertHandler: @Sendable (String) async throws -> AlertEventResponse {
        get { read(\.fetchAlert) }
        set { write(\.fetchAlert, newValue) }
    }
    var fetchDevicePrefsHandler: @Sendable (String) async throws -> DeviceAlertPrefListResponse {
        get { read(\.fetchDevicePrefs) }
        set { write(\.fetchDevicePrefs, newValue) }
    }
    var updateDevicePrefHandler: @Sendable (String, UpdateDevicePrefCommand) async throws -> DeviceAlertPrefResponse {
        get { read(\.updateDevicePref) }
        set { write(\.updateDevicePref, newValue) }
    }
    var revokeDevicePrefHandler: @Sendable (String, String, RevokeDevicePrefCommand) async throws -> RevokeDevicePrefResponse {
        get { read(\.revokeDevicePref) }
        set { write(\.revokeDevicePref, newValue) }
    }
    var fetchAlertDefaultsHandler: @Sendable () async throws -> UserAlertDefaultListResponse {
        get { read(\.fetchAlertDefaults) }
        set { write(\.fetchAlertDefaults, newValue) }
    }
    var updateAlertDefaultHandler: @Sendable (UpdateUserAlertDefaultCommand) async throws -> UserAlertDefaultResponse {
        get { read(\.updateAlertDefault) }
        set { write(\.updateAlertDefault, newValue) }
    }
    func fetchOrders() async throws -> [OrderStatus] {
        return try await fetchOrdersHandler()
    }

    func fetchPositions() async throws -> [PositionSnapshot] {
        return try await fetchPositionsHandler()
    }

    func fetchAccounts() async throws -> [PortfolioAccountState] {
        return try await fetchAccountsHandler()
    }

    func fetchSignals() async throws -> [TradingSignal] {
        return try await fetchSignalsHandler()
    }

    func fetchBacktests() async throws -> [BacktestRunData] {
        return try await fetchBacktestsHandler()
    }

    func fetchProcessSummary() async throws -> ProcessSummaryData {
        return try await fetchProcessSummaryHandler()
    }

    func fetchConfiguredProcesses() async throws -> [ConfiguredProcess] {
        return try await fetchConfiguredProcessesHandler()
    }

    func fetchAiReviews() async throws -> [AdminAiReviewItem] {
        return try await fetchAiReviewsHandler()
    }

    func fetchPendingAiReviews() async throws -> PendingReviewListResponse {
        return try await fetchPendingAiReviewsHandler()
    }

    func submitAiReviewDecision(
        reviewPublicId: String,
        decision: AiReviewDecisionIntent,
        rationale: String?
    ) async throws -> AiReviewDecisionResponse {
        return try await submitAiReviewDecisionHandler(reviewPublicId, decision, rationale)
    }

    func fetchStrategies() async throws -> [StrategyProcess] {
        return try await fetchStrategiesHandler()
    }

    func fetchCurrentUser() async throws -> UserProfile {
        return try await fetchCurrentUserHandler()
    }

    func fetchUsers() async throws -> [UserProfile] {
        return try await fetchUsersHandler()
    }

    func attachViewerToDesk(operatorPublicId: String, username: String) async throws {
        try await attachViewerToDeskHandler(operatorPublicId, username)
    }

    func fetchDelegates() async throws -> [DelegateRead] {
        return try await fetchDelegatesHandler()
    }

    func fetchExecutions() async throws -> [ExecutionRecord] {
        return try await fetchExecutionsHandler()
    }

    func fetchWallets() async throws -> [WalletInfo] {
        return try await fetchWalletsHandler()
    }

    func fetchOperators() async throws -> [OperatorInfo] {
        return try await fetchOperatorsHandler()
    }

    func fetchPnlSeries(
        walletPublicId: String,
        mode: String,
        granularity: String,
        from: Date,
        to: Date,
        valuationCcy: String
    ) async throws -> PnlSeriesData {
        return try await fetchPnlSeriesHandler(walletPublicId, mode, granularity, from, to, valuationCcy)
    }

    func createOrder(command: CreateOrderCommand) async throws -> ExecutionPlanResponse {
        return try await createOrderHandler(command)
    }

    func cancelOrder(planPublicId: String, reason: String?) async throws -> ExecutionPlanResponse {
        return try await cancelOrderHandler(planPublicId, reason)
    }

    func createBracket(command: BracketCreateCommand) async throws -> ExecutionPlanResponse {
        return try await createBracketHandler(command)
    }

    func createTrailingStop(command: TrailingStopCreateCommand) async throws -> ExecutionPlanResponse {
        return try await createTrailingStopHandler(command)
    }

    func startProcess(name: String, body: ProcessStartBody) async throws -> ProcessStartData {
        return try await startProcessHandler(name, body)
    }

    func stopProcess(name: String) async throws -> ProcessStopData {
        return try await stopProcessHandler(name)
    }

    func setProcessDesiredState(
        name: String,
        body: ProcessDesiredStateBody
    ) async throws -> ProcessDesiredStateData {
        return try await setProcessDesiredStateHandler(name, body)
    }

    func fetchInstruments(exchange: String) async throws -> [InstrumentDetailData] {
        return try await fetchInstrumentsHandler(exchange)
    }

    func fetchExchanges() async throws -> [String] {
        return try await fetchExchangesHandler()
    }

    func fetchRelatedInstruments(exchange: String, symbol: String) async throws -> RelatedInstrumentsResponse {
        return try await fetchRelatedInstrumentsHandler(exchange, symbol)
    }

    func updateDefaultLanguage(_ language: String) async throws {
        try await updateDefaultLanguageHandler(language)
    }

    func fetchCachedCandles(
        exchange: String,
        symbol: String,
        timeframe: MarketTimeframe,
        limit: Int
    ) async throws -> CachedCandlesResponse {
        return try await fetchCachedCandlesHandler(exchange, symbol, timeframe, limit)
    }

    func fetchAllConfiguredPairStats() async throws -> ListedCachedStatsResponse {
        return try await fetchAllConfiguredPairStatsHandler()
    }

    func fetchCacheHealth() async throws -> CacheHealthResponse {
        return try await fetchCacheHealthHandler()
    }

    func fetchCandles(
        exchange: String,
        instrument: String,
        timeframe: MarketTimeframe,
        limit: Int,
        asOf: Date?
    ) async throws -> [MarketCandle] {
        return try await fetchCandlesHandler(exchange, instrument, timeframe, limit, asOf)
    }

    func fetchSystemStatus() async throws -> SystemStatus {
        return try await fetchSystemStatusHandler()
    }

    func fetchHealth() async throws -> HealthCheckResponse {
        return try await fetchHealthHandler()
    }

    func registerDevice(command: RegisterDeviceCommand) async throws -> NotificationDeviceResponse {
        return try await registerDeviceHandler(command)
    }

    func fetchAlertHistory(limit: Int?, before: String?) async throws -> AlertHistoryResponse {
        return try await fetchAlertHistoryHandler(limit, before)
    }

    func fetchAlert(publicId: String) async throws -> AlertEventResponse {
        return try await fetchAlertHandler(publicId)
    }

    func fetchDevicePrefs(devicePublicId: String) async throws -> DeviceAlertPrefListResponse {
        return try await fetchDevicePrefsHandler(devicePublicId)
    }

    func updateDevicePref(
        devicePublicId: String,
        command: UpdateDevicePrefCommand
    ) async throws -> DeviceAlertPrefResponse {
        return try await updateDevicePrefHandler(devicePublicId, command)
    }

    func revokeDevicePref(
        devicePublicId: String,
        prefPublicId: String,
        command: RevokeDevicePrefCommand
    ) async throws -> RevokeDevicePrefResponse {
        return try await revokeDevicePrefHandler(devicePublicId, prefPublicId, command)
    }

    func fetchAlertDefaults() async throws -> UserAlertDefaultListResponse {
        return try await fetchAlertDefaultsHandler()
    }

    func updateAlertDefault(
        command: UpdateUserAlertDefaultCommand
    ) async throws -> UserAlertDefaultResponse {
        return try await updateAlertDefaultHandler(command)
    }
}
