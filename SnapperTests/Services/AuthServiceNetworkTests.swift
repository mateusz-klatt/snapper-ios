import XCTest
@testable import Snapper

@MainActor
final class AuthServiceNetworkTests: XCTestCase {

    var authService: AuthService!
    var mockSession: URLSession!
    var injectedAppState: AppState!
    var loginLocaleMock: MockAPIClient!

    override func setUp() {
        super.setUp()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)

        loginLocaleMock = MockAPIClient()
        loginLocaleMock.updateDefaultLanguageHandler = { _ in }
        let mock = loginLocaleMock!
        injectedAppState = AppState(
            userDefaults: UserDefaults(suiteName: "test.AuthServiceNetworkTests.\(UUID().uuidString)")!,
            preferredLanguagesProvider: { ["en"] },
            apiClientProvider: { mock }
        )
        let state = injectedAppState!
        authService = AuthService(
            session: mockSession,
            appStateProvider: { state }
        )
    }

    override func tearDown() {
        authService = nil
        mockSession = nil
        injectedAppState = nil
        loginLocaleMock = nil
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
            XCTAssertNil(authService.error)
            XCTAssertEqual(authService.currentUser?.username, "testuser")
        }
    }

    func testLoginPreservesFuturePermissionWithoutGrantingKnownCapabilities() async throws {
        let futurePermission = "future:manage_teleportation"
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000520",
                "timestamp": "2025-01-01T00:00:00Z",
                "session_id": "session-future-permission",
                "payload": [
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000521",
                    "timestamp": "2025-01-01T00:00:00Z",
                    "session_id": "session-future-permission",
                    "message": "Login successful",
                    "expires_in": 900,
                    "user": [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000522",
                        "timestamp": "2025-01-01T00:00:00Z",
                        "session_id": "session-future-permission",
                        "username": "future-user",
                        "role": "viewer",
                        "is_active": true,
                        "created_at": "2025-01-01T00:00:00Z",
                        "effective_permissions": [futurePermission]
                    ]
                ]
            ]
            return (response, try JSONSerialization.data(withJSONObject: json))
        }

        await authService.login(username: "future-user", password: "testpass")

        XCTAssertTrue(authService.isAuthenticated)
        XCTAssertNil(authService.error)
        XCTAssertEqual(authService.currentUser?.effectivePermissions?.map(\.rawValue), [futurePermission])
        for knownPermission in Permission.allCases {
            XCTAssertFalse(
                authService.hasPermission(knownPermission),
                "Unknown permission must not grant \(knownPermission.rawValue)"
            )
        }
    }

    /// Login MUST persist the locale BEFORE flipping
    /// ``isAuthenticated`` so the first post-login fetch sees the
    /// backend-resolved description in the user's catalog language.
    /// Captures ``isAuthenticated`` inside the mock's
    /// ``updateDefaultLanguage`` handler and asserts it is still
    /// false at that moment.
    func testLoginPersistsLocaleBeforeAuthFlip() async throws {
        let flipObserved = AuthFlipObserver()
        let authRef = authService!
        loginLocaleMock.updateDefaultLanguageHandler = { _ in
            let snapshot = await MainActor.run { authRef.isAuthenticated }
            flipObserved.record(authFlipAtLocalePersist: snapshot)
        }

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

        XCTAssertEqual(flipObserved.snapshot, false, "isAuthenticated must still be false when locale-persist runs.")
        XCTAssertTrue(authService.isAuthenticated, "Login must complete with isAuthenticated true.")
    }

    /// If the post-login locale-persist call invalidates the session
    /// (e.g. the helper triggers ``authService.logout()`` via the
    /// 401 retry path), ``login()`` MUST bail out instead of
    /// flipping ``isAuthenticated`` against a now-invalidated session.
    func testLoginBailsOutWhenLocaleSyncInvalidatesSession() async throws {
        let authRef = authService!
        loginLocaleMock.updateDefaultLanguageHandler = { _ in
            await MainActor.run {
                authRef.currentUser = nil
                authRef.isAuthenticated = false
            }
            throw APIError.httpError(401)
        }

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000510",
                "timestamp": "2025-01-01T00:00:00Z",
                "session_id": "session-2",
                "payload": [
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000511",
                    "timestamp": "2025-01-01T00:00:00Z",
                    "session_id": "session-2",
                    "message": "Login successful",
                    "expires_in": 900,
                    "user": [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000512",
                        "timestamp": "2025-01-01T00:00:00Z",
                        "session_id": "session-2",
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

        XCTAssertFalse(authService.isAuthenticated, "Login must NOT flip isAuthenticated when locale sync invalidated the session.")
        XCTAssertEqual(authService.error, .invalidResponse, "Login surfaces .invalidResponse so the UI can prompt re-auth.")
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
            XCTAssertEqual(authService.error, .serverDetail("Invalid credentials"))
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
            if case .network = authService.error {
                /// network case carries underlying error description.
            } else {
                XCTFail("Expected .network LoginViewError case, got \(String(describing: authService.error))")
            }
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
            XCTAssertEqual(authService.error, .serverDetail("Internal server error"))
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
        XCTAssertEqual(authService.error, .loginFailed)
    }

    func testLoginMalformedSuccessPayloadFailsClosedOverExistingSession() async throws {
        authService.currentUser = Self.refreshTestUser(sessionId: "existing-session")
        authService.isAuthenticated = true
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            return (response, Data("{\"payload\":{}}".utf8))
        }

        await authService.login(username: "testuser", password: "testpass")

        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
        XCTAssertEqual(authService.error, .invalidResponse)
    }

    func testLoginNonHTTPResponseSetsInvalidResponse() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NonHTTPURLProtocol.self]
        let service = AuthService(session: URLSession(configuration: configuration))

        await service.login(username: "testuser", password: "testpass")

        XCTAssertFalse(service.isAuthenticated)
        XCTAssertEqual(service.error, .invalidResponse)
    }

    func testLoginInvalidBaseURLSetsInvalidURL() async {
        let service = AuthService(
            session: mockSession,
            apiBaseURLProvider: { "http://[::1" }
        )

        await service.login(username: "testuser", password: "testpass")

        XCTAssertFalse(service.isAuthenticated)
        XCTAssertEqual(service.error, .invalidURL)
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
        service.currentUser = Self.refreshTestUser(sessionId: "session-invalid-url")
        service.isAuthenticated = true

        let token = await service.fetchFreshWsToken()

        XCTAssertNil(token)
        XCTAssertNil(service.getWsToken())
    }

    func testSelectActiveWalletRefreshesSessionScope() async throws {
        let walletId = "01961234-5678-7000-8000-000000000099"
        let captured = CapturedBody()
        authService.currentUser = UserProfile(
            sequenceId: 1,
            publicId: "01961234-5678-7000-8000-000000000101",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "session-wallet",
            username: "viewer",
            role: .viewer,
            isActive: true,
            createdAt: Date(timeIntervalSince1970: 0),
            effectivePermissions: [.readBacktests]
        )
        MockURLProtocol.requestHandler = { request in
            captured.set(Self.readBody(from: request) ?? Data())
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000102",
                "timestamp": "2025-11-22T11:00:00Z",
                "session_id": "session-wallet",
                "payload": [
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000103",
                    "timestamp": "2025-11-22T11:00:00Z",
                    "session_id": "session-wallet",
                    "message": "Token refreshed",
                    "ws_token": "wallet-ws-token",
                    "ws_token_exp": "2025-11-22T11:15:00Z",
                    "csrf_token": "csrf",
                    "user": [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000101",
                        "timestamp": "2025-01-01T00:00:00Z",
                        "session_id": "session-wallet",
                        "username": "viewer",
                        "role": "viewer",
                        "is_active": true,
                        "created_at": "2025-01-01T00:00:00Z",
                        "active_wallet_public_id": walletId,
                        "effective_permissions": ["read:backtests"]
                    ]
                ]
            ]
            return (response, try JSONSerialization.data(withJSONObject: json))
        }

        let selected = await authService.selectActiveWallet(walletId)

        XCTAssertTrue(selected)
        XCTAssertEqual(authService.currentUser?.activeWalletPublicId, walletId)
        XCTAssertEqual(authService.getWsToken(), "wallet-ws-token")
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: captured.value) as? [String: Any]
        )
        XCTAssertEqual(body["type"] as? String, "refresh_token_request")
        let payload = try XCTUnwrap(body["payload"] as? [String: Any])
        XCTAssertEqual(payload["active_wallet_public_id"] as? String, walletId)
        XCTAssertNil(payload["clear_active_wallet"])
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
        authService.currentUser = Self.refreshTestUser(sessionId: "session-r")
        authService.isAuthenticated = true

        MockURLProtocol.requestHandler = { request in
            counter.increment()
            /// Hold the URLProtocol thread for 100 ms so the second
            /// caller has a deterministic window to enter
            /// fetchFreshWsToken() and find the in-flight slot
            /// populated. URLProtocol.startLoading runs on a
            /// dedicated queue, so blocking here does not stall the
            /// MainActor where the awaiters are parked.
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

    /// Wallet-scoping refreshes cannot coalesce when they request
    /// different active wallets, but they still MUST execute serially.
    /// Refresh cookies are rotated atomically, so overlapping even two
    /// of these requests can invalidate one caller and force logout.
    func testConcurrentWalletSelectionsSerializeRefreshRequests() async throws {
        let probe = ConcurrentRequestProbe()
        let walletIds = [
            "01961234-5678-7000-8000-000000000610",
            "01961234-5678-7000-8000-000000000611",
            "01961234-5678-7000-8000-000000000612"
        ]
        authService.currentUser = UserProfile(
            sequenceId: 1,
            publicId: "01961234-5678-7000-8000-000000000601",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "session-wallet-race",
            username: "viewer",
            role: .viewer,
            isActive: true,
            createdAt: Date(timeIntervalSince1970: 0),
            effectivePermissions: [.readBacktests]
        )

        MockURLProtocol.requestHandler = { request in
            probe.begin()
            defer { probe.end() }
            Thread.sleep(forTimeInterval: 0.1)

            guard let body = Self.readBody(from: request),
                  let envelope = try JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let payload = envelope["payload"] as? [String: Any],
                  let walletId = payload["active_wallet_public_id"] as? String else {
                throw URLError(.cannotParseResponse)
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            let json: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000620",
                "timestamp": "2025-11-22T11:00:00Z",
                "session_id": "session-wallet-race",
                "payload": [
                    "sequence_id": 1,
                    "public_id": "01961234-5678-7000-8000-000000000621",
                    "timestamp": "2025-11-22T11:00:00Z",
                    "session_id": "session-wallet-race",
                    "message": "Token refreshed",
                    "ws_token": "wallet-token-\(walletId)",
                    "ws_token_exp": "2025-11-22T11:15:00Z",
                    "csrf_token": "csrf",
                    "user": [
                        "sequence_id": 1,
                        "public_id": "01961234-5678-7000-8000-000000000601",
                        "timestamp": "2025-01-01T00:00:00Z",
                        "session_id": "session-wallet-race",
                        "username": "viewer",
                        "role": "viewer",
                        "is_active": true,
                        "created_at": "2025-01-01T00:00:00Z",
                        "active_wallet_public_id": walletId,
                        "effective_permissions": ["read:backtests"]
                    ]
                ]
            ]
            return (response, try JSONSerialization.data(withJSONObject: json))
        }

        let firstTask = Task { @MainActor in
            await self.authService.selectActiveWallet(walletIds[0])
        }
        let secondTask = Task { @MainActor in
            await self.authService.selectActiveWallet(walletIds[1])
        }
        let thirdTask = Task { @MainActor in
            await self.authService.selectActiveWallet(walletIds[2])
        }
        let results = await [firstTask.value, secondTask.value, thirdTask.value]

        XCTAssertEqual(results, [true, true, true])
        XCTAssertEqual(probe.callCount, 3)
        XCTAssertEqual(
            probe.maximumActive,
            1,
            "Different wallet payloads must rotate the refresh cookie serially, never concurrently."
        )
    }

    /// A wallet selection already queued on an in-flight refresh must
    /// not start a replacement request after logout invalidates that
    /// session. Concurrent logout callers also await the same teardown
    /// task rather than returning while local auth state is still live.
    func testLogoutDuringRefreshDropsTheRefreshedToken() async throws {
        let refreshCounter = HandlerCallCounter()
        let logoutCounter = HandlerCallCounter()
        let walletId = "01961234-5678-7000-8000-000000000699"
        authService.currentUser = UserProfile(
            sequenceId: 1,
            publicId: "01961234-5678-7000-8000-000000000602",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: "session-r3",
            username: "alice",
            role: .viewer,
            isActive: true,
            createdAt: Date(timeIntervalSince1970: 0),
            effectivePermissions: [.readBacktests]
        )
        authService.isAuthenticated = true

        MockURLProtocol.requestHandler = { request in
            if request.url?.path.hasSuffix(AppConfig.Endpoints.logout) == true {
                logoutCounter.increment()
                Thread.sleep(forTimeInterval: 0.15)
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, nil)
            }

            refreshCounter.increment()
            /// Hold the URLProtocol thread long enough for logout to
            /// cancel the slot while a wallet caller is queued on it.
            Thread.sleep(forTimeInterval: 0.2)

            let requestedWalletId: String?
            if let body = Self.readBody(from: request),
               let envelope = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let payload = envelope["payload"] as? [String: Any] {
                requestedWalletId = payload["active_wallet_public_id"] as? String
            } else {
                requestedWalletId = nil
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [AppConfig.HTTPHeader.contentType: AppConfig.ContentType.json]
            )!
            var user: [String: Any] = [
                "sequence_id": 1,
                "public_id": "01961234-5678-7000-8000-000000000402",
                "timestamp": "2025-01-01T00:00:00Z",
                "session_id": "session-r3",
                "username": "alice",
                "email": "alice@example.com",
                "role": "viewer",
                "is_active": true,
                "created_at": "2025-01-01T00:00:00Z",
                "effective_permissions": ["read:backtests"]
            ]
            if let requestedWalletId {
                user["active_wallet_public_id"] = requestedWalletId
            }
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
                    "user": user
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        let refreshTask = Task { @MainActor in
            await self.authService.fetchFreshWsToken()
        }

        /// Queue a payload refresh behind the generic refresh, then
        /// invalidate both by logging out.
        try await Task.sleep(nanoseconds: 50_000_000)
        let walletTask = Task { @MainActor in
            await self.authService.selectActiveWallet(walletId)
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        let firstLogoutTask = Task { @MainActor in
            await self.authService.logout()
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        let secondLogoutTask = Task { @MainActor in
            await self.authService.logout()
            return self.authService.currentUser == nil &&
                !self.authService.isAuthenticated
        }

        let secondLogoutObservedFinalState = await secondLogoutTask.value
        await firstLogoutTask.value
        let refreshResult = await refreshTask.value
        let walletResult = await walletTask.value

        XCTAssertNil(
            refreshResult,
            "fetchFreshWsToken must return nil when logout cancels the in-flight refresh."
        )
        XCTAssertFalse(
            walletResult,
            "A wallet refresh queued before logout must not create a replacement session afterward."
        )
        XCTAssertEqual(
            refreshCounter.value,
            1,
            "Logout must invalidate queued payload callers instead of letting them issue another refresh."
        )
        XCTAssertTrue(
            secondLogoutObservedFinalState,
            "Every awaited logout caller must return only after local auth state is cleared."
        )
        XCTAssertEqual(
            logoutCounter.value,
            1,
            "Concurrent logout callers must share one server request."
        )
        XCTAssertNil(
            authService.getWsToken(),
            "wsToken must NOT be re-populated by a refresh response that landed after logout — that would bind the next login to the prior session's identity."
        )
        XCTAssertNil(authService.currentUser)
        XCTAssertFalse(authService.isAuthenticated)

        let postLogoutRefresh = await authService.fetchFreshWsToken()
        XCTAssertNil(
            postLogoutRefresh,
            "A late request must not recreate a session after logout has completed."
        )
        XCTAssertEqual(
            refreshCounter.value,
            1,
            "A refresh arriving after local teardown must be rejected without touching the network."
        )
        XCTAssertNil(authService.currentUser)
        XCTAssertFalse(authService.isAuthenticated)
    }

    /// After a refresh completes, the in-flight slot is cleared so
    /// the next refresh window starts fresh. A naive implementation
    /// that latched the slot would wedge the app — every subsequent
    /// 401 would resolve to the cached (now-stale) token and the
    /// retry path would loop or force premature logout.
    func testSubsequentRefreshAfterCompletionStartsNewRequest() async throws {
        let counter = HandlerCallCounter()
        authService.currentUser = Self.refreshTestUser(sessionId: "session-r2")
        authService.isAuthenticated = true

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
        authService.currentUser = Self.refreshTestUser(sessionId: "session-refresh-503")
        authService.isAuthenticated = true

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

    private static func refreshTestUser(sessionId: String) -> UserProfile {
        UserProfile(
            sequenceId: 1,
            publicId: "01961234-5678-7000-8000-000000000090",
            timestamp: Date(timeIntervalSince1970: 0),
            sessionId: sessionId,
            username: "alice",
            role: .viewer,
            isActive: true,
            createdAt: Date(timeIntervalSince1970: 0)
        )
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

/// Tracks both total URLProtocol handler calls and the high-water mark
/// of requests executing at the same time. This catches serialization
/// regressions that a final call-count assertion alone cannot detect.
private final class ConcurrentRequestProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var calls: Int = 0
    private var active: Int = 0
    private var highWaterMark: Int = 0

    func begin() {
        lock.withLock {
            calls += 1
            active += 1
            highWaterMark = max(highWaterMark, active)
        }
    }

    func end() {
        lock.withLock { active -= 1 }
    }

    var callCount: Int {
        lock.withLock { calls }
    }

    var maximumActive: Int {
        lock.withLock { highWaterMark }
    }
}

/// Captures the value of ``AuthService.isAuthenticated`` observed
/// at the moment the locale-persist mock fires. Used to assert
/// that login persists the locale BEFORE flipping the auth state
/// — see ``testLoginPersistsLocaleBeforeAuthFlip``.
private final class AuthFlipObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Bool?
    func record(authFlipAtLocalePersist value: Bool) {
        lock.withLock { storage = value }
    }
    var snapshot: Bool? {
        lock.withLock { storage }
    }
}
