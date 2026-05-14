import SwiftUI

/// 5-tab root: Home, Positions, Orders, Alerts, Settings.
///
/// Permission gating per tab:
/// - Home: ``canAccess("overview")``.
/// - Positions: ``readPositions`` / ``managePositions`` (every role
///   above ``aiDelegate`` already grants ``readPositions``).
/// - Orders: ``canAccess("orders")``.
/// - Alerts: ``readNotifications`` (push gating).
/// - Settings: ``canAccess("overview")`` — every authenticated role
///   per the permission catalog (contract that
///   any user can self-manage push notifications + device).
///
/// Deep-link routing pulls a pending path off
/// ``NavigationCoordinator.pendingDeepLink`` and selects the matching
/// tab. The mapping was generalised so the
/// dedicated Positions tab gets ``/positions*``, Home picks up
/// ``/system*``, and the existing ``/alerts*`` / ``/orders*`` rules
/// stay byte-identical to keep the APNs tap → AlertsView
/// scroll-to-anchor flow working.
struct MainTabView: View {
    @EnvironmentObject var webSocketManager: WebSocketManager
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(AppState.self) private var appState

    @State private var selectedTab: String = "home"

    var body: some View {
        TabView(selection: $selectedTab) {
            if authService.canAccess("overview") {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag("home")
            }

            if authService.hasPermission(.readPositions) {
                PositionsView()
                    .tabItem {
                        Label("Positions", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag("positions")
            }

            if authService.canAccess("orders") {
                OrdersView()
                    .tabItem {
                        Label("Orders", systemImage: "arrow.left.arrow.right")
                    }
                    .tag("orders")
            }

            if authService.hasPermission(.readNotifications) {
                AlertsView()
                    .tabItem {
                        Label("Alerts", systemImage: "bell.fill")
                    }
                    .tag("alerts")
            }

            if authService.canAccess("overview") {
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag("settings")
            }
        }
        .onAppear {
            /// Consume any pending deep-link that landed BEFORE the
            /// tab view existed (e.g. a notification tap while the
            /// user was on the login screen — `pendingDeepLink` is
            /// set by `NavigationCoordinator.handleNotificationTap`
            /// before `MainTabView` mounts after a successful auth
            /// flip in `SnapperApp`). `.onChange` alone misses this
            /// case: SwiftUI does not fire onChange for values that
            /// are already set at first render.
            consumePendingDeepLink()
        }
        .onChange(of: navigationCoordinator.pendingDeepLink) { _, _ in
            consumePendingDeepLink()
        }
        /// WS lifecycle is owned by `SnapperApp` (scenePhase + isAuthenticated
        /// observers). Putting connect/disconnect here would kill the
        /// socket whenever a modal sheet covered the tab view.
    }

    /// Read the coordinator's current `pendingDeepLink` and route
    /// to the matching tab if one applies. Shared between the
    /// `.onAppear` initial-render path (logged-out tap, login,
    /// MainTabView mount) and the `.onChange` runtime-update path
    /// (logged-in tap while MainTabView is already mounted).
    private func consumePendingDeepLink() {
        if let nextTab = Self.routeDeepLink(
            path: navigationCoordinator.pendingDeepLink,
            alertsPrefix: AppConfig.Endpoints.alerts,
            ordersPrefix: AppConfig.Endpoints.orders,
            positionsPrefix: AppConfig.Endpoints.positions,
            systemPrefix: AppConfig.Endpoints.system
        ) {
            selectedTab = nextTab
        }
    }

    /// Deep-link routing path-prefix mapping:
    /// - ``/alerts*`` → ``alerts`` (UNCHANGED, preserves
    ///   AlertsView scroll-to-anchor contract).
    /// - ``/orders*`` → ``orders`` (renamed from "trading").
    /// - ``/positions*`` → ``positions`` (now its own tab — previously
    ///   this fell back to Dashboard).
    /// - ``/system*`` → ``home`` (renamed from "dashboard").
    /// - anything else → ``nil``, leaving the current tab unchanged.
    ///
    /// Extracted as a pure function so the routing table is unit
    /// tested without rendering the SwiftUI body — ViewInspector is
    /// not available in this project.
    static func routeDeepLink(
        path: String?,
        alertsPrefix: String,
        ordersPrefix: String,
        positionsPrefix: String,
        systemPrefix: String
    ) -> String? {
        guard let path else { return nil }
        if path.hasPrefix(alertsPrefix) {
            return "alerts"
        }
        if path.hasPrefix(ordersPrefix) {
            return "orders"
        }
        if path.hasPrefix(positionsPrefix) {
            return "positions"
        }
        if path.hasPrefix(systemPrefix) {
            return "home"
        }
        return nil
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(WebSocketManager.shared)
            .environmentObject(AuthService.shared)
            .environmentObject(NavigationCoordinator.shared)
            .environment(AppState.shared)
    }
}
