import XCTest
import SwiftUI
import UserNotifications
@testable import Snapper

/// Tests for ``SettingsView`` Notifications section (Plan 2 iOS-5).
///
/// The section surfaces three user-visible paths:
/// - Authorization status colour + label (via `NotificationService`).
/// - Conditional CTA (Request / Open Settings) based on status.
/// - Device registration summary.
///
/// SwiftUI bodies are non-trivially instantiable in xctest, so these
/// tests verify the observable inputs (NotificationService +
/// DeviceRegistrationService) that drive the rendered state.
@MainActor
final class SettingsViewTests: XCTestCase {

    func testNotificationServiceReflectsNotDeterminedOnFreshInstall() {
        let service = NotificationService()
        XCTAssertEqual(service.authorizationStatus, .notDetermined)
        XCTAssertFalse(service.isAuthorized)
    }

    func testDeviceRegistrationServiceStartsUnregistered() async {
        let mockSession = URLSession(configuration: .ephemeral)
        let api = APIClient(session: mockSession, authService: FakeAuthService())
        let service = DeviceRegistrationService(apiClient: api)

        let pid = await service.currentDevicePublicId()

        XCTAssertNil(pid)
    }

    func testRegistrationFailureMessageENSubstitutesAttempt() {
        XCTAssertEqual(
            SettingsView.registrationFailureMessage(attempt: 3, locale: .us),
            "Failed (attempt 3)"
        )
    }

    func testRegistrationFailureMessagePLSubstitutesAttempt() {
        XCTAssertEqual(
            SettingsView.registrationFailureMessage(attempt: 3, locale: .pl),
            "Niepowodzenie (próba 3)"
        )
    }

    func testBundleVersionHelpersUseInfoDictionaryOrLocalizedFallback() {
        let expectedApp = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? LocaleStrings.localized("common.unknown", in: .pl)
        let expectedBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? LocaleStrings.localized("common.unknown", in: .pl)
        XCTAssertEqual(Bundle.main.appVersion(in: .pl), expectedApp)
        XCTAssertEqual(Bundle.main.buildVersion(in: .pl), expectedBuild)
    }

    func testSettingsViewCanBeInstantiatedWithInjectedEnvironment() {
        let view = SettingsView()
            .environmentObject(AuthService.shared)
            .environmentObject(WebSocketManager.shared)
            .environmentObject(NotificationService.shared)

        XCTAssertNotNil(view)
    }
}
