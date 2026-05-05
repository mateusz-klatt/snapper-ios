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

    // MARK: - Wiring tests (refreshAuthorizationStatus → registerForRemote)
    //
    // The pure-helper tests above prove the decision logic. These
    // tests prove the WIRING — that the result of the decision
    // helper actually fires the injected `registerForRemote`
    // closure. They use `_refreshWithStatusForTests` to bypass the
    // simulator UNUserNotificationCenter (which always reports
    // .notDetermined) and pin a chosen status directly.

    /// Granted + logged-in path — the durable APNs re-register hook
    /// fires `registerForRemote()` exactly once. Without this wiring
    /// guard, a future refactor could swap the decision helper for
    /// a different gate and silently break the re-register path.
    func testRefreshFiresRegisterForRemoteWhenAuthorizedAndLoggedIn() {
        var registerCalls = 0
        let service = NotificationService(
            isLoggedIn: { true },
            registerForRemote: { registerCalls += 1 }
        )

        service._refreshWithStatusForTests(.authorized)

        XCTAssertEqual(registerCalls, 1)
        XCTAssertEqual(service.authorizationStatus, .authorized)
    }

    /// `.provisional` mirrors `.authorized` for the re-register
    /// decision — quiet-permission users still get a fresh token
    /// stream after a relaunch.
    func testRefreshFiresRegisterForRemoteWhenProvisionalAndLoggedIn() {
        var registerCalls = 0
        let service = NotificationService(
            isLoggedIn: { true },
            registerForRemote: { registerCalls += 1 }
        )

        service._refreshWithStatusForTests(.provisional)

        XCTAssertEqual(registerCalls, 1)
    }

    /// `.ephemeral` (App Clips push grant) is treated as granted by
    /// `shouldFireDurableRegistration` — pin the wiring test too so
    /// a future refactor that switches `refreshAuthorizationStatus`
    /// to a manual status check (instead of the pure helper) cannot
    /// silently drop `.ephemeral` while the helper test still passes.
    func testRefreshFiresRegisterForRemoteWhenEphemeralAndLoggedIn() {
        var registerCalls = 0
        let service = NotificationService(
            isLoggedIn: { true },
            registerForRemote: { registerCalls += 1 }
        )

        service._refreshWithStatusForTests(.ephemeral)

        XCTAssertEqual(registerCalls, 1)
    }

    /// Logged-out user must NOT trigger `registerForRemote()` —
    /// the backend `/api/devices` register call would 401 without
    /// a session, and worse, the device row could bind to whoever
    /// was previously logged in if the auth state hadn't fully
    /// torn down.
    func testRefreshDoesNotFireRegisterForRemoteWhenLoggedOut() {
        var registerCalls = 0
        let service = NotificationService(
            isLoggedIn: { false },
            registerForRemote: { registerCalls += 1 }
        )

        service._refreshWithStatusForTests(.authorized)

        XCTAssertEqual(registerCalls, 0)
        XCTAssertEqual(
            service.authorizationStatus,
            .authorized,
            "Status is still published for UI even when register-for-remote is suppressed."
        )
    }

    /// `.denied` user must NOT be silently re-prompted — even if
    /// the `registerForRemote()` call is technically harmless
    /// (system would reject), firing it could obscure the actual
    /// permission story in logs / observability.
    func testRefreshDoesNotFireRegisterForRemoteWhenDenied() {
        var registerCalls = 0
        let service = NotificationService(
            isLoggedIn: { true },
            registerForRemote: { registerCalls += 1 }
        )

        service._refreshWithStatusForTests(.denied)

        XCTAssertEqual(registerCalls, 0)
    }

    /// First-launch `.notDetermined` user must NOT be auto-prompted
    /// by the durable-registration hook — the explicit
    /// `requestAuthorization()` flow owns the prompt UX.
    func testRefreshDoesNotFireRegisterForRemoteWhenNotDetermined() {
        var registerCalls = 0
        let service = NotificationService(
            isLoggedIn: { true },
            registerForRemote: { registerCalls += 1 }
        )

        service._refreshWithStatusForTests(.notDetermined)

        XCTAssertEqual(registerCalls, 0)
    }

    /// Repeated calls to the durable-registration hook fire the
    /// closure each time — the OS-side
    /// `UIApplication.registerForRemoteNotifications()` call is
    /// idempotent (Apple guarantees the next available token gets
    /// re-delivered through `AppDelegate`), so we don't need to
    /// debounce on our side. This also covers the cold-relaunch +
    /// foreground scenePhase flow where both hooks fire.
    func testRefreshFiresRegisterForRemoteEveryCallWhenGated() {
        var registerCalls = 0
        let service = NotificationService(
            isLoggedIn: { true },
            registerForRemote: { registerCalls += 1 }
        )

        service._refreshWithStatusForTests(.authorized)
        service._refreshWithStatusForTests(.authorized)
        service._refreshWithStatusForTests(.authorized)

        XCTAssertEqual(registerCalls, 3)
    }
}
