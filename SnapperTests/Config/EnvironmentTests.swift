import XCTest
@testable import Snapper

final class EnvironmentTests: XCTestCase {

    private static let expectedAPIBaseURL = AppConfig.baseURL + AppConfig.apiPrefix
    private static let httpsTestURL = AppConfig.URIScheme.https + "api.example.com"
    private let fullConfiguration: [String: Any] = [
        "BaseURL": "https://api.example.com",
        "APIPrefix": "/v1",
        "WSPath": "/stream",
        "Endpoints": [
            "Login": "/login",
            "Logout": "/logout",
            "Refresh": "/refresh",
            "Me": "/me",
            "Orders": "/orders",
            "Positions": "/positions",
            "Signals": "/signals",
            "Executions": "/executions",
            "Status": "/status",
            "Health": "/health",
            "Devices": "/devices",
            "Alerts": "/alerts",
            "System": "/system",
            "Wallets": "/wallets",
            "AlertDefaults": "/alert-defaults",
            "Operators": "/operators",
            "ExecutionPlans": "/execution-plans",
            "TrailingStops": "/trailing-stops"
        ]
    ]

    func testAPIBaseURL() {
        XCTAssertEqual(AppConfig.apiBaseURL, Self.expectedAPIBaseURL)
        XCTAssertEqual(
            AppConfig.makeAPIBaseURL(baseURL: "https://api.example.com", apiPrefix: "/v1"),
            "https://api.example.com/v1"
        )
    }

    func testWebSocketBaseURL() {

        let wsURL = AppConfig.wsBaseURL
        let expectedProtocol = AppConfig.baseURL.hasPrefix(AppConfig.URIScheme.httpsPrefix)
            ? AppConfig.URIScheme.wss : AppConfig.URIScheme.ws
        XCTAssertTrue(wsURL.starts(with: expectedProtocol))
        let urlWithoutProtocol = AppConfig.baseURL
            .replacingOccurrences(of: AppConfig.URIScheme.http, with: "")
            .replacingOccurrences(of: AppConfig.URIScheme.https, with: "")
        XCTAssertTrue(wsURL.contains(urlWithoutProtocol))
        let expectedWsPath = AppConfig.apiPrefix + AppConfig.wsPath
        XCTAssertTrue(wsURL.contains(expectedWsPath))
    }

    func testWebSocketBaseURLWithHTTPS() {

        let httpsURL = Self.httpsTestURL
        let wsProtocol = httpsURL.hasPrefix(AppConfig.URIScheme.httpsPrefix) ? "wss" : "ws"
        XCTAssertEqual(wsProtocol, "wss")
        XCTAssertEqual(
            AppConfig.makeWSBaseURL(baseURL: "https://api.example.com", apiPrefix: "/v1", wsPath: "/stream"),
            "wss://api.example.com/v1/stream"
        )
        XCTAssertEqual(
            AppConfig.makeWSBaseURL(baseURL: "http://localhost:8000", apiPrefix: "/api", wsPath: "/ws"),
            "ws://localhost:8000/api/ws"
        )
    }

    func testEndpoints() {
        XCTAssertEqual(AppConfig.Endpoints.login, "/auth/login")
        XCTAssertEqual(AppConfig.Endpoints.logout, "/auth/logout")
        XCTAssertEqual(AppConfig.Endpoints.me, "/auth/me")
        XCTAssertEqual(AppConfig.Endpoints.orders, "/orders")
        XCTAssertEqual(AppConfig.Endpoints.positions, "/positions")
        XCTAssertEqual(AppConfig.Endpoints.signals, "/signals")
        XCTAssertEqual(AppConfig.Endpoints.executions, "/executions")
        XCTAssertEqual(AppConfig.Endpoints.status, "/status")
        XCTAssertEqual(AppConfig.Endpoints.health, "/health")
        XCTAssertEqual(AppConfig.Endpoints.devices, "/devices")
        XCTAssertEqual(AppConfig.Endpoints.alerts, "/alerts")
        XCTAssertEqual(AppConfig.Endpoints.system, "/system")
        XCTAssertEqual(AppConfig.Endpoints.wallets, "/wallets")
        XCTAssertEqual(AppConfig.Endpoints.alertDefaults, "/alert_defaults")
        XCTAssertEqual(AppConfig.Endpoints.operators, "/operators")
        XCTAssertEqual(AppConfig.Endpoints.executionPlans, "/execution-plans")
        XCTAssertEqual(AppConfig.Endpoints.trailingStops, "/trailing-stops")
        XCTAssertEqual(AppConfig.HTTPHeader.authorization, "Authorization")
        XCTAssertEqual(AppConfig.ContentType.formURLEncoded, "application/x-www-form-urlencoded")
    }

    func testConfigurationParsingMapsAllFields() {
        let parsed = AppConfig.AppConfiguration.parse(fullConfiguration)

        XCTAssertEqual(parsed.baseURL, "https://api.example.com")
        XCTAssertEqual(parsed.apiPrefix, "/v1")
        XCTAssertEqual(parsed.wsPath, "/stream")
        XCTAssertEqual(parsed.endpoints.login, "/login")
        XCTAssertEqual(parsed.endpoints.logout, "/logout")
        XCTAssertEqual(parsed.endpoints.refresh, "/refresh")
        XCTAssertEqual(parsed.endpoints.me, "/me")
        XCTAssertEqual(parsed.endpoints.orders, "/orders")
        XCTAssertEqual(parsed.endpoints.positions, "/positions")
        XCTAssertEqual(parsed.endpoints.signals, "/signals")
        XCTAssertEqual(parsed.endpoints.executions, "/executions")
        XCTAssertEqual(parsed.endpoints.status, "/status")
        XCTAssertEqual(parsed.endpoints.health, "/health")
        XCTAssertEqual(parsed.endpoints.devices, "/devices")
        XCTAssertEqual(parsed.endpoints.alerts, "/alerts")
        XCTAssertEqual(parsed.endpoints.system, "/system")
        XCTAssertEqual(parsed.endpoints.wallets, "/wallets")
        XCTAssertEqual(parsed.endpoints.alertDefaults, "/alert-defaults")
        XCTAssertEqual(parsed.endpoints.operators, "/operators")
        XCTAssertEqual(parsed.endpoints.executionPlans, "/execution-plans")
        XCTAssertEqual(parsed.endpoints.trailingStops, "/trailing-stops")
    }

    func testConfigurationParsingDefaultsMissingFields() {
        let parsed = AppConfig.AppConfiguration.parse([
            "BaseURL": 123,
            "APIPrefix": "",
            "WSPath": 456,
            "Endpoints": [
                "Login": 789,
                "Orders": "/orders"
            ]
        ], assertOnMissingCriticalFields: false)

        XCTAssertEqual(parsed.baseURL, "")
        XCTAssertEqual(parsed.apiPrefix, "")
        XCTAssertEqual(parsed.wsPath, "")
        XCTAssertEqual(parsed.endpoints.login, "")
        XCTAssertEqual(parsed.endpoints.orders, "/orders")
        XCTAssertEqual(parsed.endpoints.logout, "")
        XCTAssertEqual(parsed.endpoints.trailingStops, "")
    }

    func testConfigurationParsingDefaultsMissingEndpointsBlock() {
        let parsed = AppConfig.AppConfiguration.parse([
            "BaseURL": "https://api.example.com",
            "APIPrefix": "/v1",
            "WSPath": "/stream"
        ])

        XCTAssertEqual(parsed.baseURL, "https://api.example.com")
        XCTAssertEqual(parsed.apiPrefix, "/v1")
        XCTAssertEqual(parsed.wsPath, "/stream")
        XCTAssertEqual(parsed.endpoints.login, "")
        XCTAssertEqual(parsed.endpoints.orders, "")
        XCTAssertEqual(parsed.endpoints.trailingStops, "")
    }

    func testConfigurationParsingAcceptsSingleMissingCriticalFieldWhenAssertionsDisabled() {
        let missingPrefix = AppConfig.AppConfiguration.parse([
            "BaseURL": "https://api.example.com",
            "APIPrefix": "",
            "WSPath": "/stream"
        ], assertOnMissingCriticalFields: false)
        let missingBaseURL = AppConfig.AppConfiguration.parse([
            "BaseURL": "",
            "APIPrefix": "/v1",
            "WSPath": "/stream"
        ], assertOnMissingCriticalFields: false)

        XCTAssertEqual(missingPrefix.baseURL, "https://api.example.com")
        XCTAssertEqual(missingPrefix.apiPrefix, "")
        XCTAssertEqual(missingBaseURL.baseURL, "")
        XCTAssertEqual(missingBaseURL.apiPrefix, "/v1")
    }

    func testConfigurationParsingReportsMissingCriticalFieldsWhenAssertionsEnabled() {
        var assertionMessages: [String] = []
        let parsed = AppConfig.AppConfiguration.parse([
            "BaseURL": "",
            "APIPrefix": "",
            "WSPath": "/stream"
        ], assertionHandler: { assertionMessages.append($0) })

        XCTAssertEqual(parsed.baseURL, "")
        XCTAssertEqual(parsed.apiPrefix, "")
        XCTAssertEqual(assertionMessages.count, 1)
        XCTAssertTrue(assertionMessages[0].contains("missing critical fields"))
    }

    func testConfigurationLoadReturnsEmptyWhenPlistIsMissing() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.snapper.tests.empty</string>
            <key>CFBundlePackageType</key>
            <string>BNDL</string>
        </dict>
        </plist>
        """.utf8).write(to: bundleURL.appendingPathComponent("Info.plist"))
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        var assertionMessages: [String] = []

        let loaded = AppConfig.AppConfiguration.load(
            bundle: bundle,
            assertionHandler: { assertionMessages.append($0) }
        )

        XCTAssertEqual(loaded.baseURL, "")
        XCTAssertEqual(loaded.apiPrefix, "")
        XCTAssertEqual(assertionMessages.count, 1)
        XCTAssertTrue(assertionMessages[0].contains("Failed to load Configuration.plist"))
    }

    func testEmptyConfigurationContainsEmptyValues() {
        let empty = AppConfig.AppConfiguration.empty

        XCTAssertEqual(empty.baseURL, "")
        XCTAssertEqual(empty.apiPrefix, "")
        XCTAssertEqual(empty.wsPath, "")
        XCTAssertEqual(empty.endpoints.login, "")
        XCTAssertEqual(empty.endpoints.logout, "")
        XCTAssertEqual(empty.endpoints.refresh, "")
        XCTAssertEqual(empty.endpoints.me, "")
        XCTAssertEqual(empty.endpoints.orders, "")
        XCTAssertEqual(empty.endpoints.positions, "")
        XCTAssertEqual(empty.endpoints.signals, "")
        XCTAssertEqual(empty.endpoints.executions, "")
        XCTAssertEqual(empty.endpoints.status, "")
        XCTAssertEqual(empty.endpoints.health, "")
        XCTAssertEqual(empty.endpoints.devices, "")
        XCTAssertEqual(empty.endpoints.alerts, "")
        XCTAssertEqual(empty.endpoints.system, "")
        XCTAssertEqual(empty.endpoints.wallets, "")
        XCTAssertEqual(empty.endpoints.alertDefaults, "")
        XCTAssertEqual(empty.endpoints.operators, "")
        XCTAssertEqual(empty.endpoints.executionPlans, "")
        XCTAssertEqual(empty.endpoints.trailingStops, "")
    }
}
