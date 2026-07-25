import XCTest
@testable import Snapper

@MainActor
final class APIClientTests: XCTestCase {

    private var mockSession: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
    }

    override func tearDown() {
        mockSession = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testAPIErrorDescription() {
        XCTAssertEqual(APIError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(APIError.invalidResponse.errorDescription, "Invalid response from server")
        XCTAssertEqual(APIError.httpError(404).errorDescription, "HTTP error: 404")
        XCTAssertEqual(APIError.serverError("Test error").errorDescription, "Test error")
    }

    /// First 401 triggers fresh-token fetch; second call returns 200.
    /// Request must execute twice; final 200 payload decodes; no logout.
    func test401TriggersRefreshAndRetry() async throws {
        let fakeAuth = FakeAuthService(nextToken: "new-token")
        let client = APIClient(session: mockSession, authService: fakeAuth)

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            if callCount == 1 {
                return MockURLProtocol.errorResponse(statusCode: 401, message: "Token expired")
            }
            return MockURLProtocol.jsonResponse(statusCode: 200, json: Self.orderListEnvelope())
        }

        let orders = try await client.fetchOrders()

        XCTAssertEqual(callCount, 2, "request must be retried exactly once after 401")
        XCTAssertEqual(orders.count, 1)
        let fetchCalls = await fakeAuth.fetchCalls
        let logoutCalls = await fakeAuth.logoutCalls
        XCTAssertEqual(fetchCalls, 1, "refresh should be requested once between 401 and retry")
        XCTAssertEqual(logoutCalls, 0, "successful retry must not trigger logout")
    }

    /// Second 401 after refresh → force logout + surface APIError.httpError(401).
    func test401TwiceTriggersLogout() async {
        let fakeAuth = FakeAuthService(nextToken: "fresh")
        let client = APIClient(session: mockSession, authService: fakeAuth)

        MockURLProtocol.requestHandler = { _ in
            return MockURLProtocol.errorResponse(statusCode: 401, message: "Token still bad")
        }

        do {
            _ = try await client.fetchOrders()
            XCTFail("expected APIError.httpError(401)")
        } catch let error as APIError {
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 401)
            } else {
                XCTFail("wrong error: \(error)")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }

        let logoutCalls = await fakeAuth.logoutCalls
        XCTAssertEqual(logoutCalls, 1, "logout must fire after second 401")
    }

    /// Refresh returns nil (nextToken=nil) → immediate logout, no retry.
    func testRefreshNilTriggersLogoutWithoutRetry() async {
        let fakeAuth = FakeAuthService(nextToken: nil)
        let client = APIClient(session: mockSession, authService: fakeAuth)

        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            return MockURLProtocol.errorResponse(statusCode: 401, message: "Token expired")
        }

        do {
            _ = try await client.fetchOrders()
            XCTFail("expected APIError.httpError(401)")
        } catch let error as APIError {
            if case .httpError = error {} else { XCTFail("wrong error: \(error)") }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }

        XCTAssertEqual(callCount, 1, "must NOT retry when refresh returns nil — infinite loop defence")
        let logoutCalls = await fakeAuth.logoutCalls
        XCTAssertEqual(logoutCalls, 1, "logout must fire when refresh returns nil")
    }

    /// The 401-refresh-replay lives in the shared ``transport``, so the
    /// fractional-seconds decoding variant MUST inherit exactly the same
    /// behavior as the strict-ISO one. These two characterize it through
    /// ``fetchPnlSeries`` (a fractional-date caller) so a future change
    /// that re-splits the transport cannot silently give one variant a
    /// different retry policy.
    ///
    /// 401 → refresh once → replay once → 200 decodes.
    func testFractionalDateVariantRetriesOnceAfter401() async throws {
        let fakeAuth = FakeAuthService(nextToken: "new-token")
        let client = APIClient(session: mockSession, authService: fakeAuth)

        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            if callCount == 1 {
                return MockURLProtocol.errorResponse(statusCode: 401, message: "Token expired")
            }
            return MockURLProtocol.jsonResponse(statusCode: 200, json: Self.pnlSeriesEnvelope())
        }

        let series = try await client.fetchPnlSeries(
            walletPublicId: "wallet-1",
            mode: "paper",
            granularity: "1h",
            from: Date(timeIntervalSince1970: 1_767_225_600),
            to: Date(timeIntervalSince1970: 1_767_312_000),
            valuationCcy: "EUR"
        )

        XCTAssertEqual(callCount, 2, "request must be replayed exactly once after 401")
        XCTAssertEqual(series.mode, "paper")
        let fetchCalls = await fakeAuth.fetchCalls
        let logoutCalls = await fakeAuth.logoutCalls
        XCTAssertEqual(fetchCalls, 1, "exactly one refresh between the 401 and the replay")
        XCTAssertEqual(logoutCalls, 0, "a successful replay must not log out")
    }

    /// 401 → refresh → 401 again → logout, and NO second replay.
    func testFractionalDateVariantDoesNotReplayTwiceOn401() async {
        let fakeAuth = FakeAuthService(nextToken: "fresh")
        let client = APIClient(session: mockSession, authService: fakeAuth)

        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            return MockURLProtocol.errorResponse(statusCode: 401, message: "Token still bad")
        }

        do {
            _ = try await client.fetchPnlSeries(
                walletPublicId: "wallet-1",
                mode: "paper",
                granularity: "1h",
                from: Date(timeIntervalSince1970: 1_767_225_600),
                to: Date(timeIntervalSince1970: 1_767_312_000),
                valuationCcy: "EUR"
            )
            XCTFail("expected APIError.httpError(401)")
        } catch let error as APIError {
            guard case .httpError(let code) = error else {
                return XCTFail("wrong error: \(error)")
            }
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }

        XCTAssertEqual(callCount, 2, "the replay happens once and is never repeated")
        let logoutCalls = await fakeAuth.logoutCalls
        XCTAssertEqual(logoutCalls, 1, "a second 401 forces logout")
    }

    private static func pnlSeriesEnvelope() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "env-1",
            "timestamp": "2026-01-01T00:00:00.000Z",
            "session_id": "session-1",
            "payload": [
                "type": "pnl_series",
                "sequence_id": 1,
                "public_id": "pnl-1",
                "timestamp": "2026-01-01T00:00:00Z",
                "session_id": "session-1",
                "wallet_public_id": "wallet-1",
                "mode": "paper",
                "granularity": "1h",
                "valuation_ccy": "EUR",
                "from_time": "2026-01-01T00:00:00Z",
                "to_time": "2026-01-02T00:00:00Z",
                "as_of": "2026-01-02T00:00:00.123456Z",
                "mark_source": "finalized_1m_candle_close",
                "rate_sources": [],
                "calc_version": "5A.13",
                "execution_history": ["status": "as_recorded", "corrections": []],
                "equity_coverage": [
                    "sampled": false,
                    "venue_scope": NSNull(),
                    "external_flows_adjusted": NSNull(),
                    "complete_minutes": 0,
                    "first_minute": NSNull(),
                    "last_minute": NSNull(),
                    "sample_calc_version": NSNull(),
                ],
                "points": [],
            ],
        ]
    }

    /// Asserts that ``fetchWallets`` decodes the canonical
    /// ``WalletListResponse`` envelope and returns the inner
    /// ``WalletInfo`` payload preserving ``label`` + ``isPaper``.
    func testFetchWalletsParsesResponse() async throws {
        let fakeAuth = FakeAuthService(nextToken: "token")
        let client = APIClient(session: mockSession, authService: fakeAuth)

        MockURLProtocol.requestHandler = { _ in
            return MockURLProtocol.jsonResponse(statusCode: 200, json: Self.walletListEnvelope())
        }

        let wallets = try await client.fetchWallets()

        XCTAssertEqual(wallets.count, 2)
        XCTAssertEqual(wallets[0].label, "default")
        XCTAssertEqual(wallets[0].isPaper, false)
        XCTAssertEqual(wallets[1].label, "default-paper")
        XCTAssertEqual(wallets[1].isPaper, true)
    }

    private static func walletListEnvelope() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "01961234-5678-7000-8000-000000000a00",
            "timestamp": "2025-11-22T10:00:00Z",
            "session_id": "session-wallets",
            "count": 2,
            "payload": [
                [
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000a01",
                    "timestamp": "2025-11-22T10:00:00Z",
                    "session_id": "session-wallets",
                    "label": "default",
                    "is_paper": false
                ],
                [
                    "sequence_id": 2,
                    "public_id": "01961234-5678-7000-8000-000000000a02",
                    "timestamp": "2025-11-22T10:00:00Z",
                    "session_id": "session-wallets",
                    "label": "default-paper",
                    "is_paper": true
                ]
            ]
        ]
    }

    private static func orderListEnvelope() -> [String: Any] {
        return [
            "sequence_id": 1,
            "public_id": "01961234-5678-7000-8000-000000000900",
            "timestamp": "2025-11-22T10:00:00Z",
            "session_id": "session-retry",
            "count": 1,
            "payload": [
                [
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000901",
                    "timestamp": "2025-11-22T10:00:00Z",
                    "session_id": "session-retry",
                    "instrument": "BTCUSD",
                    "exchange": "kraken",
                    "client_order_id": "cli-retry",
                    "side": "buy",
                    "order_type": "limit",
                    "size": 1.0,
                    "filled_size": 0.0,
                    "status": "open",
                    "created_at": "2025-11-22T10:00:00Z"
                ]
            ]
        ]
    }
}
