import XCTest
@testable import Snapper

@MainActor
final class APIClientNetworkTests: XCTestCase {

    var apiClient: APIClient!
    var mockSession: URLSession!

    override func setUp() {
        super.setUp()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)

        apiClient = APIClient(session: mockSession, authService: FakeAuthService())
    }

    override func tearDown() {
        apiClient = nil
        mockSession = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchOrdersSuccess() async throws {

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!

            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000100",
                "timestamp": "2025-11-22T10:00:00Z",
                "session_id": "session-1",
                "count": 1,
                "payload": [
                    [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000001",
                        "timestamp": "2025-11-22T10:00:00Z",
                        "session_id": "session-1",
                        "instrument": "BTCUSD",
                        "exchange": "kraken",
                        "client_order_id": "client-123",
                        "side": "buy",
                        "order_type": "limit",
                        "size": 1.0,
                        "filled_size": 0.0,
                        "status": "open",
                        "created_at": "2025-11-22T10:00:00Z"
                    ]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)

            return (response, data)
        }

        let orders = try await apiClient.fetchOrders()

        XCTAssertEqual(orders.count, 1)
        XCTAssertEqual(orders[0].clientOrderId, "client-123")
        XCTAssertEqual(orders[0].instrument, "BTCUSD")
    }

    func testFetchOrders401Error() async throws {

        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.errorResponse(statusCode: 401, message: "Token expired")
        }

        do {
            _ = try await apiClient.fetchOrders()
            XCTFail("Should throw error")
        } catch let error as APIError {
            // Post-Commit-3 contract: a 401 with no recoverable token
            // (default FakeAuthService → nextToken == nil) force-logs-out
            // the user and surfaces httpError(401). Backend-sent detail
            // is intentionally dropped in this path so the UI routes to
            // LoginView instead of showing a stale error message.
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 401)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testFetchOrdersNetworkError() async throws {

        MockURLProtocol.requestHandler = { request in
            throw MockURLProtocol.networkError()
        }

        do {
            _ = try await apiClient.fetchOrders()
            XCTFail("Should throw error")
        } catch {

            XCTAssertNotNil(error)
        }
    }

    func testFetchOrdersNonHTTPResponseThrowsInvalidResponse() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [APIClientNonHTTPURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = APIClient(session: session, authService: FakeAuthService())
        APIClientNonHTTPURLProtocol.responseHandler = { request in
            let response = URLResponse(
                url: request.url!,
                mimeType: AppConfig.ContentType.json,
                expectedContentLength: 0,
                textEncodingName: nil
            )
            return (response, Data())
        }
        defer { APIClientNonHTTPURLProtocol.responseHandler = nil }

        do {
            _ = try await client.fetchOrders()
            XCTFail("Expected invalidResponse")
        } catch let error as APIError {
            if case .invalidResponse = error {
            } else {
                XCTFail("Wrong APIError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchOrdersInvalidBaseURLThrowsInvalidURL() async {
        let client = APIClient(
            session: mockSession,
            authService: FakeAuthService(),
            apiBaseURLProvider: { "http://[::1" }
        )

        do {
            _ = try await client.fetchOrders()
            XCTFail("Expected invalidURL")
        } catch let error as APIError {
            if case .invalidURL = error {
            } else {
                XCTFail("Wrong APIError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchPositionsSuccess() async throws {

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!

            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000200",
                "timestamp": "2025-11-22T10:00:00Z",
                "session_id": "session-1",
                "count": 1,
                "payload": [
                    [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000002",
                        "timestamp": "2025-11-22T10:00:00Z",
                        "session_id": "session-1",
                        "instrument": "BTCUSD",
                        "exchange": "kraken",
                        "quantity": 1.5,
                        "average_price": 50000.0,
                        "unrealized_pnl": 500.0,
                        "realized_pnl": 0.0
                    ]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)

            return (response, data)
        }

        let positions = try await apiClient.fetchPositions()

        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions[0].instrument, "BTCUSD")
        XCTAssertEqual(positions[0].quantity, 1.5)
        XCTAssertEqual(positions[0].averagePrice, 50000.0)
    }

    func testFetchSignalsSuccess() async throws {

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!

            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000300",
                "timestamp": "2025-11-22T10:00:00Z",
                "session_id": "session-1",
                "count": 1,
                "payload": [
                    [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000003",
                        "timestamp": "2025-11-22T10:00:00Z",
                        "session_id": "session-1",
                        "instrument": "ETHUSD",
                        "exchange": "kraken",
                        "side": "buy",
                        "strength": 0.8,
                        "reason": "Strategy triggered",
                        "fired_at": "2025-11-22T10:00:00Z"
                    ]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)

            return (response, data)
        }

        let signals = try await apiClient.fetchSignals()

        XCTAssertEqual(signals.count, 1)
        XCTAssertEqual(signals[0].publicId, "01961234-5678-7000-8000-000000000003")
        XCTAssertEqual(signals[0].instrument, "ETHUSD")
    }

    func testRequestSetsCorrectContentType() async throws {

        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request

            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000400",
                "timestamp": "2025-11-22T10:00:00Z",
                "session_id": "session-1",
                "count": 1,
                "payload": [
                    [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000001",
                        "timestamp": "2025-11-22T10:00:00Z",
                        "session_id": "session-1",
                        "instrument": "BTCUSD",
                        "exchange": "kraken",
                        "client_order_id": "client-123",
                        "side": "buy",
                        "order_type": "limit",
                        "size": 1.0,
                        "filled_size": 0.0,
                        "status": "open",
                        "created_at": "2025-11-22T10:00:00Z"
                    ]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            return (response, data)
        }

        _ = try await apiClient.fetchOrders()

        XCTAssertNotNil(capturedRequest)
        let contentType = capturedRequest?.value(forHTTPHeaderField: AppConfig.HTTPHeader.contentType)
        XCTAssertEqual(contentType, AppConfig.ContentType.json)
    }
}

private final class APIClientNonHTTPURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: ((URLRequest) -> (URLResponse, Data?))?

    static var responseHandler: ((URLRequest) -> (URLResponse, Data?))? {
        get { lock.withLock { handler } }
        set { lock.withLock { handler = newValue } }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = Self.responseHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
