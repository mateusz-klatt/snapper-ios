import Foundation
@testable import Snapper

/// Closure-overridable test double for `APIClientProtocol`.
///
/// Established in iOS v0.3.1 alongside the MVVM extraction so VM
/// tests can drive every async branch without going through the URL
/// stack. Each method backs onto a `Sendable` closure slot defaulting
/// to a thrown `APIError.invalidResponse` — tests are explicit about
/// which calls they care about, and any unexpected method call fails
/// loudly instead of silently returning junk.
///
/// `actor`-backed slot mutation lets tests record call counts /
/// arguments across concurrent `async let` fan-out without a data
/// race. The protocol signatures themselves stay `nonisolated` to
/// match `APIClientProtocol`'s `Sendable` shape.
///
/// Pattern:
///     let mock = MockAPIClient()
///     mock.fetchPositionsHandler = { [PositionSnapshot.fixture] }
///     let viewModel = PositionsViewModel(api: mock, appState: AppState())
///     await viewModel.load()
///     XCTAssertEqual(viewModel.positions.count, 1)
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    // MARK: - Handler slots

    var fetchOrdersHandler: @Sendable () async throws -> [OrderStatus] = {
        throw APIError.invalidResponse
    }
    var fetchPositionsHandler: @Sendable () async throws -> [PositionSnapshot] = {
        throw APIError.invalidResponse
    }
    var fetchSignalsHandler: @Sendable () async throws -> [TradingSignal] = {
        throw APIError.invalidResponse
    }
    var fetchExecutionsHandler: @Sendable () async throws -> [ExecutionRecord] = {
        throw APIError.invalidResponse
    }
    var fetchWalletsHandler: @Sendable () async throws -> [WalletInfo] = {
        throw APIError.invalidResponse
    }
    var fetchOperatorsHandler: @Sendable () async throws -> [OperatorInfo] = {
        throw APIError.invalidResponse
    }

    var createOrderHandler: @Sendable (CreateOrderCommand) async throws -> ExecutionPlanResponse = { _ in
        throw APIError.invalidResponse
    }
    var cancelOrderHandler: @Sendable (String, String?) async throws -> ExecutionPlanResponse = { _, _ in
        throw APIError.invalidResponse
    }
    var createBracketHandler: @Sendable (BracketCreateCommand) async throws -> ExecutionPlanResponse = { _ in
        throw APIError.invalidResponse
    }
    var createTrailingStopHandler: @Sendable (TrailingStopCreateCommand) async throws -> ExecutionPlanResponse = { _ in
        throw APIError.invalidResponse
    }

    var fetchInstrumentsHandler: @Sendable (String) async throws -> [InstrumentDetailData] = { _ in
        throw APIError.invalidResponse
    }
    var fetchSystemStatusHandler: @Sendable () async throws -> SystemStatus = {
        throw APIError.invalidResponse
    }
    var fetchHealthHandler: @Sendable () async throws -> HealthCheckResponse = {
        throw APIError.invalidResponse
    }

    var registerDeviceHandler: @Sendable (RegisterDeviceCommand) async throws -> NotificationDeviceResponse = { _ in
        throw APIError.invalidResponse
    }

    var fetchAlertHistoryHandler: @Sendable (Int?, String?) async throws -> AlertHistoryResponse = { _, _ in
        throw APIError.invalidResponse
    }
    var fetchAlertHandler: @Sendable (String) async throws -> AlertEventResponse = { _ in
        throw APIError.invalidResponse
    }
    var fetchDevicePrefsHandler: @Sendable (String) async throws -> DeviceAlertPrefListResponse = { _ in
        throw APIError.invalidResponse
    }
    var updateDevicePrefHandler: @Sendable (String, UpdateDevicePrefCommand) async throws -> DeviceAlertPrefResponse = { _, _ in
        throw APIError.invalidResponse
    }
    var fetchAlertDefaultsHandler: @Sendable () async throws -> UserAlertDefaultListResponse = {
        throw APIError.invalidResponse
    }
    var updateAlertDefaultHandler: @Sendable (UpdateUserAlertDefaultCommand) async throws -> UserAlertDefaultResponse = { _ in
        throw APIError.invalidResponse
    }

    // MARK: - APIClientProtocol

    func fetchOrders() async throws -> [OrderStatus] {
        return try await fetchOrdersHandler()
    }

    func fetchPositions() async throws -> [PositionSnapshot] {
        return try await fetchPositionsHandler()
    }

    func fetchSignals() async throws -> [TradingSignal] {
        return try await fetchSignalsHandler()
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

    func fetchInstruments(exchange: String) async throws -> [InstrumentDetailData] {
        return try await fetchInstrumentsHandler(exchange)
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

    func fetchAlertDefaults() async throws -> UserAlertDefaultListResponse {
        return try await fetchAlertDefaultsHandler()
    }

    func updateAlertDefault(
        command: UpdateUserAlertDefaultCommand
    ) async throws -> UserAlertDefaultResponse {
        return try await updateAlertDefaultHandler(command)
    }
}
