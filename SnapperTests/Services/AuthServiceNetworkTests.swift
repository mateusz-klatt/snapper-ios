import XCTest
@testable import Snapper

@MainActor
final class AuthServiceNetworkTests: XCTestCase {

    var authService: AuthService!
    var mockSession: URLSession!

    override func setUp() {
        super.setUp()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)

        authService = AuthService(session: mockSession)
    }

    override func tearDown() {
        authService = nil
        mockSession = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testLoginSuccess() async throws {

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!

            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000500",
                "timestamp": "2025-01-01T00:00:00Z",
                "session_id": "session-1",
                "payload": [
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000501",
                    "timestamp": "2025-01-01T00:00:00Z",
                    "session_id": "session-1",
                    "message": "Login successful",
                    "expires_in": 900,
                    "user": [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000502",
                        "timestamp": "2025-01-01T00:00:00Z",
                        "session_id": "session-1",
                        "username": "testuser",
                        "email": "test@example.com",
                        "role": "viewer",
                        "is_active": true,
                        "created_at": "2025-01-01T00:00:00Z"
                    ]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)

            return (response, data)
        }

        await authService.login(username: "testuser", password: "testpass")

        await MainActor.run {
            XCTAssertTrue(authService.isAuthenticated)
            XCTAssertNil(authService.errorMessage)
            XCTAssertEqual(authService.currentUser?.username, "testuser")
        }
    }

    func testLoginInvalidCredentials() async throws {

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!

            let json = ["detail": "Invalid credentials"]
            let data = try JSONSerialization.data(withJSONObject: json)

            return (response, data)
        }

        await authService.login(username: "wronguser", password: "wrongpass")

        await MainActor.run {
            XCTAssertFalse(authService.isAuthenticated)
            XCTAssertEqual(authService.errorMessage, "Invalid credentials")
            XCTAssertNil(authService.currentUser)
        }
    }

    func testLoginNetworkError() async throws {

        MockURLProtocol.requestHandler = { request in
            throw MockURLProtocol.networkError()
        }

        await authService.login(username: "testuser", password: "testpass")

        await MainActor.run {
            XCTAssertFalse(authService.isAuthenticated)
            XCTAssertNotNil(authService.errorMessage)
            XCTAssertTrue(authService.errorMessage?.contains("Network") ?? false)
        }
    }

    func testLoginServerError() async throws {

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!

            let json = ["detail": "Internal server error"]
            let data = try JSONSerialization.data(withJSONObject: json)

            return (response, data)
        }

        await authService.login(username: "testuser", password: "testpass")

        await MainActor.run {
            XCTAssertFalse(authService.isAuthenticated)
            XCTAssertEqual(authService.errorMessage, "Internal server error")
        }
    }

    func testLoginFailureWithoutDetailFallsBackToGenericMessage() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            let data = try JSONSerialization.data(withJSONObject: ["unexpected": "shape"])
            return (response, data)
        }

        await authService.login(username: "testuser", password: "testpass")

        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertEqual(authService.errorMessage, "Login failed")
    }

    func testLoginNonHTTPResponseSetsInvalidResponse() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NonHTTPURLProtocol.self]
        let service = AuthService(session: URLSession(configuration: configuration))

        await service.login(username: "testuser", password: "testpass")

        XCTAssertFalse(service.isAuthenticated)
        XCTAssertEqual(service.errorMessage, "Invalid response")
    }

    func testLoginInvalidBaseURLSetsInvalidURL() async {
        let service = AuthService(
            session: mockSession,
            apiBaseURLProvider: { "http://[::1" }
        )

        await service.login(username: "testuser", password: "testpass")

        XCTAssertFalse(service.isAuthenticated)
        XCTAssertEqual(service.errorMessage, "Invalid URL")
    }

    func testLogoutNetworkFailureStillClearsLocalState() async {
        MockURLProtocol.requestHandler = { _ in
            throw MockURLProtocol.networkError()
        }

        await authService.logout()

        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
        XCTAssertNil(authService.getWsToken())
    }

    func testLogoutInvalidBaseURLStillClearsLocalState() async {
        let service = AuthService(
            session: mockSession,
            apiBaseURLProvider: { "http://[::1" }
        )

        await service.logout()

        XCTAssertFalse(service.isAuthenticated)
        XCTAssertNil(service.currentUser)
        XCTAssertNil(service.getWsToken())
    }

    func testFetchFreshWsTokenInvalidBaseURLReturnsNil() async {
        let service = AuthService(
            session: mockSession,
            apiBaseURLProvider: { "http://[::1" }
        )

        let token = await service.fetchFreshWsToken()

        XCTAssertNil(token)
        XCTAssertNil(service.getWsToken())
    }

    /// Regression guard for the envelope/provenance contract enforced
    /// by ``snapper.api.schemas.base.StrictDataSchema``: outbound
    /// login requests must wrap credentials inside ``payload`` and
    /// stamp top-level provenance fields. A reverted change to plain
    /// ``{username, password}`` body would resurrect the production
    /// HTTP 422 we hit previously.
    func testLoginRequestUsesEnvelopeWithProvenanceAndNoTopLevelCredentials() async throws {
        let captured = CapturedBody()

        MockURLProtocol.requestHandler = { request in
            let body = Self.readBody(from: request) ?? Data()
            captured.set(body)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            let stub = try JSONSerialization.data(withJSONObject: ["detail": "stub"])
            return (response, stub)
        }

        await authService.login(username: "alice", password: "s3cret")

        let bodyData = captured.value
        XCTAssertGreaterThan(bodyData.count, 0, "Login request body must not be empty.")

        let parsed = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertNotNil(parsed, "Login body must be a JSON object envelope.")
        guard let parsed else { return }

        XCTAssertNil(parsed["username"], "Username must NOT appear at the top level.")
        XCTAssertNil(parsed["password"], "Password must NOT appear at the top level.")

        XCTAssertEqual(parsed["type"] as? String, "login_request")
        XCTAssertNotNil(parsed["public_id"] as? String)
        XCTAssertNotNil(parsed["session_id"] as? String)
        XCTAssertTrue(parsed["sequence_id"] is Int || parsed["sequence_id"] is NSNumber)
        XCTAssertNotNil(parsed["timestamp"] as? String)

        let payload = parsed["payload"] as? [String: Any]
        XCTAssertEqual(payload?["username"] as? String, "alice")
        XCTAssertEqual(payload?["password"] as? String, "s3cret")
    }

    /// Concurrent 401 retry path (PR #3): two callers that both arrive
    /// at ``fetchFreshWsToken()`` while a refresh is in flight must
    /// coalesce into a single network request. Without coalescing,
    /// parallel REST calls (e.g. ``HomeView.loadData``'s
    /// ``async let`` orders + positions) each hitting 401 stampede
    /// the refresh endpoint and can race their way into a double
    /// logout when the second refresh sees the just-rotated session.
    func testConcurrentRefreshCallersCoalesceIntoSingleRequest() async throws {
        let counter = HandlerCallCounter()

        MockURLProtocol.requestHandler = { request in
            counter.increment()
            // Hold the URLProtocol thread for 100 ms so the second
            // caller has a deterministic window to enter
            // fetchFreshWsToken() and find the in-flight slot
            // populated. URLProtocol.startLoading runs on a
            // dedicated queue, so blocking here does not stall the
            // MainActor where the awaiters are parked.
            Thread.sleep(forTimeInterval: 0.1)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000200",
                "timestamp": "2025-11-22T11:00:00Z",
                "session_id": "session-r",
                "payload": [
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000201",
                    "timestamp": "2025-11-22T11:00:00Z",
                    "session_id": "session-r",
                    "message": "Token refreshed",
                    "ws_token": "fresh-ws-token",
                    "ws_token_exp": "2025-11-22T11:15:00Z",
                    "csrf_token": "csrf",
                    "user": [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000202",
                        "timestamp": "2025-01-01T00:00:00Z",
                        "session_id": "session-r",
                        "username": "alice",
                        "email": "alice@example.com",
                        "role": "viewer",
                        "is_active": true,
                        "created_at": "2025-01-01T00:00:00Z"
                    ]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        let firstTask = Task { @MainActor in
            await self.authService.fetchFreshWsToken()
        }
        let secondTask = Task { @MainActor in
            await self.authService.fetchFreshWsToken()
        }
        let first = await firstTask.value
        let second = await secondTask.value

        XCTAssertEqual(first, "fresh-ws-token")
        XCTAssertEqual(second, "fresh-ws-token")
        XCTAssertEqual(
            counter.value,
            1,
            "Concurrent refresh callers must coalesce into a single network request, not stampede the refresh endpoint."
        )
    }

    /// Logout-during-refresh race (PR #3 fix-up): a logout that
    /// fires while a refresh is in flight must NOT let the
    /// refresh's freshly-minted ws_token re-stamp ``wsToken`` after
    /// the local session is torn down. The ``Task.isCancelled``
    /// gate protects the slot write so a stale refresh response
    /// is dropped on the floor — without this, the next login on
    /// the same install would bind to the prior session's identity
    /// for the lifetime of the leaked token.
    func testLogoutDuringRefreshDropsTheRefreshedToken() async throws {
        MockURLProtocol.requestHandler = { request in
            // Hold the URLProtocol thread long enough for logout to
            // run and cancel the refresh task. 200 ms is generous —
            // logout's local mutations are sub-millisecond.
            Thread.sleep(forTimeInterval: 0.2)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000400",
                "timestamp": "2025-11-22T11:00:00Z",
                "session_id": "session-r3",
                "payload": [
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000401",
                    "timestamp": "2025-11-22T11:00:00Z",
                    "session_id": "session-r3",
                    "message": "Token refreshed",
                    "ws_token": "post-logout-token",
                    "ws_token_exp": "2025-11-22T11:15:00Z",
                    "csrf_token": "csrf",
                    "user": [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000402",
                        "timestamp": "2025-01-01T00:00:00Z",
                        "session_id": "session-r3",
                        "username": "alice",
                        "email": "alice@example.com",
                        "role": "viewer",
                        "is_active": true,
                        "created_at": "2025-01-01T00:00:00Z"
                    ]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        let refreshTask = Task { @MainActor in
            await self.authService.fetchFreshWsToken()
        }

        // Yield long enough for the refresh task to enter the
        // URLProtocol sleep window, then fire logout.
        try await Task.sleep(nanoseconds: 50_000_000)
        await authService.logout()

        let refreshResult = await refreshTask.value

        XCTAssertNil(
            refreshResult,
            "fetchFreshWsToken must return nil when logout cancels the in-flight refresh."
        )
        XCTAssertNil(
            authService.getWsToken(),
            "wsToken must NOT be re-populated by a refresh response that landed after logout — that would bind the next login to the prior session's identity."
        )
    }

    /// After a refresh completes, the in-flight slot is cleared so
    /// the next refresh window starts fresh. A naive implementation
    /// that latched the slot would wedge the app — every subsequent
    /// 401 would resolve to the cached (now-stale) token and the
    /// retry path would loop or force premature logout.
    func testSubsequentRefreshAfterCompletionStartsNewRequest() async throws {
        let counter = HandlerCallCounter()

        MockURLProtocol.requestHandler = { request in
            counter.increment()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000300",
                "timestamp": "2025-11-22T11:00:00Z",
                "session_id": "session-r2",
                "payload": [
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000301",
                    "timestamp": "2025-11-22T11:00:00Z",
                    "session_id": "session-r2",
                    "message": "Token refreshed",
                    "ws_token": "fresh-ws-token-\(counter.value)",
                    "ws_token_exp": "2025-11-22T11:15:00Z",
                    "csrf_token": "csrf",
                    "user": [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000302",
                        "timestamp": "2025-01-01T00:00:00Z",
                        "session_id": "session-r2",
                        "username": "alice",
                        "email": "alice@example.com",
                        "role": "viewer",
                        "is_active": true,
                        "created_at": "2025-01-01T00:00:00Z"
                    ]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        _ = await authService.fetchFreshWsToken()
        _ = await authService.fetchFreshWsToken()

        XCTAssertEqual(
            counter.value,
            2,
            "Sequential refresh calls must each fire a network request — the in-flight slot is cleared on completion."
        )
    }

    func testFetchFreshWsTokenNonSuccessReturnsNil() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            let data = try JSONSerialization.data(withJSONObject: ["detail": "offline"])
            return (response, data)
        }

        let token = await authService.fetchFreshWsToken()

        XCTAssertNil(token)
        XCTAssertNil(authService.getWsToken())
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

private final class NonHTTPURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let response = URLResponse(
            url: request.url!,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Captures bytes from inside the URLProtocol handler closure into a
/// thread-safe holder the test body can read after ``login()`` returns.
private final class CapturedBody: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: Data = Data()

    func set(_ data: Data) {
        lock.withLock { bytes = data }
    }

    var value: Data {
        lock.withLock { bytes }
    }
}

/// Counts handler invocations across the URLProtocol queue + the
/// MainActor that issues `await fetchFreshWsToken()`. NSLock-backed
/// so the URLProtocol thread can mutate the counter safely while the
/// MainActor reads it for assertion.
private final class HandlerCallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count: Int = 0

    func increment() {
        lock.withLock { count += 1 }
    }

    var value: Int {
        lock.withLock { count }
    }
}
