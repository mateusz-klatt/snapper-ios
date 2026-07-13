import Foundation

final class APIClient: Sendable, APIClientProtocol {
    @MainActor static let shared = APIClient(session: .shared, authService: AuthService.shared)

    private let session: URLSession
    private let authService: AuthRefreshing
    private let apiBaseURLProvider: @Sendable () -> String

    init(
        session: URLSession,
        authService: AuthRefreshing,
        apiBaseURLProvider: @Sendable @escaping () -> String = { AppConfig.apiBaseURL }
    ) {
        self.session = session
        self.authService = authService
        self.apiBaseURLProvider = apiBaseURLProvider
    }

    /// Percent-encode a value for safe inclusion as a URL path segment.
    ///
    /// Used at every path interpolation site (publicIds, opaque ids,
    /// venue names) so reserved characters do not silently produce
    /// malformed URLs. Falls back to the raw segment only on the
    /// (theoretical) case where the encoder fails.
    private static func encodePathSegment(_ value: String) -> String {
        return value.addingPercentEncoding(withAllowedCharacters: rfc3986Unreserved) ?? value
    }

    private struct QueryParameter {
        let name: String
        let value: String
    }

    /// Build the trailing query suffix from name/value pairs.
    ///
    /// Encodes query names and values against the RFC 3986 unreserved
    /// set so reserved characters in values (e.g. ``+``, ``=``, ``/``
    /// in opaque server-emitted cursors) are always percent-escaped.
    /// Returns the empty string when no items are supplied so callers
    /// can concatenate unconditionally.
    private static func querySuffix(_ items: [QueryParameter]) -> String {
        guard !items.isEmpty else {
            return ""
        }
        let query = items.map { item in
            let name = item.name.addingPercentEncoding(withAllowedCharacters: rfc3986Unreserved) ?? item.name
            let encodedValue = item.value.addingPercentEncoding(withAllowedCharacters: rfc3986Unreserved) ?? item.value
            return "\(name)=\(encodedValue)"
        }.joined(separator: "&")
        return "?\(query)"
    }

    private static let rfc3986Unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    /// Attach the ``X-CSRF-Token`` header for state-changing requests.
    ///
    /// The backend's cookie-auth path requires double-submit CSRF
    /// (``csrf_token`` cookie value mirrored into ``X-CSRF-Token``
    /// header) on every non-safe HTTP method — see
    /// ``snapper.auth.dependencies.validate_csrf_token``. Login,
    /// refresh, and logout are explicitly exempt server-side and do
    /// not flow through this client.
    ///
    /// Cookie lookup is scoped to the request URL via
    /// ``HTTPCookieStorage.cookies(for:)`` so a stale cookie from a
    /// different host (e.g. mid backend-switch) does not leak into a
    /// new-host request. Absent or unmatched cookie → header is left
    /// off and the backend returns its native 403, which surfaces the
    /// missing-CSRF condition rather than masking it with a synthetic
    /// header.
    static func attachCSRFHeader(to request: inout URLRequest, method: String) {
        guard !Self.isSafeMethod(method) else { return }
        guard let url = request.url else { return }
        let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
        guard let csrf = cookies.first(where: { $0.name == AppConfig.CookieName.csrfToken }) else { return }
        guard !csrf.value.isEmpty else { return }
        request.setValue(csrf.value, forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken)
    }

    private static func isSafeMethod(_ method: String) -> Bool {
        let upper = method.uppercased()
        return upper == "GET" || upper == "HEAD"
    }

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        isRetry: Bool = false
    ) async throws -> T {
        guard let url = URL(string: "\(apiBaseURLProvider())\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(AppConfig.ContentType.json, forHTTPHeaderField: AppConfig.HTTPHeader.contentType)

        Self.attachCSRFHeader(to: &request, method: method)

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            /// ISO-8601 mirrors the response decoder set below at line ~63;
            /// Codable Date fields (e.g. DeviceAlertPrefBody.mute_until)
            /// would otherwise serialize as numeric Unix timestamps and
            /// decode to a wrong instant on the backend.
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        /// 401 retry path: refresh ws_token exactly once, then replay.
        /// Second 401 → force logout so the UI routes to LoginView via
        /// SnapperApp's isAuthenticated observer.
        if httpResponse.statusCode == 401 {
            if isRetry {
                await authService.logout()
                throw APIError.httpError(401)
            }
            guard await authService.fetchFreshWsToken() != nil else {
                await authService.logout()
                throw APIError.httpError(401)
            }
            return try await self.request(endpoint: endpoint, method: method, body: body, isRetry: true)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.detail)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(T.self, from: data)
    }

    /// Variant of ``request(endpoint:)`` whose ``JSONDecoder``
    /// accepts ISO 8601 timestamps with OR without fractional
    /// seconds. The default ``request`` uses ``.iso8601`` which is
    /// strict against the bare RFC 3339 grammar; candle envelopes
    /// and ``CandleData`` rows can ship fractional precision
    /// because they originate from the same dispatch path that
    /// serializes WS frames.
    ///
    /// Two ``ISO8601DateFormatter`` instances are tried in order:
    /// first with ``.withFractionalSeconds``, then without. A
    /// malformed string throws ``DecodingError`` so the test in
    /// ``APIClientMarketTests`` can pin the negative path.
    private func requestWithFractionalSecondsDates<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        isRetry: Bool = false
    ) async throws -> T {
        guard let url = URL(string: "\(apiBaseURLProvider())\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(AppConfig.ContentType.json, forHTTPHeaderField: AppConfig.HTTPHeader.contentType)
        Self.attachCSRFHeader(to: &request, method: method)

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            if isRetry {
                await authService.logout()
                throw APIError.httpError(401)
            }
            guard await authService.fetchFreshWsToken() != nil else {
                await authService.logout()
                throw APIError.httpError(401)
            }
            return try await self.requestWithFractionalSecondsDates(
                endpoint: endpoint, method: method, body: body, isRetry: true
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.detail)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(SnapperJSON.decodeFractionalOrPlainISO8601)
        return try decoder.decode(T.self, from: data)
    }

    func fetchOrders() async throws -> [OrderStatus] {
        let envelope: OrderListResponse = try await request(endpoint: AppConfig.Endpoints.orders)
        return envelope.payload
    }

    func fetchPositions() async throws -> [PositionSnapshot] {
        let envelope: PositionListResponse = try await request(endpoint: AppConfig.Endpoints.positions)
        return envelope.payload
    }

    func fetchAccounts() async throws -> [PortfolioAccountState] {
        let envelope: PortfolioAccountStateListResponse = try await request(endpoint: AppConfig.Endpoints.accounts)
        return envelope.payload
    }

    func fetchSignals() async throws -> [TradingSignal] {
        let envelope: SignalListResponse = try await request(endpoint: AppConfig.Endpoints.signals)
        return envelope.payload
    }

    func fetchBacktests() async throws -> [BacktestRunData] {
        let envelope: BacktestRunListResponse = try await request(endpoint: AppConfig.Endpoints.backtests)
        return envelope.payload
    }

    func fetchProcessSummary() async throws -> ProcessSummaryData {
        let envelope: ProcessSummaryResponse = try await request(endpoint: AppConfig.Endpoints.processSummary)
        return envelope.payload
    }

    func fetchAiReviews() async throws -> [AdminAiReviewItem] {
        let envelope: AdminAiReviewListResponse = try await request(endpoint: AppConfig.Endpoints.aiReviews)
        return envelope.items
    }

    func fetchStrategies() async throws -> [StrategyProcess] {
        let envelope: StrategyListResponse = try await request(endpoint: AppConfig.Endpoints.strategies)
        return envelope.payload
    }

    func fetchUsers() async throws -> [UserProfile] {
        let envelope: UserListResponse = try await request(endpoint: AppConfig.Endpoints.users)
        return envelope.payload
    }

    func fetchDelegates() async throws -> [DelegateRead] {
        let envelope: DelegateListResponse = try await request(endpoint: AppConfig.Endpoints.delegates)
        return envelope.payload
    }

    func fetchExecutions() async throws -> [ExecutionRecord] {
        let envelope: ExecutionListResponse = try await request(endpoint: AppConfig.Endpoints.executions)
        return envelope.payload
    }

    /// Fetch wallets visible to the current user (backend
    /// ``GET /api/wallets``).
    ///
    /// Powers ``WalletPicker``. Returns the full list; the picker
    /// caches it on ``AppState.availableWallets`` and surfaces every
    /// row in the menu — backend already filters to the wallets the
    /// user has access to via SCD2 grants.
    func fetchWallets() async throws -> [WalletInfo] {
        let envelope: WalletListResponse = try await request(endpoint: AppConfig.Endpoints.wallets)
        return envelope.payload
    }

    /// Fetch operators the caller may act AS (multi-tenant).
    ///
    /// Powers ``EditDevicePrefView``'s scope picker — operator scope
    /// AND wallet scope (the latter requires an accompanying
    /// operator per the backend ``ck_device_alert_valid_scope``
    /// CHECK constraint). Backend filters by
    /// ``principal.operator_public_ids`` for non-admin roles; admins
    /// get every active operator.
    func fetchOperators() async throws -> [OperatorInfo] {
        let envelope: OperatorListResponse = try await request(
            endpoint: AppConfig.Endpoints.operators
        )
        return envelope.payload
    }

    /// Submit a manual order via the existing ``POST /api/orders``
    /// route.
    ///
    /// Used by ``PositionsView`` to fire reduce / close actions and
    /// by ``NewOrderSheet`` to enter fresh orders — the caller
    /// builds a ``CreateOrderCommand`` from ``EnvelopeMinter``.
    /// Backend routes into the existing trade-command machinery; the
    /// response carries the spawned ``ExecutionPlanData`` so the UI
    /// can confirm the submission succeeded.
    func createOrder(command: CreateOrderCommand) async throws -> ExecutionPlanResponse {
        return try await request(
            endpoint: AppConfig.Endpoints.orders,
            method: "POST",
            body: command
        )
    }

    /// Cancel a live execution plan via
    /// ``POST /api/orders/{plan_public_id}/cancel``. Backend
    /// transitions the plan to ``cancel_requested`` and emits a
    /// venue-facing cancel command for the active child order.
    func cancelOrder(planPublicId: String, reason: String? = nil) async throws -> ExecutionPlanResponse {
        let provenance = await MainActor.run {
            EnvelopeMinter.shared.next(.control)
        }
        let command = CancelOrderCommand(
            type: "cancel_order_command",
            sequenceId: provenance.sequenceId,
            publicId: provenance.publicId,
            timestamp: provenance.timestamp,
            sessionId: provenance.sessionId,
            topic: nil,
            payload: CancelOrderBody(reason: reason)
        )
        return try await request(
            endpoint: "\(AppConfig.Endpoints.orders)/\(Self.encodePathSegment(planPublicId))/cancel",
            method: "POST",
            body: command
        )
    }

    /// Attach a stop-loss / take-profit bracket to a live position
    /// cycle via ``POST /api/execution-plans`` (the bracket creation
    /// route lives on the execution-plans router per
    /// ``snapper.server.execution_plan_routes``).
    func createBracket(command: BracketCreateCommand) async throws -> ExecutionPlanResponse {
        return try await request(
            endpoint: AppConfig.Endpoints.executionPlans,
            method: "POST",
            body: command
        )
    }

    /// Attach a trailing-stop plan to a live position cycle via
    /// ``POST /api/trailing-stops``. Backend validates the cycle is
    /// open, the venue supports ``reduce_only``, and ``trailing_pct``
    /// falls within configured bounds before spawning the plan.
    func createTrailingStop(command: TrailingStopCreateCommand) async throws -> ExecutionPlanResponse {
        return try await request(
            endpoint: AppConfig.Endpoints.trailingStops,
            method: "POST",
            body: command
        )
    }

    /// Fetch capability-aware instrument rows for a venue via
    /// ``GET /api/exchanges/{exchange}/instruments/detail``. Each
    /// row carries ``can_trade``, ``can_market_data``, and
    /// ``instrument_kind`` so order-entry can disable rows the
    /// venue treats as market-data-only (TradFi mirrors).
    func fetchInstruments(exchange: String) async throws -> [InstrumentDetailData] {
        let envelope: InstrumentDetailListResponse = try await request(
            endpoint: "/exchanges/\(Self.encodePathSegment(exchange))/instruments/detail"
        )
        return envelope.payload
    }

    /// Fetch the list of exchange names registered server-side via
    /// ``GET /api/exchanges``. The envelope's ``payload`` is a
    /// ``[String]`` of names (kraken, paper, kraken_futures,
    /// walutomat, polygon) — these are the same values the
    /// ``/exchanges/{exchange}/instruments/detail`` path segment
    /// accepts.
    func fetchExchanges() async throws -> [String] {
        let envelope: ExchangeListResponse = try await request(endpoint: "/exchanges")
        return envelope.payload
    }

    /// Fetch the cached-candles envelope for a given venue/symbol/
    /// timeframe via ``GET /api/candles/cache``. Returns the same
    /// OHLCV shape as ``fetchCandles`` but the envelope also carries
    /// cache-warming metadata (``sample_count`` / ``is_warm`` /
    /// ``source``) the metrics surfaces use to render a warming
    /// banner. Mirrors the web ``getCachedCandles`` client + backend
    /// route contract; the ``timeframe`` rawValue (``"1m"`` /
    /// ``"1h"`` / …) flows through verbatim as the query parameter.
    func fetchCachedCandles(
        exchange: String,
        symbol: String,
        timeframe: MarketTimeframe,
        limit: Int
    ) async throws -> CachedCandlesResponse {
        let items = [
            QueryParameter(name: "instrument", value: symbol),
            QueryParameter(name: "exchange", value: exchange),
            QueryParameter(name: "timeframe", value: timeframe.rawValue),
            QueryParameter(name: "limit", value: String(limit)),
        ]
        let path = "/candles/cache\(Self.querySuffix(items))"
        return try await request(endpoint: path)
    }

    /// Fetch the configured-pair cointegration stats list via
    /// ``GET /api/market/cache/stats/configured``. Used by the pair
    /// stats row to render cointegration chips for every pair the
    /// operator has configured.
    func fetchAllConfiguredPairStats() async throws -> ListedCachedStatsResponse {
        return try await request(endpoint: "/market/cache/stats/configured")
    }

    /// Fetch the cache-warming health snapshot via
    /// ``GET /api/market/cache/health``. Not consumed by the
    /// initial Phase 3 UI surface but added so the
    /// ``APIClientProtocol`` mirrors every backend cache endpoint
    /// for future operator-facing health dashboards.
    func fetchCacheHealth() async throws -> CacheHealthResponse {
        return try await request(endpoint: "/market/cache/health")
    }

    /// Fetch the related-instruments catalog for a given venue-scoped
    /// ticker via ``GET /api/instruments/{exchange}/{native_symbol}/related``.
    ///
    /// The response carries the resolved underlying (name, sector,
    /// asset class, per-locale description) plus grouped derivative
    /// and proxy instruments. The backend resolves the description
    /// from ``User.default_language`` set via
    /// ``updateDefaultLanguage(_:)``.
    func fetchRelatedInstruments(
        exchange: String,
        symbol: String
    ) async throws -> RelatedInstrumentsResponse {
        return try await request(
            endpoint: "/instruments/\(Self.encodePathSegment(exchange))/\(Self.encodePathSegment(symbol))/related"
        )
    }

    /// Persist the caller's preferred catalog language to
    /// ``User.default_language`` via ``POST /api/auth/me/update``.
    ///
    /// Flows through ``request(...)`` so the helper's
    /// ``attachCSRFHeader(to:method:)`` runs and the 401-refresh
    /// retry path remains in effect. ``request(...)`` is preferred
    /// over the bespoke ``URLSession.dataTask`` path used by
    /// ``AuthService.login/refresh/logout`` (those routes are
    /// server-side CSRF-exempt; ``/auth/me/update`` is guarded by
    /// ``validate_csrf_token``).
    ///
    /// ``language`` is the catalog-language code (``"en"``,
    /// ``"pl"``, …) — callers source it from
    /// ``AppLocale.catalogLanguage.rawValue``.
    ///
    /// The backend returns the updated ``UserResponse``; this call
    /// discards it because ``AppState`` is the source of truth for
    /// the locale on the client.
    func updateDefaultLanguage(_ language: String) async throws {
        let provenance = await MainActor.run {
            EnvelopeMinter.shared.next(.control)
        }
        let envelope = UpdateAuthMeRequest(
            type: "update_auth_me_request",
            sequenceId: provenance.sequenceId,
            publicId: provenance.publicId,
            timestamp: provenance.timestamp,
            sessionId: provenance.sessionId,
            topic: nil,
            payload: UpdateAuthMeBody(defaultLanguage: language)
        )
        let _: UserResponse = try await request(
            endpoint: "/auth/me/update",
            method: "POST",
            body: envelope
        )
    }

    /// Fetch historical candle data via ``GET /api/candles``.
    ///
    /// Routes through ``requestWithFractionalSecondsDates`` rather
    /// than the default ``request`` because the candle envelope and
    /// individual ``CandleData`` rows ship ISO-8601 timestamps with
    /// fractional seconds (e.g. `"2026-05-11T10:00:00.123456Z"`).
    /// The default decoder's ``.iso8601`` strategy is strict against
    /// the bare RFC 3339 grammar and rejects fractional seconds.
    ///
    /// ``asOf`` is optional and absent in the v0.7.0 UI; reserved
    /// for a future time-travel affordance. When supplied it is
    /// formatted as ISO 8601 with fractional seconds, matching the
    /// backend's parsing expectations.
    func fetchCandles(
        exchange: String,
        instrument: String,
        timeframe: MarketTimeframe,
        limit: Int = 100,
        asOf: Date? = nil
    ) async throws -> [MarketCandle] {
        var components = URLComponents()
        var items = [
            URLQueryItem(name: "instrument", value: instrument),
            URLQueryItem(name: "exchange", value: exchange),
            URLQueryItem(name: "timeframe", value: timeframe.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let asOf {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            items.append(URLQueryItem(name: "as_of", value: formatter.string(from: asOf)))
        }
        components.queryItems = items
        let path = "/candles?\(components.percentEncodedQuery ?? "")"
        let envelope: CandleListResponseLocal = try await requestWithFractionalSecondsDates(
            endpoint: path
        )
        return envelope.payload.compactMap(MarketCandle.from(wsCandleData:))
    }

    func fetchSystemStatus() async throws -> SystemStatus {
        let envelope: SystemStatusResponse = try await request(endpoint: AppConfig.Endpoints.status)
        return envelope.payload
    }

    func fetchHealth() async throws -> HealthCheckResponse {
        return try await request(endpoint: AppConfig.Endpoints.health)
    }

    /// Register an APNs device token with the backend.
    ///
    /// Sends ``POST /api/devices`` with a full ``RegisterDeviceCommand``
    /// envelope (the handler strips everything but the ``payload`` and
    /// mints its own provenance; the iOS-side envelope fields are
    /// placeholder values). The 401 retry path in ``request`` handles
    /// an expired ws_token transparently.
    ///
    /// Args:
    ///   command: Envelope-wrapped ``RegisterDeviceBody`` minted by
    ///     ``DeviceRegistrationService``.
    ///
    /// Returns:
    ///   ``NotificationDeviceResponse`` whose ``payload`` carries the
    ///   server-assigned ``public_id`` that identifies this device
    ///   row on subsequent `DELETE` / `PATCH` calls.
    func registerDevice(command: RegisterDeviceCommand) async throws -> NotificationDeviceResponse {
        return try await request(
            endpoint: AppConfig.Endpoints.devices,
            method: "POST",
            body: command
        )
    }

    /// Fetch the authenticated user's recent alert history.
    ///
    /// Powers the Alerts tab. ``limit`` caps page size; the
    /// backend enforces its own upper bound. ``before`` is the opaque
    /// cursor from the previous page's ``next_cursor`` — pass ``nil``
    /// for the first page.
    ///
    /// Hits the ``/alerts/history`` sub-route (the bare ``/alerts``
    /// prefix is reserved for ``GET /alerts/{public_id}`` single-row
    /// lookups consumed by ``fetchAlert(publicId:)``). The mismatch
    /// silently 404'd the entire Alerts tab on TestFlight v0.4.0
    /// build 17 until this path was corrected.
    func fetchAlertHistory(limit: Int? = nil, before: String? = nil) async throws -> AlertHistoryResponse {
        var queryItems: [QueryParameter] = []
        if let limit {
            queryItems.append(QueryParameter(name: "limit", value: "\(limit)"))
        }
        if let before, !before.isEmpty {
            queryItems.append(QueryParameter(name: "before", value: before))
        }
        return try await request(
            endpoint: "\(AppConfig.Endpoints.alerts)/history\(Self.querySuffix(queryItems))"
        )
    }

    /// Fetch a single alert by ``public_id`` (used for deep-linking).
    ///
    /// Args:
    ///   publicId: UUID7 of the alert event to load.
    ///
    /// Returns:
    ///   ``AlertEventResponse`` wrapping the one matching row.
    func fetchAlert(publicId: String) async throws -> AlertEventResponse {
        return try await request(endpoint: "\(AppConfig.Endpoints.alerts)/\(Self.encodePathSegment(publicId))")
    }

    /// Fetch active per-(alert_type, scope) prefs for the addressed
    /// device.
    ///
    /// Caller-scoped server-side: the backend filters by
    /// ``principal.user_public_id`` and 404s when the device is not
    /// owned. ``DeviceRegistrationService.currentDevicePublicId`` is
    /// the right input — never pass a foreign or stale id.
    ///
    /// Returns:
    ///   ``DeviceAlertPrefListResponse`` with zero-or-more prefs.
    func fetchDevicePrefs(devicePublicId: String) async throws -> DeviceAlertPrefListResponse {
        return try await request(
            endpoint: "\(AppConfig.Endpoints.devices)/\(Self.encodePathSegment(devicePublicId))/prefs"
        )
    }

    /// Upsert one per-(device, alert_type, scope) preference.
    ///
    /// Sends ``PATCH /api/devices/{public_id}/prefs`` with a full
    /// ``UpdateDevicePrefCommand`` envelope. The handler strips and
    /// re-mints provenance, so the iOS-side envelope fields are
    /// placeholder values (mirrors ``registerDevice``).
    func updateDevicePref(
        devicePublicId: String,
        command: UpdateDevicePrefCommand
    ) async throws -> DeviceAlertPrefResponse {
        return try await request(
            endpoint: "\(AppConfig.Endpoints.devices)/\(Self.encodePathSegment(devicePublicId))/prefs",
            method: "PATCH",
            body: command
        )
    }

    /// Revoke (SCD2 close) one per-(device, alert_type, scope) preference.
    ///
    /// Sends ``POST /api/devices/{device_public_id}/prefs/{pref_public_id}/revoke``
    /// with a ``RevokeDevicePrefCommand`` envelope. Backend convention is
    /// POST + envelope (not DELETE) so every write carries client-side
    /// provenance for the gap detector — same as ``cancelOrder`` /
    /// ``revokeScopeGrant``.
    ///
    /// The response payload echoes the closed pref projection so the UI
    /// can drop the row from its local list without an extra GET.
    /// Idempotent at the backend: a second revoke of an already-closed
    /// pref returns 404, which surfaces here as ``APIError.httpError(404)``.
    func revokeDevicePref(
        devicePublicId: String,
        prefPublicId: String,
        command: RevokeDevicePrefCommand
    ) async throws -> RevokeDevicePrefResponse {
        return try await request(
            endpoint: "\(AppConfig.Endpoints.devices)/\(Self.encodePathSegment(devicePublicId))/prefs/\(Self.encodePathSegment(prefPublicId))/revoke",
            method: "POST",
            body: command
        )
    }

    /// Fetch the caller's user-level alert default fallbacks.
    ///
    /// Empty list is the legitimate "no overrides" state — the
    /// alert-routing layer falls through to the in-app defaults.
    func fetchAlertDefaults() async throws -> UserAlertDefaultListResponse {
        return try await request(endpoint: AppConfig.Endpoints.alertDefaults)
    }

    /// Upsert one ``(user, alert_type)`` fallback default.
    ///
    /// Sends ``PATCH /api/alert_defaults``. ``user_public_id`` is
    /// sourced server-side from the principal; the
    /// ``UserAlertDefaultBody`` deliberately omits the field.
    func updateAlertDefault(
        command: UpdateUserAlertDefaultCommand
    ) async throws -> UserAlertDefaultResponse {
        return try await request(
            endpoint: AppConfig.Endpoints.alertDefaults,
            method: "PATCH",
            body: command
        )
    }
}

/// Local decode wrapper for ``GET /api/candles``.
///
/// NOT auto-generated: the FastAPI route at
/// ``src/snapper/server/app.py:990`` declares
/// ``response_model=None``, so the OpenAPI generator emits nothing
/// for this endpoint. The wire shape mirrors
/// ``snapper.api.schemas.data_responses.CandleListResponse``
/// (extends ``PayloadListResponse``); ``payload`` carries the row
/// list — NOT ``items``.
///
/// Rows are typed as ``CandleData`` (the generated WS frame type at
/// ``Models/Generated/WSMessages.swift``) because backend `/candles`
/// returns the same Pydantic model that drives the
/// ``market.*.candles.*`` WS topics. One row type, one conversion
/// helper (``MarketCandle.from(wsCandleData:)``).
struct CandleListResponseLocal: Decodable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [CandleData]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        }
    }
}
