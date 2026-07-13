import XCTest
@testable import Snapper

final class APIClientSurfaceTests: XCTestCase {

    private var mockSession: URLSession!
    private var apiClient: APIClient!
    private var requests: RequestRecorder!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)
        apiClient = APIClient(session: mockSession, authService: FakeAuthService(nextToken: "fresh-token"))
        requests = RequestRecorder()
    }

    override func tearDown() {
        apiClient = nil
        mockSession = nil
        requests = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testEveryPublicEndpointUsesExpectedHTTPContract() async throws {
        let requests = self.requests!
        MockURLProtocol.requestHandler = { request in
            requests.append(request)
            return MockURLProtocol.jsonResponse(
                statusCode: 200,
                json: Self.responseEnvelope(for: request)
            )
        }

        _ = try await apiClient.fetchOrders()
        _ = try await apiClient.fetchPositions()
        _ = try await apiClient.fetchSignals()
        _ = try await apiClient.fetchExecutions()
        _ = try await apiClient.fetchWallets()
        _ = try await apiClient.fetchOperators()
        _ = try await apiClient.createOrder(command: Self.createOrderCommand())
        _ = try await apiClient.cancelOrder(planPublicId: "plan/1", reason: "user requested")
        _ = try await apiClient.createBracket(command: Self.bracketCommand())
        _ = try await apiClient.createTrailingStop(command: Self.trailingStopCommand())
        _ = try await apiClient.fetchInstruments(exchange: "kraken/spot")
        _ = try await apiClient.fetchSystemStatus()
        _ = try await apiClient.fetchHealth()
        _ = try await apiClient.registerDevice(command: Self.registerDeviceCommand())
        _ = try await apiClient.fetchAlertHistory()
        _ = try await apiClient.fetchAlertHistory(limit: 25, before: "opaque+/cursor")
        _ = try await apiClient.fetchAlert(publicId: "alert/1")
        _ = try await apiClient.fetchDevicePrefs(devicePublicId: "device/1")
        _ = try await apiClient.updateDevicePref(devicePublicId: "device/1", command: Self.devicePrefCommand())
        _ = try await apiClient.fetchAlertDefaults()
        _ = try await apiClient.updateAlertDefault(command: Self.alertDefaultCommand())
        _ = try await apiClient.fetchRelatedInstruments(exchange: "polygon", symbol: "GLD")
        try await apiClient.updateDefaultLanguage("pl")
        _ = try await apiClient.fetchCachedCandles(exchange: "polygon", symbol: "GLD", timeframe: .oneMinute, limit: 100)
        _ = try await apiClient.fetchAllConfiguredPairStats()
        _ = try await apiClient.fetchCacheHealth()
        _ = try await apiClient.fetchBacktests()
        _ = try await apiClient.fetchProcessSummary()
        let aiReviews = try await apiClient.fetchAiReviews()
        let strategies = try await apiClient.fetchStrategies()
        let users = try await apiClient.fetchUsers()
        let delegates = try await apiClient.fetchDelegates()
        let accounts = try await apiClient.fetchAccounts()

        XCTAssertEqual(aiReviews.first?.reviewPublicId, "review-1")
        XCTAssertEqual(aiReviews.first?.decision, "approve")
        XCTAssertEqual(strategies.first?.name, "strategy_macd_btc")
        XCTAssertEqual(users.first?.username, "viewer")
        XCTAssertEqual(delegates.first?.username, "delegate-mcp")
        XCTAssertTrue(accounts.isEmpty)

        let snapshots = requests.snapshots
        XCTAssertEqual(snapshots.map(\.method), [
            "GET", "GET", "GET", "GET", "GET", "GET",
            "POST", "POST", "POST", "POST",
            "GET", "GET", "GET", "POST", "GET", "GET",
            "GET", "GET", "PATCH", "GET", "PATCH",
            "GET", "POST",
            "GET", "GET", "GET",
            "GET", "GET", "GET", "GET", "GET", "GET", "GET"
        ])
        XCTAssertEqual(snapshots.map(\.path), [
            "/api/orders",
            "/api/positions",
            "/api/signals",
            "/api/executions",
            "/api/wallets",
            "/api/operators",
            "/api/orders",
            "/api/orders/plan%2F1/cancel",
            "/api/execution-plans",
            "/api/trailing-stops",
            "/api/exchanges/kraken%2Fspot/instruments/detail",
            "/api/status",
            "/api/health",
            "/api/devices",
            "/api/alerts/history",
            "/api/alerts/history",
            "/api/alerts/alert%2F1",
            "/api/devices/device%2F1/prefs",
            "/api/devices/device%2F1/prefs",
            "/api/alert_defaults",
            "/api/alert_defaults",
            "/api/instruments/polygon/GLD/related",
            "/api/auth/me/update",
            "/api/candles/cache",
            "/api/market/cache/stats/configured",
            "/api/market/cache/health",
            "/api/backtests",
            "/api/processes/summary",
            "/api/ai-reviews",
            "/api/strategies",
            "/api/auth/users",
            "/api/ai-delegates",
            "/api/portfolio/accounts"
        ])
        let cachedCandlesQuery = try XCTUnwrap(snapshots[23].query)
        let cachedCandlesItems = URLComponents(string: "/?\(cachedCandlesQuery)")?.queryItems ?? []
        XCTAssertEqual(
            Set(cachedCandlesItems),
            Set([
                URLQueryItem(name: "instrument", value: "GLD"),
                URLQueryItem(name: "exchange", value: "polygon"),
                URLQueryItem(name: "timeframe", value: "1m"),
                URLQueryItem(name: "limit", value: "100"),
            ])
        )
        XCTAssertNil(snapshots[14].query)
        XCTAssertEqual(snapshots[15].query, "limit=25&before=opaque%2B%2Fcursor")

        let orderBody = try XCTUnwrap(snapshots[6].jsonBody)
        XCTAssertEqual(orderBody["type"] as? String, "create_order_command")
        let orderPayload = try XCTUnwrap(orderBody["payload"] as? [String: Any])
        XCTAssertEqual(orderPayload["instrument_public_id"] as? String, "instrument-1")
        XCTAssertEqual(orderPayload["wallet_public_id"] as? String, "wallet-1")

        let cancelBody = try XCTUnwrap(snapshots[7].jsonBody)
        let cancelPayload = try XCTUnwrap(cancelBody["payload"] as? [String: Any])
        XCTAssertEqual(cancelPayload["reason"] as? String, "user requested")

        let prefBody = try XCTUnwrap(snapshots[18].jsonBody)
        let prefPayload = try XCTUnwrap(prefBody["payload"] as? [String: Any])
        XCTAssertEqual(prefPayload["alert_type"] as? String, "order_fill_full")
        XCTAssertEqual(prefPayload["mute_until"] as? String, "1970-01-01T00:00:00Z")

        let langBody = try XCTUnwrap(snapshots[22].jsonBody)
        XCTAssertEqual(langBody["type"] as? String, "update_auth_me_request")
        XCTAssertNotNil(langBody["public_id"] as? String)
        XCTAssertNotNil(langBody["session_id"] as? String)
        let langPayload = try XCTUnwrap(langBody["payload"] as? [String: Any])
        XCTAssertEqual(langPayload["default_language"] as? String, "pl")
    }

    func testServerErrorDetailAndPlainStatusErrors() async throws {
        MockURLProtocol.requestHandler = { _ in
            return MockURLProtocol.errorResponse(statusCode: 500, message: "backend exploded")
        }

        do {
            _ = try await apiClient.fetchOrders()
            XCTFail("Expected serverError")
        } catch let error as APIError {
            if case .serverError(let message) = error {
                XCTAssertEqual(message, "backend exploded")
            } else {
                XCTFail("Wrong APIError: \(error)")
            }
        }

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 418,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            return (response, Data("not-json".utf8))
        }

        do {
            _ = try await apiClient.fetchOrders()
            XCTFail("Expected httpError")
        } catch let error as APIError {
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 418)
            } else {
                XCTFail("Wrong APIError: \(error)")
            }
        }
    }

    func testFetchAlertHistorySkipsEmptyBeforeCursor() async throws {
        let requests = self.requests!
        MockURLProtocol.requestHandler = { request in
            requests.append(request)
            return MockURLProtocol.jsonResponse(
                statusCode: 200,
                json: Self.responseEnvelope(for: request)
            )
        }

        _ = try await apiClient.fetchAlertHistory(before: "")

        let snapshot = try XCTUnwrap(requests.snapshots.last)
        XCTAssertEqual(snapshot.path, "/api/alerts/history")
        XCTAssertNil(snapshot.query)
    }

    func testFetchAccountsDecodesNonEmptyPayloadAndOptionalObservationClocks() async throws {
        MockURLProtocol.requestHandler = { _ in
            return MockURLProtocol.jsonResponse(
                statusCode: 200,
                json: Self.listEnvelope(payload: [Self.accountPayload()])
            )
        }

        let accounts = try await apiClient.fetchAccounts()

        let account = try XCTUnwrap(accounts.first)
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(account.publicId, "account-1")
        XCTAssertEqual(account.walletPublicId, "wallet-1")
        XCTAssertEqual(account.balances?.first?.currency, "USD")
        XCTAssertEqual(account.balances?.first?.total, 1250.5)
        XCTAssertEqual(account.balances?.first?.free, 1000.25)
        XCTAssertNil(account.balances?.first?.used)
        XCTAssertEqual(account.openPositions?.first?.symbol, "BTCUSD")
        XCTAssertEqual(account.openPositions?.first?.entryPrice, 60000)
        XCTAssertEqual(account.openPositions?.first?.unrealizedFunding, -1.25)
        XCTAssertEqual(
            account.balanceObservedAt,
            Date(timeIntervalSince1970: 1_767_225_601)
        )
        XCTAssertNil(account.positionObservedAt)
        XCTAssertEqual(account.currentAttemptObservationId, 42)
        XCTAssertEqual(account.balancePayloadSourceObservationId, 41)
        XCTAssertNil(account.positionPayloadSourceObservationId)
    }

    private static func responseEnvelope(for request: URLRequest) -> [String: Any] {
        let method = request.httpMethod ?? "GET"
        let path = Self.percentEncodedPath(for: request)
        if method == "GET", path == "/api/orders" {
            return listEnvelope(payload: [])
        }
        if method == "GET", path == "/api/positions" {
            return listEnvelope(payload: [])
        }
        if method == "GET", path == "/api/portfolio/accounts" {
            return listEnvelope(payload: [])
        }
        if method == "GET", path == "/api/signals" {
            return listEnvelope(payload: [])
        }
        if method == "GET", path == "/api/backtests" {
            return listEnvelope(payload: [backtestPayload()])
        }
        if method == "GET", path == "/api/processes/summary" {
            return envelope(payload: processSummaryPayload())
        }
        if method == "GET", path == "/api/ai-reviews" {
            return ["items": [aiReviewPayload()], "count": 1]
        }
        if method == "GET", path == "/api/strategies" {
            return listEnvelope(payload: [strategyProcessPayload()])
        }
        if method == "GET", path == "/api/auth/users" {
            return listEnvelope(payload: [userProfilePayload()])
        }
        if method == "GET", path == "/api/ai-delegates" {
            return listEnvelope(payload: [delegatePayload()])
        }
        if method == "GET", path == "/api/executions" {
            return listEnvelope(payload: [])
        }
        if method == "GET", path == "/api/wallets" {
            return listEnvelope(payload: [])
        }
        if method == "GET", path == "/api/operators" {
            return listEnvelope(payload: [])
        }
        if method == "GET", path == "/api/exchanges/kraken%2Fspot/instruments/detail" {
            return listEnvelope(payload: [])
        }
        if method == "GET", path == "/api/status" {
            return envelope(payload: systemStatusPayload())
        }
        if method == "GET", path == "/api/health" {
            return envelope(payload: healthPayload())
        }
        if method == "POST", path == "/api/devices" {
            return envelope(payload: notificationDevicePayload())
        }
        if method == "GET", path == "/api/alerts/history" {
            var value = listEnvelope(payload: [])
            value["next_cursor"] = "cursor-next"
            return value
        }
        if method == "GET", path == "/api/alerts/alert%2F1" {
            return envelope(payload: alertPayload())
        }
        if method == "GET", path == "/api/devices/device%2F1/prefs" {
            return listEnvelope(payload: [devicePrefPayload()])
        }
        if method == "PATCH", path == "/api/devices/device%2F1/prefs" {
            return envelope(payload: devicePrefPayload())
        }
        if method == "GET", path == "/api/alert_defaults" {
            return listEnvelope(payload: [alertDefaultPayload()])
        }
        if method == "PATCH", path == "/api/alert_defaults" {
            return envelope(payload: alertDefaultPayload())
        }
        if method == "GET", path == "/api/instruments/polygon/GLD/related" {
            return relatedInstrumentsEnvelope()
        }
        if method == "POST", path == "/api/auth/me/update" {
            return envelope(payload: userProfilePayload())
        }
        if method == "GET", path == "/api/candles/cache" {
            return envelope(payload: cachedCandlesPayload())
        }
        if method == "GET", path == "/api/market/cache/stats/configured" {
            return envelope(payload: listedCachedStatsPayload())
        }
        if method == "GET", path == "/api/market/cache/health" {
            return envelope(payload: cacheHealthPayload())
        }
        return envelope(payload: executionPlanPayload())
    }

    private static func cachedCandlesPayload() -> [String: Any] {
        return [
            "candles": [],
            "sample_count": 0,
            "is_warm": true,
            "source": "cache"
        ]
    }

    private static func listedCachedStatsPayload() -> [String: Any] {
        return [
            "pairs": [],
            "count": 0
        ]
    }

    private static func cacheHealthPayload() -> [String: Any] {
        return [
            "instruments_cached": 0,
            "pairs_cached": 0,
            "persist_universe_size": 0
        ]
    }

    private static func percentEncodedPath(for request: URLRequest) -> String {
        guard let url = request.url else { return "" }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
    }

    private static func envelope(payload: Any) -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "env-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "payload": payload
        ]
    }

    private static func listEnvelope(payload: [[String: Any]]) -> [String: Any] {
        var value = envelope(payload: payload)
        value["count"] = payload.count
        return value
    }

    private static func executionPlanPayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "plan-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "plan_type": "manual",
            "status": "created",
            "instrument_public_id": "instrument-1",
            "exchange": "kraken",
            "mode": "paper",
            "side": "buy",
            "total_quantity": 1.0,
            "filled_quantity": 0.0,
            "created_at": "2026-01-01T00:00:00Z",
            "created_via": "ios",
            "wallet_public_id": "wallet-1",
            "params": [:]
        ]
    }

    private static func systemStatusPayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "status-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "trader": processStatusPayload(),
            "backtests": [:]
        ]
    }

    private static func processStatusPayload() -> [String: Any] {
        return [
            "status": "running",
            "pid": 123,
            "started_at": "2026-01-01T00:00:00Z",
            "command": "snapper",
            "exit_code": 0
        ]
    }

    private static func strategyProcessPayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "strategy-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "name": "strategy_macd_btc",
            "running": true,
            "enabled": true,
            "mode": "paper"
        ]
    }

    private static func aiReviewPayload() -> [String: Any] {
        return [
            "review_public_id": "review-1",
            "strategy_public_id": "strategy-1",
            "user_public_id": "user-1",
            "operator_public_id": "operator-1",
            "wallet_public_id": "wallet-1",
            "instrument_public_id": "instrument-1",
            "selected_delegate_public_id": "delegate-1",
            "status": "resolved_approved",
            "decision": "approve",
            "rationale": "momentum confirmed",
            "dispatch_version": 1,
            "created_at": "2026-01-01T00:00:00Z",
            "resolved_at": "2026-01-01T00:30:00Z",
            "deadline": "2026-01-01T01:00:00Z"
        ]
    }

    private static func processSummaryPayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "psum-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "feeds": ["running": 1, "total": 1],
            "strategies": ["running": 2, "total": 3],
            "executors": ["running": 1, "total": 1],
            "brokers": ["running": 1, "total": 1],
            "processes": [
                [
                    "name": "trader",
                    "running": true,
                    "enabled": true,
                    "role": "core",
                    "lifecycle": "long_running",
                    "rss_bytes": 12_345_678,
                    "cpu_percent": 3.5
                ]
            ]
        ]
    }

    private static func backtestPayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "backtest-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "wallet_public_id": "wallet-1",
            "strategy_name": "momentum",
            "instrument_public_id": "instrument-1",
            "instrument": "BTC-USD",
            "exchange": "kraken",
            "timeframe": "1h",
            "start_date": "2026-01-01T00:00:00Z",
            "end_date": "2026-02-01T00:00:00Z",
            "initial_cash": 10000,
            "status": "completed"
        ]
    }

    private static func accountPayload() -> [String: Any] {
        return [
            "type": "portfolio_account_state",
            "sequence_id": 7,
            "public_id": "account-1",
            "timestamp": "2026-01-01T00:00:02Z",
            "session_id": "session-1",
            "wallet_public_id": "wallet-1",
            "exchange": "kraken",
            "mode": "live",
            "sync_status": "observed",
            "effective_status": "observed",
            "is_authoritative": true,
            "balance_status": "observed",
            "position_status": "observed",
            "valuation_status": "native_only",
            "balances": [[
                "currency": "USD",
                "total": 1250.5,
                "free": 1000.25,
                "used": NSNull(),
            ]],
            "open_positions": [[
                "symbol": "BTCUSD",
                "side": "long",
                "size": 0.5,
                "entry_price": 60000,
                "mark_price": 61000,
                "unrealized_pnl": 500,
                "unrealized_funding": -1.25,
                "timestamp": "2026-01-01T00:00:01Z",
            ]],
            "balance_observed_at": "2026-01-01T00:00:01Z",
            "position_observed_at": NSNull(),
            "authoritative_until": "2026-01-01T00:00:17Z",
            "current_attempt_observation_id": 42,
            "balance_payload_source_observation_id": 41,
            "position_payload_source_observation_id": NSNull(),
            "error": NSNull(),
        ]
    }

    private static func healthPayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "health-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "status": "healthy",
            "version": "1.0",
            "connections": ["active_connections": 1],
            "topics": ["active": 1],
            "gap_detection": ["bridge": ["gaps_detected": 0]]
        ]
    }

    private static func notificationDevicePayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "device-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "user_public_id": "user-1",
            "device_token": "deadbeef",
            "device_id": "device-id",
            "platform": "ios",
            "env": "sandbox",
            "app_version": "1.0",
            "previews_mode": "private",
            "registered_at": "2026-01-01T00:00:00Z"
        ]
    }

    private static func alertPayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "alert-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "user_public_id": "user-1",
            "alert_type": "order_fill_full",
            "priority": "medium",
            "is_safety_critical": false,
            "title": "Order filled",
            "body": "The order filled."
        ]
    }

    private static func devicePrefPayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "pref-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "device_public_id": "device-1",
            "alert_type": "order_fill_full",
            "enabled": true,
            "min_priority": "medium",
            "timezone": "UTC"
        ]
    }

    private static func alertDefaultPayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "default-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "user_public_id": "user-1",
            "alert_type": "order_fill_full",
            "enabled": true,
            "min_priority": "medium"
        ]
    }

    private static func delegatePayload() -> [String: Any] {
        return [
            "public_id": "delegate-1",
            "username": "delegate-mcp",
            "label": "MCP grant",
            "created_by_user_public_id": "user-1",
            "created_at": "2026-01-01T00:00:00Z",
            "is_active": true,
            "caps": ["max_open_orders": 5, "max_daily_notional_usd": 10000]
        ]
    }

    private static func userProfilePayload() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "user-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "username": "viewer",
            "role": "viewer",
            "is_active": true,
            "created_at": "2026-01-01T00:00:00Z",
            "default_language": "pl"
        ]
    }

    private static func relatedInstrumentsEnvelope() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "related-1",
            "timestamp": "2026-01-01T00:00:00Z",
            "session_id": "session-1",
            "payload": [
                "selected": [
                    "exchange": "polygon",
                    "native_symbol": "GLD"
                ],
                "underlying": [
                    "public_id": "underlying-1",
                    "ticker": "GLD",
                    "name": "SPDR Gold Trust",
                    "asset_class": "commodity",
                    "sector": "Precious Metals",
                    "description": "Test description."
                ],
                "groups": []
            ]
        ]
    }

    private static func createOrderCommand() -> CreateOrderCommand {
        return CreateOrderCommand(
            type: "create_order_command",
            sequenceId: 1,
            publicId: "cmd-order",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "session-1",
            topic: nil,
            payload: CreateOrderBody(
                instrument: "BTCUSD",
                instrumentPublicId: "instrument-1",
                exchange: "kraken",
                mode: "paper",
                side: "buy",
                orderType: "limit",
                quantity: 1.0,
                price: 10.0,
                stopPrice: nil,
                timeInForce: "gtc",
                postOnly: true,
                leverage: nil,
                reduceOnly: nil,
                walletPublicId: "wallet-1",
                operatorPublicId: nil,
                idempotencyKey: "idem-1",
                aiReviewPublicId: nil
            )
        )
    }

    private static func bracketCommand() -> BracketCreateCommand {
        return BracketCreateCommand(
            type: "bracket_create_command",
            sequenceId: 1,
            publicId: "cmd-bracket",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "session-1",
            topic: nil,
            payload: BracketCreateBody(
                positionCyclePublicId: "cycle-1",
                slPrice: 9.0,
                tpPrice: 12.0,
                idempotencyKey: "idem-bracket"
            )
        )
    }

    private static func trailingStopCommand() -> TrailingStopCreateCommand {
        return TrailingStopCreateCommand(
            type: "trailing_stop_create_command",
            sequenceId: 1,
            publicId: "cmd-trailing",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "session-1",
            topic: nil,
            payload: TrailingStopCreateBody(
                positionCyclePublicId: "cycle-1",
                trailingPct: 1.5,
                minLockPct: 0.25,
                idempotencyKey: "idem-trailing"
            )
        )
    }

    private static func registerDeviceCommand() -> RegisterDeviceCommand {
        return RegisterDeviceCommand(
            type: "register_device_command",
            sequenceId: 1,
            publicId: "cmd-device",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "session-1",
            topic: nil,
            payload: RegisterDeviceBody(
                deviceToken: "deadbeef",
                deviceId: "device-id",
                env: "sandbox",
                appVersion: "1.0",
                previewsMode: nil
            )
        )
    }

    private static func devicePrefCommand() -> UpdateDevicePrefCommand {
        return UpdateDevicePrefCommand(
            type: "update_device_pref_command",
            sequenceId: 1,
            publicId: "cmd-pref",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "session-1",
            topic: nil,
            payload: DeviceAlertPrefBody(
                alertType: "order_fill_full",
                operatorPublicId: nil,
                walletPublicId: nil,
                enabled: true,
                minPriority: "medium",
                quietHoursStartMin: 60,
                quietHoursEndMin: 120,
                muteUntil: Date(timeIntervalSince1970: 0),
                timezone: "UTC"
            )
        )
    }

    private static func alertDefaultCommand() -> UpdateUserAlertDefaultCommand {
        return UpdateUserAlertDefaultCommand(
            type: "update_user_alert_default_command",
            sequenceId: 1,
            publicId: "cmd-default",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "session-1",
            topic: nil,
            payload: UserAlertDefaultBody(
                alertType: "order_fill_full",
                enabled: true,
                minPriority: "medium"
            )
        )
    }
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [RequestSnapshot] = []

    func append(_ request: URLRequest) {
        let snapshot = RequestSnapshot(request: request)
        lock.withLock { values.append(snapshot) }
    }

    var snapshots: [RequestSnapshot] {
        lock.withLock { values }
    }
}

private struct RequestSnapshot {
    let method: String
    let path: String
    let query: String?
    let jsonBody: [String: Any]?

    init(request: URLRequest) {
        method = request.httpMethod ?? "GET"
        let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        path = components?.percentEncodedPath ?? request.url?.path ?? ""
        query = components?.percentEncodedQuery
        if let data = Self.readBody(from: request),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            jsonBody = parsed
        } else {
            jsonBody = nil
        }
    }

    private static func readBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
