import Foundation
import UIKit
import UserNotifications
import os

/// iOS application delegate wired for APNs push + foreground WS-suppression.
///
/// Single source of truth for UNUserNotificationCenter delegate
/// callbacks:
///
/// - `didRegisterForRemoteNotificationsWithDeviceToken` → hands the
///   APNs token to `DeviceRegistrationService` (actor-isolated).
/// - `didFailToRegisterForRemoteNotifications` → logs; no retry (APNs
///   is expected to re-deliver on its own or next launch).
/// - `userNotificationCenter(_:willPresent:)` → suppresses banner /
///   sound / badge when the WebSocket is connected (the app already
///   renders live alerts inline — foreground-suppression).
/// - `userNotificationCenter(_:didReceive:)` → routes the tap into
///   `NavigationCoordinator` so `MainTabView` can deep-link to the
///   target row.
///
/// All callbacks hop to `@MainActor` before touching observable state
/// — the delegate methods themselves are not `@MainActor` in
/// `UIApplicationDelegate`, so we use `Task { @MainActor in ... }`
/// to mark the boundary explicitly.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    private let logger = AppLogger.make(category: "APNs")

    nonisolated func application(
        _ _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Task { @MainActor in
            UNUserNotificationCenter.current().delegate = self
        }
        #if DEBUG
        Self.resetSessionStateIfRequested()
        #endif
        return true
    }

    #if DEBUG
    /// DEBUG-only hook for the screenshot harness: clears the persisted
    /// auth session (``HTTPCookieStorage.shared`` cookies +
    /// ``selected_wallet_public_id`` /
    /// ``snapper.devAutoLoginUser`` / ``snapper.devAutoLoginPass``
    /// UserDefaults keys) so the test runner can capture the
    /// pre-login screen even when a previous launch left a valid
    /// session in the simulator. Triggered by passing
    /// ``-snapper.resetSessionState YES`` in ``launchArguments``;
    /// no-op when the argument is missing or set to anything else.
    ///
    /// Lives in the AppDelegate's launch path as defense in depth —
    /// the primary reset happens in ``SnapperApp.init()`` which
    /// SwiftUI calls before the ``WindowGroup`` content closure
    /// evaluates and triggers the first authenticated API call.
    /// ``URLSession.shared`` only attaches persisted cookies on
    /// outgoing requests, not at ``AuthService`` init time, so as
    /// long as the reset runs before the first API call the test
    /// runner sees ``LoginView``. The AppDelegate path is kept
    /// in case the SwiftUI lifecycle changes in a future iOS
    /// release. Side-effects are scoped to the listed auth +
    /// wallet + dev-auto-login keys; the locale picker /
    /// financial-color preference / backend URL override survive
    /// (the harness sets the backend URL via a separate
    /// ``-snapper.customBackendURL`` argument).
    ///
    /// Wrapped in ``#if DEBUG`` so the helper symbol does not exist
    /// in RELEASE binaries — the production binary cannot be
    /// tricked into a session reset by a hostile launch argument.
    nonisolated private static func resetSessionStateIfRequested() {
        let defaults = UserDefaults.standard
        let requested = defaults.bool(forKey: "snapper.resetSessionState")
            || defaults.string(forKey: "snapper.resetSessionState") == "YES"
        guard requested else { return }
        for cookie in HTTPCookieStorage.shared.cookies ?? [] {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
        defaults.removeObject(forKey: "selected_wallet_public_id")
        defaults.removeObject(forKey: "snapper.devAutoLoginUser")
        defaults.removeObject(forKey: "snapper.devAutoLoginPass")
    }
    #endif

    nonisolated func application(
        _ _: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await DeviceRegistrationService.shared().onTokenReceived(deviceToken)
        }
    }

    nonisolated func application(
        _ _: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            self.logger.error("APNs registration failed: \(error.localizedDescription)")
        }
    }
    func userNotificationCenter(
        _ _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        if case .connected = WebSocketManager.shared.connectionState {
            completionHandler([])
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }

    func userNotificationCenter(
        _ _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        Task { @MainActor in
            await NavigationCoordinator.shared.handleNotificationTap(response)
            completionHandler()
        }
    }
}
