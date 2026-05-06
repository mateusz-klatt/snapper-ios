import XCTest
@testable import Snapper

/// Tests for ``DeviceRegistrationService`` actor (Plan 2 iOS-1).
///
/// Covers the two-input handshake (APNs token + login state) +
/// idempotent re-registration + logout clears state. The APIClient
/// is swapped for a mock-session-backed instance via
/// `MockURLProtocol` so `registerDevice` actually round-trips HTTP
/// under the mocked 200 / 401 / network-error responses.
@MainActor
final class DeviceRegistrationServiceTests: XCTestCase {

    private var mockSession: URLSession!
    private var apiClient: APIClient!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        apiClient = APIClient(session: mockSession, authService: FakeAuthService())
    }

    override func tearDown() {
        mockSession = nil
        apiClient = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    private func drainAsyncWork() async {
        for _ in 0..<30 {
            await Task.yield()
        }
    }

    private func waitForStatus(
        _ service: DeviceRegistrationService,
        matching predicate: (DeviceRegistrationStatus) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> DeviceRegistrationStatus {
        var latest = await service.currentStatus()
        for _ in 0..<100 {
            if predicate(latest) {
                return latest
            }
            await drainAsyncWork()
            try? await Task.sleep(nanoseconds: 1_000_000)
            latest = await service.currentStatus()
        }
        XCTFail("Timed out waiting for registration status; latest was \(latest)", file: file, line: line)
        return latest
    }

    func testStatusTracksAwaitingLoginAwaitingTokenAndIdle() async {
        let service = DeviceRegistrationService(apiClient: apiClient)

        var status = await service.currentStatus()
        XCTAssertEqual(status, .idle)

        await service.onTokenReceived(Data([0x01]))
        status = await service.currentStatus()
        XCTAssertEqual(status, .awaitingLogin)

        await service.onLogout()
        status = await service.currentStatus()
        XCTAssertEqual(status, .idle)

        await service.onLogin()
        status = await service.currentStatus()
        XCTAssertEqual(status, .awaitingToken)
    }

    func testRetryNowIsNoOpWithoutLoginAndToken() async {
        let service = DeviceRegistrationService(apiClient: apiClient)
        var calls = 0
        MockURLProtocol.requestHandler = { _ in
            calls += 1
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.retryNow()
        await service.onLogin()
        await service.retryNow()

        XCTAssertEqual(calls, 0)
        let status = await service.currentStatus()
        XCTAssertEqual(status, .awaitingToken)
    }

    func testRetryNowRegistersWhenLoginAndTokenReady() async {
        let service = DeviceRegistrationService(apiClient: apiClient)
        let token = Data([0x10, 0x20])
        var calls = 0
        MockURLProtocol.requestHandler = { _ in
            calls += 1
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.onLogin()
        await service.onTokenReceived(token)
        await service.retryNow()

        XCTAssertEqual(calls, 2)
        let status = await service.currentStatus()
        XCTAssertEqual(status, .succeeded)
    }

    /// Token received before login → stored; no registration yet.
    func testTokenBeforeLoginStoredButNotRegistered() async {
        let service = DeviceRegistrationService(apiClient: apiClient)
        let token = Data([0x01, 0x02, 0x03, 0x04])

        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.onTokenReceived(token)

        XCTAssertEqual(callCount, 0)
        let pid = await service.currentDevicePublicId()
        XCTAssertNil(pid)
    }

    /// Login before token → flag set; token arriving later triggers register.
    func testLoginBeforeTokenDoesNotRegisterUntilTokenArrives() async {
        let service = DeviceRegistrationService(apiClient: apiClient)
        let token = Data([0x01, 0x02, 0x03, 0x04])

        var calls: [URLRequest] = []
        MockURLProtocol.requestHandler = { request in
            calls.append(request)
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.onLogin()
        XCTAssertEqual(calls.count, 0)

        await service.onTokenReceived(token)
        XCTAssertEqual(calls.count, 1)
        let pid = await service.currentDevicePublicId()
        XCTAssertEqual(pid, "dev-registered-pid")
    }

    /// Token + login both present → registration fires immediately.
    func testTokenThenLoginRegistersOnLogin() async {
        let service = DeviceRegistrationService(apiClient: apiClient)
        let token = Data([0x0a, 0x0b, 0x0c, 0x0d])

        var calls: [URLRequest] = []
        MockURLProtocol.requestHandler = { request in
            calls.append(request)
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.onTokenReceived(token)
        XCTAssertEqual(calls.count, 0)

        await service.onLogin()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].httpMethod, "POST")
    }

    /// Registration POSTs to the `/devices` endpoint.
    func testRegistrationHitsDevicesEndpoint() async {
        let service = DeviceRegistrationService(apiClient: apiClient)
        let token = Data([0xde, 0xad, 0xbe, 0xef])

        var capturedRequests: [URLRequest] = []
        MockURLProtocol.requestHandler = { request in
            capturedRequests.append(request)
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.onLogin()
        await service.onTokenReceived(token)

        XCTAssertEqual(capturedRequests.count, 1)
        XCTAssertEqual(capturedRequests.first?.httpMethod, "POST")
        XCTAssertTrue(
            capturedRequests.first?.url?.path.hasSuffix("/devices") ?? false,
            "expected URL path to end with /devices"
        )
    }

    /// Logout clears both the login flag AND the pending token.
    func testLogoutClearsState() async {
        let service = DeviceRegistrationService(apiClient: apiClient)
        let token = Data([0x01])

        MockURLProtocol.requestHandler = { _ in
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.onLogin()
        await service.onTokenReceived(token)
        await service.onLogout()

        var afterLogoutCalls = 0
        MockURLProtocol.requestHandler = { _ in
            afterLogoutCalls += 1
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }
        await service.onLogin()

        XCTAssertEqual(afterLogoutCalls, 0, "no re-registration after logout cleared the token")
    }

    /// Cross-user-leak guard (PR #5): logout must clear the cached
    /// `lastRegisteredDevicePublicId` so a subsequent user logging
    /// in on the same device cannot transiently surface the prior
    /// user's device id via `currentDevicePublicId()` between
    /// `onLogout()` and the next successful register cycle.
    func testLogoutClearsLastRegisteredDevicePublicId() async {
        let service = DeviceRegistrationService(apiClient: apiClient)
        let token = Data([0x01])

        MockURLProtocol.requestHandler = { _ in
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.onLogin()
        await service.onTokenReceived(token)
        let pidBeforeLogout = await service.currentDevicePublicId()
        XCTAssertEqual(pidBeforeLogout, "dev-registered-pid")

        await service.onLogout()

        let pidAfterLogout = await service.currentDevicePublicId()
        XCTAssertNil(
            pidAfterLogout,
            "lastRegisteredDevicePublicId must clear on logout to prevent cross-user leak when a different user logs in on the same device."
        )
    }

    /// Actor-re-entrancy race (PR #5 fix-up): a registration response
    /// that lands AFTER ``onLogout()`` ran must NOT re-populate
    /// ``lastRegisteredDevicePublicId``. Actors are re-entrant across
    /// ``await``, so the in-flight ``apiClient.registerDevice`` hop
    /// can resume after logout took the actor turn — without an
    /// ``isLoggedIn`` re-check inside ``register()``, the response
    /// would re-stamp the cached id for a session the user already
    /// signed out of.
    func testLogoutDuringRegisterDropsTheResponse() async {
        let service = DeviceRegistrationService(apiClient: apiClient)
        let token = Data([0x42])

        MockURLProtocol.requestHandler = { _ in
            // Hold the URLProtocol thread long enough for onLogout()
            // to run and take the actor turn before the response
            // resolves.
            Thread.sleep(forTimeInterval: 0.2)
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.onLogin()
        // Fire register; the inner await holds for ~200 ms.
        let registerTask = Task { await service.onTokenReceived(token) }

        // Yield long enough for the URLProtocol thread to hit the
        // sleep, then fire logout while register is in flight.
        try? await Task.sleep(nanoseconds: 50_000_000)
        await service.onLogout()

        // Drain the register Task so the test observes the
        // post-response actor state.
        await registerTask.value

        let pid = await service.currentDevicePublicId()
        XCTAssertNil(
            pid,
            "register() must drop the response on the floor when isLoggedIn flipped to false during the await — without this guard the response would re-populate lastRegisteredDevicePublicId for a torn-down session."
        )
    }

    /// Backend 500 error does NOT raise; next attempt re-tries cleanly.
    func testRegistrationServerErrorIsSwallowed() async {
        let service = DeviceRegistrationService(apiClient: apiClient)
        let token = Data([0x01])
        var attempts = 0

        MockURLProtocol.requestHandler = { _ in
            attempts += 1
            if attempts == 1 {
                return MockURLProtocol.errorResponse(statusCode: 500, message: "server down")
            }
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.onLogin()
        await service.onTokenReceived(token)

        let firstPid = await service.currentDevicePublicId()
        XCTAssertNil(firstPid)

        await service.onTokenReceived(token)
        let secondPid = await service.currentDevicePublicId()
        XCTAssertEqual(secondPid, "dev-registered-pid")
    }

    func testFailedRegistrationSchedulesRetryAndEventuallySucceeds() async {
        let sleeper = FakeSleeper()
        let service = DeviceRegistrationService(apiClient: apiClient, sleeper: sleeper)
        let token = Data([0xca, 0xfe])
        var attempts = 0

        MockURLProtocol.requestHandler = { _ in
            attempts += 1
            if attempts == 1 {
                return MockURLProtocol.errorResponse(statusCode: 500, message: "temporary")
            }
            return MockURLProtocol.jsonResponse(statusCode: 200, json: _deviceResponseJSON)
        }

        await service.onLogin()
        await service.onTokenReceived(token)
        let status = await waitForStatus(service) { $0 == .succeeded }

        let pid = await service.currentDevicePublicId()
        XCTAssertEqual(pid, "dev-registered-pid")
        XCTAssertEqual(status, .succeeded)
        let requestedIntervals = await sleeper.requestedIntervals
        XCTAssertEqual(requestedIntervals, [1])
        XCTAssertEqual(attempts, 2)
    }

    func testRegistrationGivesUpAfterRetryBudget() async {
        let sleeper = FakeSleeper()
        let service = DeviceRegistrationService(apiClient: apiClient, sleeper: sleeper)
        let token = Data([0xba, 0xad])
        var attempts = 0

        MockURLProtocol.requestHandler = { _ in
            attempts += 1
            return MockURLProtocol.errorResponse(statusCode: 500, message: "still down")
        }

        await service.onLogin()
        await service.onTokenReceived(token)
        let status = await waitForStatus(service) {
            if case .failed(let attempt, _) = $0 {
                return attempt == 5
            }
            return false
        }

        if case .failed(let attempt, let message) = status {
            XCTAssertEqual(attempt, 5)
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("expected final failed status, got \(status)")
        }
        let requestedIntervals = await sleeper.requestedIntervals
        XCTAssertEqual(requestedIntervals, [1, 4, 16, 60])
        XCTAssertEqual(attempts, 5)
    }

    func testLogoutDuringRegisterDropsTheErrorAndRetrySchedule() async {
        let sleeper = FakeSleeper()
        let service = DeviceRegistrationService(apiClient: apiClient, sleeper: sleeper)
        let token = Data([0x24])

        MockURLProtocol.requestHandler = { _ in
            Thread.sleep(forTimeInterval: 0.2)
            return MockURLProtocol.errorResponse(statusCode: 500, message: "late failure")
        }

        await service.onLogin()
        let registerTask = Task { await service.onTokenReceived(token) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        await service.onLogout()
        await registerTask.value

        let status = await service.currentStatus()
        XCTAssertEqual(status, .idle)
        let requestedIntervals = await sleeper.requestedIntervals
        XCTAssertEqual(requestedIntervals, [])
    }

    func testScheduledRetryIsNoOpAfterLogoutClearsToken() async {
        let sleeper = ManualSleeper()
        let service = DeviceRegistrationService(apiClient: apiClient, sleeper: sleeper)
        let token = Data([0x33])
        var attempts = 0

        MockURLProtocol.requestHandler = { _ in
            attempts += 1
            return MockURLProtocol.errorResponse(statusCode: 500, message: "temporary")
        }

        await service.onLogin()
        await service.onTokenReceived(token)
        await sleeper.waitUntilSleeping()

        await service.onLogout()
        await sleeper.resume()
        await drainAsyncWork()

        XCTAssertEqual(attempts, 1)
        let status = await service.currentStatus()
        XCTAssertEqual(status, .idle)
    }
}

private nonisolated(unsafe) let _deviceResponseJSON: [String: Any] = [
    "type": "notification_device_response",
    "session_id": "s",
    "sequence_id": 1,
    "public_id": "env-1",
    "timestamp": "2026-04-24T12:00:00Z",
    "payload": [
        "session_id": "s",
        "sequence_id": 1,
        "public_id": "dev-registered-pid",
        "timestamp": "2026-04-24T12:00:00Z",
        "user_public_id": "user-1",
        "device_token": "deadbeef",
        "device_id": "did",
        "platform": "ios",
        "env": "sandbox",
        "app_version": "1.0",
        "previews_mode": "private",
        "registered_at": "2026-04-24T12:00:00Z",
        "last_seen_at": nil,
    ],
]

private actor ManualSleeper: Sleeper {
    private var sleepContinuation: CheckedContinuation<Void, Never>?
    private var waitingContinuation: CheckedContinuation<Void, Never>?
    private var isSleeping = false

    func sleep(seconds: TimeInterval) async throws {
        precondition(sleepContinuation == nil, "ManualSleeper only supports one active sleep")
        isSleeping = true
        waitingContinuation?.resume()
        waitingContinuation = nil
        await withCheckedContinuation { continuation in
            sleepContinuation = continuation
        }
    }

    func waitUntilSleeping() async {
        if isSleeping {
            return
        }
        await withCheckedContinuation { continuation in
            precondition(waitingContinuation == nil, "ManualSleeper only supports one pending wait")
            waitingContinuation = continuation
        }
    }

    func resume() {
        guard isSleeping else {
            return
        }
        isSleeping = false
        let continuation = sleepContinuation
        sleepContinuation = nil
        continuation?.resume()
    }
}
