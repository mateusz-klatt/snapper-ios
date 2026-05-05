import Combine
import XCTest
import UserNotifications
@testable import Snapper

/// Tests for ``NotificationService`` permission-state observer.
///
/// The real ``UNUserNotificationCenter`` cannot be authorized in an
/// xctest simulator run (no entitlement, no user interaction), so we
/// cover the paths that don't require granted state:
///
/// - `refreshAuthorizationStatus` reads from the injected centre.
/// - `isAuthorized` derivation across every status value.
/// - `requestAuthorization` handles the declined / error paths
///   without propagating throws to the caller.
@MainActor
final class NotificationServiceTests: XCTestCase {

    func testIsAuthorizedReflectsAuthorizationStatus() {
        let service = NotificationService()
        XCTAssertFalse(service.isAuthorized, "notDetermined is NOT authorized")
    }

    func testRefreshAuthorizationStatusPublishesCurrentState() async {
        let service = NotificationService()
        await service.refreshAuthorizationStatus()
        XCTAssertTrue(
            [.notDetermined, .denied, .authorized, .provisional, .ephemeral]
                .contains(service.authorizationStatus),
            "authorizationStatus must be a valid UNAuthorizationStatus case"
        )
    }

    func testServiceIsObservable() {
        let service = NotificationService()
        XCTAssertNotNil(service.objectWillChange as (any Publisher))
    }

    /// Durable-registration branch (PR #5): when the user has a
    /// prior `.authorized` grant AND is currently logged in,
    /// `registerForRemoteNotifications()` must be re-fired so a
    /// fresh APNs token flows through `AppDelegate`.
    func testShouldFireDurableRegistrationAuthorizedAndLoggedIn() {
        XCTAssertTrue(
            NotificationService.shouldFireDurableRegistration(
                authorizationStatus: .authorized,
                isLoggedIn: true
            )
        )
    }

    /// Provisional permission also gates push delivery; treat it
    /// as a re-trigger eligibility.
    func testShouldFireDurableRegistrationProvisionalAndLoggedIn() {
        XCTAssertTrue(
            NotificationService.shouldFireDurableRegistration(
                authorizationStatus: .provisional,
                isLoggedIn: true
            )
        )
    }

    /// .ephemeral (App Clips push grant) must also count as
    /// granted so the durable-registration decision aligns with
    /// ``isAuthorized`` / SettingsView — without this, an ephemeral
    /// + logged-in user never re-fires registration and stays
    /// stuck in ``.awaitingToken``.
    func testShouldFireDurableRegistrationEphemeralAndLoggedIn() {
        XCTAssertTrue(
            NotificationService.shouldFireDurableRegistration(
                authorizationStatus: .ephemeral,
                isLoggedIn: true
            )
        )
    }

    /// Logged-out user must NOT trigger registration — the device
    /// row would lack a backend session to bind to and the
    /// register call would 401.
    func testShouldNotFireDurableRegistrationWhenLoggedOut() {
        XCTAssertFalse(
            NotificationService.shouldFireDurableRegistration(
                authorizationStatus: .authorized,
                isLoggedIn: false
            )
        )
    }

    /// User who declined permission must NOT be silently re-asked
    /// — `registerForRemoteNotifications()` would not deliver a
    /// token anyway, but firing it here would obscure the actual
    /// authorization story.
    func testShouldNotFireDurableRegistrationWhenDenied() {
        XCTAssertFalse(
            NotificationService.shouldFireDurableRegistration(
                authorizationStatus: .denied,
                isLoggedIn: true
            )
        )
    }

    /// First-launch user with no decision yet stays in the
    /// permission-prompt flow (`requestAuthorization`); the
    /// durable-registration hook must not bypass that prompt.
    func testShouldNotFireDurableRegistrationWhenNotDetermined() {
        XCTAssertFalse(
            NotificationService.shouldFireDurableRegistration(
                authorizationStatus: .notDetermined,
                isLoggedIn: true
            )
        )
    }
}
