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
        window = nil
        if let defaultsSuite {
            UserDefaults.standard.removePersistentDomain(forName: defaultsSuite)
        }
        defaultsSuite = nil
        try await super.tearDown()
    }

    func testAuditorCanReadPreferencesButCannotChangeControls() async throws {
        let api = MockAPIClient()
        let writes = PreferenceWriteCounter()
        let model = makePreferences(api: api)
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
        let root = try host(view)
        try await waitFor {
            self.controls(UISwitch.self, in: root).count == 5 && model.defaults.count == 5 && model.devicePrefs.count == 1
        }

        XCTAssertEqual(model.defaults.count, 5)
        XCTAssertEqual(model.devicePrefs.count, 1)
        let toggles = controls(UISwitch.self, in: root)
        XCTAssertTrue(toggles.allSatisfy { !$0.isEnabled })
        let pickers = controls(UISegmentedControl.self, in: root)
        XCTAssertEqual(pickers.count, 5)
        XCTAssertTrue(pickers.allSatisfy { !$0.isEnabled })
        let labels = accessibilityLabels(in: root)
        XCTAssertTrue(labels.contains(readOnlyNotice), "Available labels: \(labels.sorted())")

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
        let writes = PreferenceWriteCounter()
        let model = makePreferences(api: api)
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
        let root = try host(view)
        try await waitFor {
            self.controls(UISwitch.self, in: root).count == 5 && model.defaults.count == 5 && model.devicePrefs.count == 1
        }

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

    func testSettingsShowsReadOnlyNoticeAndHidesNotificationRegistrationUntilGranted() async throws {
        let auth = makeAuth(permissions: [.readAllScopes, .readNotifications])
        let notificationService = NotificationService(
            authorizationStatusProvider: { .notDetermined },
            authorizationRequester: { _ in
                XCTFail("Rendering settings must not request notification authorization")
                return false
            },
            isLoggedIn: { false },
            registerForRemote: { XCTFail("Rendering read-only settings must not register push") }
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
        let root = try host(view)
        try await waitFor { self.accessibilityLabels(in: root).contains(self.readOnlyNotice) }
        let readOnlyLabels = accessibilityLabels(in: root)
        XCTAssertTrue(readOnlyLabels.contains(readOnlyNotice), "Available labels: \(readOnlyLabels.sorted())")
        let enableLabel = LocaleStrings.localized("settings.notifications.enableButton", in: .en)
        XCTAssertFalse(accessibilityLabels(in: root).contains(enableLabel))

        auth.currentUser = makeUser(permissions: [.readNotifications, .manageSelfAccount])
        try await waitFor { self.accessibilityLabels(in: root).contains(enableLabel) }
        let writableLabels = accessibilityLabels(in: root)
        XCTAssertTrue(writableLabels.contains(enableLabel), "Available labels: \(writableLabels.sorted())")
        XCTAssertFalse(accessibilityLabels(in: root).contains(readOnlyNotice))
        XCTAssertEqual(notificationService.authorizationStatus, .notDetermined)
        XCTAssertEqual(webSocket.connectionState, .disconnected)
    }

    private var timestamp: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private var readOnlyNotice: String {
        LocaleStrings.localized("settings.account.readOnly", in: .en)
    }

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

    private func makePreferences(api: MockAPIClient) -> NotificationPrefsViewModel {
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
        api.fetchAlertDefaultsHandler = { defaultResponse }
        api.fetchDevicePrefsHandler = { _ in prefResponse }
        return NotificationPrefsViewModel(api: api, deviceIdProvider: { "device" })
    }

    private func host<Content: View>(_ content: Content) throws -> UIView {
        let controller = UIHostingController(rootView: content)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let hostedWindow = UIWindow(windowScene: scene)
        hostedWindow.frame = CGRect(x: 0, y: 0, width: 430, height: 2400)
        hostedWindow.rootViewController = controller
        hostedWindow.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        window = hostedWindow
        return controller.view
    }

    private func controls<Control: UIView>(_ type: Control.Type, in view: UIView) -> [Control] {
        let matching = (view as? Control).map { [$0] } ?? []
        return matching + view.subviews.flatMap { controls(type, in: $0) }
    }

    private func accessibilityLabels(in root: NSObject) -> Set<String> {
        var pending = [root]
        var visited = Set<ObjectIdentifier>()
        var labels = Set<String>()
        while let object = pending.popLast() {
            guard visited.insert(ObjectIdentifier(object)).inserted else { continue }
            if let label = object.accessibilityLabel { labels.insert(label) }
            if let view = object as? UIView { pending.append(contentsOf: view.subviews) }
            if let elements = object.accessibilityElements {
                pending.append(contentsOf: elements.compactMap { $0 as? NSObject })
            }
            let count = object.accessibilityElementCount()
            if count > 0 && count < 1000 {
                for index in 0..<count {
                    if let element = object.accessibilityElement(at: index) as? NSObject {
                        pending.append(element)
                    }
                }
            }
        }
        return labels
    }

    private func waitFor(_ predicate: @MainActor () -> Bool) async throws {
        for _ in 0..<40 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(predicate(), "Hosted view did not reach the expected state")
    }
}

private actor PreferenceWriteCounter {
    private(set) var count = 0

    func record() {
        count += 1
    }
}
