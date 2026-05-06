import XCTest
@testable import Snapper

/// Behavioral tests for the ``X-CSRF-Token`` header attachment in
/// ``APIClient``.
///
/// The backend's cookie-auth path (see
/// ``snapper.auth.dependencies.validate_csrf_token``) requires
/// double-submit CSRF on every state-changing HTTP method. Before
/// this change, every iOS-driven mutation against ``/api/devices``
/// 403'd silently because the header was missing. These tests pin
/// down the four-cell matrix:
///
/// 1. Safe method (GET/HEAD) + cookie present → no header (the
///    backend exempts safe methods).
/// 2. Non-safe method + cookie present and matching host → header
///    set to the cookie value.
/// 3. Non-safe method + cookie absent → no header (let the backend
///    return its native 403 instead of forging an empty value).
/// 4. Non-safe method + cookie present but for a different host →
///    no header (cross-host cookies must not leak after a
///    backend-URL switch).
final class APIClientCSRFTests: XCTestCase {

    private let target = URL(string: "https://api.example.com/api/orders")!
    private let foreignTarget = URL(string: "https://other.example.com/api/orders")!

    override func setUp() {
        super.setUp()
        clearCookies(for: target)
        clearCookies(for: foreignTarget)
    }

    override func tearDown() {
        clearCookies(for: target)
        clearCookies(for: foreignTarget)
        super.tearDown()
    }

    func testGetRequestSkipsCSRFHeaderEvenWhenCookieIsPresent() {
        setCSRFCookie(value: "ignored-for-get", on: target)
        var request = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &request, method: "GET")
        XCTAssertNil(request.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken))
    }

    func testHeadRequestSkipsCSRFHeaderEvenWhenCookieIsPresent() {
        setCSRFCookie(value: "ignored-for-head", on: target)
        var request = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &request, method: "HEAD")
        XCTAssertNil(request.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken))
    }

    func testPostRequestAttachesCSRFHeaderFromMatchingCookie() {
        setCSRFCookie(value: "csrf-token-abc", on: target)
        var request = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &request, method: "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken),
            "csrf-token-abc"
        )
    }

    func testPatchRequestAttachesCSRFHeaderFromMatchingCookie() {
        setCSRFCookie(value: "csrf-token-patch", on: target)
        var request = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &request, method: "PATCH")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken),
            "csrf-token-patch"
        )
    }

    func testDeleteRequestAttachesCSRFHeaderFromMatchingCookie() {
        setCSRFCookie(value: "csrf-token-delete", on: target)
        var request = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &request, method: "DELETE")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken),
            "csrf-token-delete"
        )
    }

    func testLowercaseMethodIsTreatedAsSafeWhenItResolvesToGetOrHead() {
        setCSRFCookie(value: "ignored", on: target)
        var lowercaseGet = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &lowercaseGet, method: "get")
        XCTAssertNil(lowercaseGet.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken))

        var lowercaseHead = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &lowercaseHead, method: "head")
        XCTAssertNil(lowercaseHead.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken))
    }

    func testLowercasePostMethodAttachesCSRFHeader() {
        setCSRFCookie(value: "lower-post", on: target)
        var request = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &request, method: "post")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken),
            "lower-post"
        )
    }

    func testNonSafeRequestSkipsCSRFHeaderWhenCookieIsAbsent() {
        var request = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &request, method: "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken))
    }

    func testNonSafeRequestSkipsCSRFHeaderWhenOnlyForeignHostHasCookie() {
        setCSRFCookie(value: "leaked-from-other-host", on: foreignTarget)
        var request = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &request, method: "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken))
    }

    func testNonSafeRequestUsesTargetHostCookieWhenBothHostsHaveCookies() {
        setCSRFCookie(value: "target-host-token", on: target)
        setCSRFCookie(value: "foreign-host-token", on: foreignTarget)
        var request = URLRequest(url: target)
        APIClient.attachCSRFHeader(to: &request, method: "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken),
            "target-host-token"
        )
    }

    func testRequestWithoutURLNoOps() {
        var request = URLRequest(url: target)
        request.url = nil
        APIClient.attachCSRFHeader(to: &request, method: "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken))
    }

    func testIntegrationFullRequestPathCarriesCSRFHeaderForMutation() async throws {
        let apiBase = "https://api.example.com/api"
        setCSRFCookie(
            value: "wire-token-xyz",
            on: URL(string: "\(apiBase)/devices")!
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = APIClient(
            session: session,
            authService: FakeAuthService(nextToken: "fresh-token"),
            apiBaseURLProvider: { apiBase }
        )

        let captured = CapturedRequestBox()
        MockURLProtocol.requestHandler = { request in
            captured.set(request)
            return MockURLProtocol.jsonResponse(
                statusCode: 200,
                json: [
                    "sequence_id": 1,
                    "public_id": "env-1",
                    "timestamp": "2026-01-01T00:00:00Z",
                    "session_id": "session-1",
                    "payload": [
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
                ]
            )
        }

        defer { MockURLProtocol.requestHandler = nil }

        let command = RegisterDeviceCommand(
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
        _ = try await client.registerDevice(command: command)

        let recorded = try XCTUnwrap(captured.value)
        XCTAssertEqual(
            recorded.value(forHTTPHeaderField: AppConfig.HTTPHeader.xCSRFToken),
            "wire-token-xyz"
        )
    }

    private func setCSRFCookie(value: String, on url: URL) {
        let host = url.host ?? "localhost"
        let cookie = HTTPCookie(properties: [
            .domain: host,
            .path: "/",
            .name: AppConfig.CookieName.csrfToken,
            .value: value,
            .secure: "TRUE"
        ])!
        HTTPCookieStorage.shared.setCookie(cookie)
    }

    private func clearCookies(for url: URL) {
        let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}

private final class CapturedRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: URLRequest?

    func set(_ request: URLRequest) {
        lock.withLock { stored = request }
    }

    var value: URLRequest? {
        lock.withLock { stored }
    }
}
