import Foundation

/// Protocol seam over `APIClient` for ViewModel-level test injection.
///
/// Established in iOS v0.3.1 as part of the MVVM extraction —
/// see `docs/architecture-mvvm.md` for the design rules.
/// Every release-critical ViewModel takes an `APIClientProtocol` via
/// init so tests can inject a deterministic `MockAPIClient` without
/// going through the URL stack. The existing `APIClientNetworkTests`
/// keep using `URLProtocol` interception against the concrete
/// `APIClient` to verify the JSON encode / decode contract end-to-end.
///
/// `Sendable` is required so the protocol can cross actor isolation
/// boundaries — VMs are `@MainActor`, but `MockAPIClient` may be a
/// value type captured by detached tasks during concurrency tests.
///
/// All methods mirror the concrete `APIClient` signatures verbatim.
/// Adding a new endpoint to `APIClient` requires the same line here
/// so VM tests can mock it; the small bookkeeping cost is the price
/// of having a single, audit-friendly view of the network surface.
protocol APIClientProtocol: Sendable {

    func fetchOrders() async throws -> [OrderStatus]
    func fetchPositions() async throws -> [PositionSnapshot]
    func fetchSignals() async throws -> [TradingSignal]
    func fetchExecutions() async throws -> [ExecutionRecord]
    func fetchWallets() async throws -> [WalletInfo]
    func fetchOperators() async throws -> [OperatorInfo]

    func createOrder(command: CreateOrderCommand) async throws -> ExecutionPlanResponse
    func cancelOrder(planPublicId: String, reason: String?) async throws -> ExecutionPlanResponse
    func createBracket(command: BracketCreateCommand) async throws -> ExecutionPlanResponse
    func createTrailingStop(command: TrailingStopCreateCommand) async throws -> ExecutionPlanResponse

    func fetchInstruments(exchange: String) async throws -> [InstrumentDetailData]
    func fetchExchanges() async throws -> [String]
    func fetchRelatedInstruments(exchange: String, symbol: String) async throws -> RelatedInstrumentsResponse
    func updateDefaultLanguage(_ language: String) async throws
    func fetchCandles(
        exchange: String,
        instrument: String,
        timeframe: MarketTimeframe,
        limit: Int,
        asOf: Date?
    ) async throws -> [MarketCandle]
    func fetchSystemStatus() async throws -> SystemStatus
    func fetchHealth() async throws -> HealthCheckResponse

    func registerDevice(command: RegisterDeviceCommand) async throws -> NotificationDeviceResponse

    func fetchAlertHistory(limit: Int?, before: String?) async throws -> AlertHistoryResponse
    func fetchAlert(publicId: String) async throws -> AlertEventResponse
    func fetchDevicePrefs(devicePublicId: String) async throws -> DeviceAlertPrefListResponse
    func updateDevicePref(
        devicePublicId: String,
        command: UpdateDevicePrefCommand
    ) async throws -> DeviceAlertPrefResponse
    func revokeDevicePref(
        devicePublicId: String,
        prefPublicId: String,
        command: RevokeDevicePrefCommand
    ) async throws -> RevokeDevicePrefResponse
    func fetchAlertDefaults() async throws -> UserAlertDefaultListResponse
    func updateAlertDefault(
        command: UpdateUserAlertDefaultCommand
    ) async throws -> UserAlertDefaultResponse
}
