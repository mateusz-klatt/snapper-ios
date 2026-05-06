import Foundation
import UserNotifications
import UIKit
import os

/// Observable facade for UNUserNotificationCenter state.
///
/// Owns the permission prompt lifecycle + exposes `authorizationStatus` as
/// a `@Published` field so SwiftUI can render "Notifications off" banners
/// or settings-link hints. The actual APNs token plumbing lives in
/// `AppDelegate` (application delegate is required for `didRegisterForRemoteNotificationsWithDeviceToken`);
/// this service is the user-facing layer.
///
/// Lazy shared instance — safe to touch from any `@MainActor` context
/// (SnapperApp `@StateObject`, settings views, auth hooks). Not an actor;
/// UserNotifications APIs are main-actor-friendly on iOS 17+.
@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Snapper",
        category: "Notifications"
    )
    private let authorizationStatusProvider: @MainActor () async -> UNAuthorizationStatus
    private let authorizationRequester: @MainActor (UNAuthorizationOptions) async throws -> Bool
    private let isLoggedIn: () -> Bool
    private let registerForRemote: () -> Void

    /// Current UNUserNotificationCenter authorization status.
    ///
    /// `.notDetermined` until the first permission probe. Updated via
    /// `refreshAuthorizationStatus()` on app launch + after every
    /// `requestAuthorization()` / `Settings.app` round-trip.
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Test seam — production wiring keeps the closures pinned to
    /// ``AuthService.shared`` and ``UIApplication.shared`` so the
    /// public initializer matches the prior contract. Tests inject
    /// their own closures to verify the durable-registration path
    /// without an actual UIApplication round-trip.
    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        isLoggedIn: @escaping () -> Bool = { AuthService.shared.isAuthenticated },
        registerForRemote: @escaping () -> Void = {
            UIApplication.shared.registerForRemoteNotifications()
        }
    ) {
        self.authorizationStatusProvider = {
            let settings = await notificationCenter.notificationSettings()
            return settings.authorizationStatus
        }
        self.authorizationRequester = { options in
            try await notificationCenter.requestAuthorization(options: options)
        }
        self.isLoggedIn = isLoggedIn
        self.registerForRemote = registerForRemote
    }

    init(
        authorizationStatusProvider: @MainActor @escaping () async -> UNAuthorizationStatus,
        authorizationRequester: @MainActor @escaping (UNAuthorizationOptions) async throws -> Bool,
        isLoggedIn: @escaping () -> Bool = { AuthService.shared.isAuthenticated },
        registerForRemote: @escaping () -> Void = {
            UIApplication.shared.registerForRemoteNotifications()
        }
    ) {
        self.authorizationStatusProvider = authorizationStatusProvider
        self.authorizationRequester = authorizationRequester
        self.isLoggedIn = isLoggedIn
        self.registerForRemote = registerForRemote
    }

    /// Read the current authorization status and publish it.
    ///
    /// Called from app launch + from `SettingsView` every time the
    /// screen appears so a permission flipped via Settings.app shows
    /// up without a restart, AND from `SnapperApp.handleScenePhase`
    /// every time the app returns to `.active` so a cold-relaunch
    /// of an already-authorized + logged-in user re-fires the APNs
    /// registration. Without that re-trigger, a user who granted
    /// permission in a prior session, logged out, then logged back
    /// in stays stuck in `.awaitingToken` forever — the system
    /// only delivers a fresh APNs token in response to an explicit
    /// `registerForRemoteNotifications()` call.
    func refreshAuthorizationStatus() async {
        self.authorizationStatus = await authorizationStatusProvider()

        if Self.shouldFireDurableRegistration(
            authorizationStatus: self.authorizationStatus,
            isLoggedIn: isLoggedIn()
        ) {
            registerForRemote()
        }
    }

    /// Pure decision helper for the durable-registration branch:
    /// returns ``true`` iff the user has previously granted
    /// notification permission AND is currently logged in, in
    /// which case ``registerForRemoteNotifications()`` must be
    /// re-fired so a fresh APNs token flows through ``AppDelegate``.
    /// Extracted out of ``refreshAuthorizationStatus`` so the
    /// decision is unit-testable without an actual
    /// ``UNUserNotificationCenter`` round-trip.
    ///
    /// ``.ephemeral`` (App Clips push grant) is treated as granted
    /// for parity with ``isAuthorized`` / ``SettingsView`` — without
    /// this, an .ephemeral + logged-in user would never re-fire
    /// registration and stay stuck in ``.awaitingToken``.
    static func shouldFireDurableRegistration(
        authorizationStatus: UNAuthorizationStatus,
        isLoggedIn: Bool
    ) -> Bool {
        let granted: Bool = (authorizationStatus == .authorized
            || authorizationStatus == .provisional
            || authorizationStatus == .ephemeral)
        return granted && isLoggedIn
    }

    /// Prompt the user for notification permission + register for APNs.
    ///
    /// When the user grants, triggers
    /// `UIApplication.registerForRemoteNotifications()` on the main
    /// thread so the AppDelegate's
    /// `didRegisterForRemoteNotificationsWithDeviceToken` fires and
    /// the token flows to `DeviceRegistrationService`.
    ///
    /// When the user denies, the status is published and the caller
    /// can surface an inline hint to Settings.app. The method never
    /// throws — denied / error statuses are represented via the
    /// `@Published authorizationStatus` field.
    func requestAuthorization() async {
        do {
            _ = try await authorizationRequester([.alert, .sound, .badge])
            // refreshAuthorizationStatus already fires registerForRemote
            // when the post-grant status is granted AND the user is
            // logged in, so we let it own the registration call —
            // routing through the injected closure here too keeps the
            // grant + durable paths aligned, prevents a back-to-back
            // double registerForRemoteNotifications() call after the
            // user accepts the prompt while logged in, and lets tests
            // assert the call count via the same seam.
            await refreshAuthorizationStatus()
            if !isAuthorized {
                logger.info("User declined notification permission")
            }
        } catch {
            logger.error("Notification permission request failed: \(error)")
            await refreshAuthorizationStatus()
        }
    }

    /// True iff permission granted AND APNs token present in device list.
    ///
    /// Derived from `authorizationStatus` only — a token's presence is
    /// a `DeviceRegistrationService` concern. Kept here as a
    /// convenience boolean for UI. ``.ephemeral`` is included so the
    /// flag matches the durable-registration decision in
    /// ``shouldFireDurableRegistration``.
    var isAuthorized: Bool {
        authorizationStatus == .authorized
            || authorizationStatus == .provisional
            || authorizationStatus == .ephemeral
    }

    #if DEBUG
    /// Test-only seam: directly drive ``refreshAuthorizationStatus``
    /// for a chosen post-settings status without going through the
    /// real ``UNUserNotificationCenter``.
    ///
    /// The simulator UNUserNotificationCenter always reports
    /// ``.notDetermined``, which means the granted-path branch of
    /// ``refreshAuthorizationStatus`` (the durable APNs re-register
    /// trigger) cannot be exercised via the public API in tests. This
    /// helper bypasses the settings read so tests can pin the status
    /// to ``.authorized`` / ``.provisional`` / ``.ephemeral`` and
    /// verify that the injected ``registerForRemote`` closure fires
    /// when ``isLoggedIn`` is also true.
    ///
    /// `#if DEBUG`-gated so the seam is stripped from release builds
    /// — this is stricter than the
    /// ``WebSocketManager._setConnectionStateForTests`` pattern
    /// (which lives in the test target as an extension) because
    /// ``authorizationStatus`` is ``@Published private(set)`` on the
    /// production class and a test-target extension cannot bypass
    /// the private setter, so the seam has to live on the class
    /// itself; the DEBUG gate prevents it from shipping.
    func refreshWithStatusForTests(_ status: UNAuthorizationStatus) {
        self.authorizationStatus = status
        if Self.shouldFireDurableRegistration(
            authorizationStatus: status,
            isLoggedIn: isLoggedIn()
        ) {
            registerForRemote()
        }
    }
    #endif
}
