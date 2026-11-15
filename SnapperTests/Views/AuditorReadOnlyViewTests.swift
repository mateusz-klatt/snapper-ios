import SwiftUI
import UIKit
import UserNotifications
import XCTest
@testable import Snapper

@MainActor
final class AuditorReadOnlyViewTests: XCTestCase {
    private var window: UIWindow?
    private var defaultsSuite: String?

    override func tearDown() async throws {
        window?.isHidden = true
        window?.rootViewController = nil
        window?.windowScene = nil
        window = nil
        try await Task.sleep(for: .milliseconds(50))
        if let defaultsSuite {
            UserDefaults.standard.removePersistentDomain(forName: defaultsSuite)
        }
        defaultsSuite = nil
        try await super.tearDown()
    }

    func testAuditorCanReadPreferencesButCannotChangeControls() async throws {
        let api = MockAPIClient()
        let loads = PreferenceWriteCounter()
        let writes = PreferenceWriteCounter()
        let model = makePreferences(api: api, loads: loads)
        await model.load()
        api.updateAlertDefaultHandler = { _ in
            await writes.record()
            throw APIError.invalidResponse
        }
        let auth = makeAuth(permissions: [.readAllScopes, .readNotifications])
        let view = NotificationPrefsView(viewModel: model)
            .environmentObject(auth)
            .environment(makeAppState(api: api))
            .environment(\.locale, Locale(identifier: "en"))
        let root = try await host(view)
        try await waitFor {
            let loadCount = await loads.count
            let switches = self.controls(UISwitch.self, in: root)
            return loadCount >= 2
                && !model.isLoading
                && model.defaults.count == 5
                && model.devicePrefs.count == 1
                && switches.count == 5
                && switches.allSatisfy { $0.window != nil && $0.isOn && !$0.isEnabled }
        }

        XCTAssertEqual(model.defaults.count, 5)
        XCTAssertEqual(model.devicePrefs.count, 1)
        let toggles = controls(UISwitch.self, in: root)
        XCTAssertTrue(toggles.allSatisfy { !$0.isEnabled })
        let pickers = controls(UISegmentedControl.self, in: root)
        XCTAssertEqual(pickers.count, 5)
        XCTAssertTrue(pickers.allSatisfy { !$0.isEnabled })
        let toggle = try XCTUnwrap(toggles.first)
        toggle.setOn(false, animated: false)
        toggle.sendActions(for: .valueChanged)
        try await Task.sleep(for: .milliseconds(100))
        let writeCount = await writes.count
        XCTAssertEqual(writeCount, 0)
        XCTAssertTrue(model.defaults.values.allSatisfy(\.enabled))
    }

    func testSelfAccountCapabilityEnablesPreferenceChanges() async throws {
        let api = MockAPIClient()
        let loads = PreferenceWriteCounter()
        let writes = PreferenceWriteCounter()
        let model = makePreferences(api: api, loads: loads)
        await model.load()
        let responses = Dictionary(uniqueKeysWithValues: NotificationPrefsViewModel.alertTypes.map { alertType in
            (alertType, UserAlertDefaultResponse(
                type: "user_alert_default_response", sequenceId: 1, publicId: "response",
                timestamp: timestamp, sessionId: "test", topic: nil,
                payload: makeDefault(alertType: alertType, enabled: false)
            ))
        })
        api.updateAlertDefaultHandler = { command in
            await writes.record()
            XCTAssertEqual(command.payload.enabled, false)
            return try XCTUnwrap(responses[command.payload.alertType])
        }
        let auth = makeAuth(permissions: [.readNotifications, .manageSelfAccount])
        let view = NotificationPrefsView(viewModel: model)
            .environmentObject(auth)
            .environment(makeAppState(api: api))
            .environment(\.locale, Locale(identifier: "en"))
        let root = try await host(view)
        try await waitFor {
            let loadCount = await loads.count
            let switches = self.controls(UISwitch.self, in: root)
            return loadCount >= 2
                && !model.isLoading
                && model.defaults.count == 5
                && model.devicePrefs.count == 1
                && switches.count == 5
                && switches.allSatisfy {
                    $0.window != nil && $0.isOn && $0.isEnabled && $0.allControlEvents.contains(.valueChanged)
                }
        }
        try await Task.sleep(for: .milliseconds(50))
        root.layoutIfNeeded()

        let toggles = controls(UISwitch.self, in: root)
        XCTAssertTrue(toggles.allSatisfy(\.isEnabled))
        XCTAssertTrue(controls(UISegmentedControl.self, in: root).allSatisfy(\.isEnabled))
        let toggle = try XCTUnwrap(toggles.first)
        XCTAssertTrue(toggle.allControlEvents.contains(.valueChanged), "Registered events: \(toggle.allControlEvents.rawValue)")
        toggle.setOn(false, animated: false)
        toggle.sendActions(for: .valueChanged)
        try await waitFor { model.defaults.values.contains { !$0.enabled } }
        let writeCount = await writes.count
        XCTAssertEqual(writeCount, 1)
        XCTAssertEqual(model.defaults.values.filter { !$0.enabled }.count, 1)
    }

    func testReadOnlySettingsRefreshesStatusWithoutPromptingOrRegisteringNotifications() async throws {
        let auth = makeAuth(permissions: [.readAllScopes, .readNotifications])
        auth.isAuthenticated = true
        var statusProbes = 0
        var authorizationRequests = 0
        var registrations = 0
        let notificationService = NotificationService(
            authorizationStatusProvider: {
                statusProbes += 1
                return .notDetermined
            },
            authorizationRequester: { _ in
                authorizationRequests += 1
                return false
            },
            isLoggedIn: { auth.isAuthenticated },
            registerForRemote: { registrations += 1 }
        )
        let webSocket = WebSocketManager(
            authService: auth,
            taskFactory: FakeWebSocketTaskFactory(task: FakeWebSocketTask()),
            sleeper: FakeSleeper()
        )
        let view = SettingsView()
            .environmentObject(auth)
            .environmentObject(notificationService)
            .environmentObject(webSocket)
            .environment(makeAppState(api: MockAPIClient()))
            .environment(\.locale, Locale(identifier: "en"))
        let root = try await host(view)
        try await waitFor { statusProbes == 1 && !self.controls(UIScrollView.self, in: root).isEmpty }
        XCTAssertEqual(statusProbes, 1)
        XCTAssertEqual(authorizationRequests, 0)
        XCTAssertEqual(registrations, 0)
        XCTAssertEqual(notificationService.authorizationStatus, .notDetermined)
        XCTAssertEqual(webSocket.connectionState, .disconnected)
    }

    private var timestamp: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func makeAuth(permissions: [Permission]) -> AuthService {
        let auth = AuthService(session: .shared)
        auth.currentUser = makeUser(permissions: permissions)
        return auth
    }

    private func makeUser(permissions: [Permission]) -> UserProfile {
        UserProfile(
            type: nil, sequenceId: 1, publicId: "auditor", timestamp: timestamp,
            sessionId: "test", topic: nil, username: "auditor", email: nil,
            role: .auditor, isActive: true, createdAt: timestamp,
            operatorPublicIds: nil, primaryOperatorPublicId: nil, activeWalletPublicId: nil,
            defaultLanguage: "en", effectivePermissions: permissions, delegatePublicId: nil
        )
    }

    private func makeAppState(api: MockAPIClient) -> AppState {
        let suite = "AuditorReadOnlyViewTests.\(UUID().uuidString)"
        defaultsSuite = suite
        let defaults = UserDefaults(suiteName: suite)!
        return AppState(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["en"] },
            apiClientProvider: { api }
        )
    }

    private func makeDefault(alertType: String, enabled: Bool = true) -> UserAlertDefaultInfo {
        UserAlertDefaultInfo(
            type: "user_alert_default_info", sequenceId: 1, publicId: "default-\(alertType)",
            timestamp: timestamp, sessionId: "test", topic: nil, userPublicId: "auditor",
            alertType: alertType, enabled: enabled, minPriority: "medium"
        )
    }

    private func makePreferences(
        api: MockAPIClient,
        loads: PreferenceWriteCounter
    ) -> NotificationPrefsViewModel {
        let defaults = NotificationPrefsViewModel.alertTypes.map { makeDefault(alertType: $0) }
        let defaultResponse = UserAlertDefaultListResponse(
            type: "user_alert_default_list_response", sequenceId: 1, publicId: "defaults",
            timestamp: timestamp, sessionId: "test", topic: nil, payload: defaults, count: defaults.count
        )
        let pref = DeviceAlertPrefInfo(
            type: "device_alert_pref_info", sequenceId: 1, publicId: "override", timestamp: timestamp,
            sessionId: "test", topic: nil, devicePublicId: "device", alertType: defaults[0].alertType,
            operatorPublicId: nil, walletPublicId: nil, enabled: true, minPriority: "medium",
            quietHoursStartMin: nil, quietHoursEndMin: nil, muteUntil: nil, timezone: "UTC"
        )
        let prefResponse = DeviceAlertPrefListResponse(
            type: "device_alert_pref_list_response", sequenceId: 1, publicId: "preferences",
            timestamp: timestamp, sessionId: "test", topic: nil, payload: [pref], count: 1
        )
        api.fetchAlertDefaultsHandler = {
            await loads.record()
            return defaultResponse
        }
        api.fetchDevicePrefsHandler = { _ in prefResponse }
        return NotificationPrefsViewModel(api: api, deviceIdProvider: { "device" })
    }

    private func host<Content: View>(_ content: Content) async throws -> UIView {
        let controller = UIHostingController(rootView: content)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let hostedWindow = UIWindow(windowScene: scene)
        hostedWindow.frame = CGRect(x: 0, y: 0, width: 430, height: 2400)
        hostedWindow.rootViewController = controller
        hostedWindow.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        window = hostedWindow
        try await waitFor { controller.view.window != nil }
        try await Task.sleep(for: .milliseconds(50))
        controller.view.layoutIfNeeded()
        return controller.view
    }

    private func controls<Control: UIView>(_ type: Control.Type, in view: UIView) -> [Control] {
        let matching = (view as? Control).map { [$0] } ?? []
        return matching + view.subviews.flatMap { controls(type, in: $0) }
    }

    private func waitFor(_ predicate: @MainActor () async -> Bool) async throws {
        for _ in 0..<60 {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        let settled = await predicate()
        XCTAssertTrue(settled, "Hosted view did not reach the expected state")
    }
}

private actor PreferenceWriteCounter {
    private(set) var count = 0

    func record() {
        count += 1
    }
}
