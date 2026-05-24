import SwiftUI

@main
struct SnapperApp: App {

    /// Reset persisted session state when the screenshot harness
    /// passes ``-snapper.resetSessionState YES`` at launch. Must run
    /// BEFORE ``@StateObject`` initializers (which would lazy-create
    /// ``AuthService.shared`` and pick up the persisted cookies),
    /// so we do it in ``SnapperApp.init()`` rather than the
    /// ``AppDelegate`` (whose delegate methods can fire AFTER the
    /// SwiftUI property wrappers under SwiftUI's lifecycle). DEBUG-
    /// only so production launches cannot be tricked into clearing
    /// the session.
    init() {
        #if DEBUG
        Self.resetSessionStateIfRequested()
        #endif
    }

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authService = AuthService.shared
    @StateObject private var webSocketManager = WebSocketManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase

    /// Inline implementation mirrors the one in ``AppDelegate`` but
    /// runs at App construction so the SwiftUI property wrappers see
    /// a clean state. The AppDelegate variant is kept as a defense
    /// in depth in case the SwiftUI lifecycle changes in a future
    /// iOS release.
    #if DEBUG
    private static func resetSessionStateIfRequested() {
        let defaults = UserDefaults.standard
        let requested = defaults.bool(forKey: "snapper.resetSessionState")
            || defaults.string(forKey: "snapper.resetSessionState") == "YES"
        guard requested else { return }
        for cookie in HTTPCookieStorage.shared.cookies ?? [] {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
        if let urlSessionCookies = URLSession.shared.configuration.httpCookieStorage?.cookies {
            for cookie in urlSessionCookies {
                URLSession.shared.configuration.httpCookieStorage?.deleteCookie(cookie)
            }
        }
        if let bundleId = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleId)
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(webSocketManager)
                .environmentObject(notificationService)
                .environmentObject(navigationCoordinator)
                .environment(AppState.shared)
                .tint(.brandGreen)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhase(newPhase)
                }
                .onChange(of: authService.isAuthenticated) { _, isAuth in
                    handleAuthChange(isAuth)
                }
        }
    }

    /// Connect on foreground / disconnect on background. Matches the
    /// iOS lifecycle: the socket must not hold the radio while the
    /// app is suspended.
    ///
    /// On `.active` we also re-poll notification authorization so an
    /// already-authorized + logged-in user gets a fresh APNs token
    /// delivered through `AppDelegate` (the system only fires
    /// `didRegisterForRemoteNotifications…` in response to a fresh
    /// `registerForRemoteNotifications()` call — without this hook a
    /// cold-relaunch leaves `DeviceRegistrationService` stuck in
    /// `.awaitingToken` forever).
    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if authService.isAuthenticated {
                webSocketManager.connect()
                Task { await notificationService.refreshAuthorizationStatus() }
            }
        case .background:
            webSocketManager.disconnect()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    /// Login flips `isAuthenticated` to true while the app is already
    /// `.active` — scenePhase doesn't fire, so we need a second
    /// observer to kick the WS connect AND the durable APNs
    /// re-registration. Without the registration call here, a user
    /// who logs out and logs back in without ever backgrounding the
    /// app stays stuck in `.awaitingToken` until the next
    /// background→active cycle. Logout is the mirror case;
    /// `disconnect()` is idempotent so the compound "logout +
    /// background" path is safe.
    private func handleAuthChange(_ isAuth: Bool) {
        if isAuth {
            webSocketManager.connect()
            Task { await notificationService.refreshAuthorizationStatus() }
        } else {
            webSocketManager.disconnect()
        }
    }
}

/// Root view that owns the SwiftUI environment locale + layout-
/// direction wiring. Pulled out of ``SnapperApp/body`` because
/// reading ``AppState.shared.locale`` inline inside the
/// ``WindowGroup`` content closure did not reliably re-evaluate
/// when ``locale`` mutated: SwiftUI's ``@Observable`` tracking
/// registers reads from ``View.body``, not from ``App.body``'s
/// scene closure, so locale-driven environment values were
/// pinned at app launch. The pin manifested as ``Text(LocalizedStringKey)``
/// resolving against the launch language regardless of the user's
/// picker selection, and as ``\.layoutDirection`` staying RTL/LTR
/// from the initial locale even after switching to a code with
/// the opposite directionality.
///
/// Reading ``appState.locale`` through ``@Environment(AppState.self)``
/// here puts the read inside a tracked ``View.body``; SwiftUI then
/// re-evaluates ``RootView/body`` on every locale change and
/// re-emits the environment modifiers with fresh values, which
/// propagate to every descendant.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environment(\.locale, LocaleEnvironmentResolver.environmentLocale(for: appState.locale))
        .environment(\.layoutDirection, LocaleEnvironmentResolver.layoutDirection(for: appState.locale))
    }
}
