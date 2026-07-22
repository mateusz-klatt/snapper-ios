import SwiftUI

/// Permission-gated root tabs for the application surfaces.
///
/// Permission gating per tab:
/// - Home: ``canAccess("overview")``.
/// - Positions: ``readPositions`` / ``managePositions``.
/// - Orders: ``canAccess("orders")``.
/// - Alerts: ``readNotifications`` (push gating).
/// - Accounts: ``readAccountState`` and the ``accounts`` resource.
/// - Signals: ``canAccess("signals")`` — read-only trading-signals feed
///   (``read:market_data``). Inserted
///   before Settings so Alerts stays a directly-tapped tab: a session with
///   all seven visible tabs lets iOS collapse the trailing account,
///   signal, and settings surfaces into the standard "More" list,
///   leaving the APNs deep-link target (Alerts) reachable without
///   traversing "More".
/// - Settings: ``canAccess("overview")`` — every authenticated session
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

    /// ``@SceneStorage`` instead of plain ``@State`` so the active
    /// tab survives the ``RootView`` re-mount that follows a locale
    /// change. ``RootView`` carries ``.id(appState.locale)`` to
    /// invalidate cached ``NavigationStack`` layout directions on
    /// RTL ⇄ LTR flips; without ``@SceneStorage`` that re-mount
    /// would also discard ``selectedTab`` and bounce the user back
    /// to the Home tab right after they flipped languages from
    /// Settings. Scene storage persists the value in the scene's
    /// state restoration store across view-identity changes within
    /// the same scene.
    @SceneStorage("snapper.main-tab.selected") private var selectedTab: String = "home"

    /// Tab IDs currently visible given the user's permissions —
    /// computed from the same gates the ``TabView`` body uses so
    /// the two cannot drift apart. Order matters: ``"home"`` is
    /// always the first fallback when an unavailable tab needs
    /// normalising, and the list happens to be ordered exactly the
    /// way ``TabView`` lays them out.
    private var availableTabIDs: [String] {
        var ids: [String] = []
        if authService.canAccess("overview") { ids.append("home") }
        if authService.hasPermission(.readPositions) { ids.append("positions") }
        if authService.canAccess("orders") { ids.append("orders") }
        if authService.hasPermission(.readNotifications) { ids.append("alerts") }
        if Self.canShowAccounts(
            hasReadAccountState: authService.hasPermission(.readAccountState),
            canAccessAccountsResource: authService.canAccess("accounts")
        ) { ids.append("accounts") }
        if authService.canAccess("signals") { ids.append("signals") }
        if authService.canAccess("overview") { ids.append("settings") }
        return ids
    }

    /// Snap ``selectedTab`` back to an available tab when the
    /// stored value points at something the current permission scope cannot
    /// access. Guards the ``@SceneStorage`` restore path: a
    /// previous login (different permission scope) may have stored
    /// ``"alerts"``; logging in again without
    /// ``readNotifications`` would render an empty
    /// ``TabView(selection:)`` because the tag is missing.
    /// Falls back to ``"home"`` when present, otherwise the first
    /// available tab, otherwise the literal ``"home"`` as a final
    /// safety net (the TabView render will be empty anyway).
    private func normalizeSelectedTab() {
        let ids = availableTabIDs
        guard !ids.contains(selectedTab) else { return }
        if ids.contains("home") {
            selectedTab = "home"
        } else if let first = ids.first {
            selectedTab = first
        } else {
            selectedTab = "home"
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            if authService.canAccess("overview") {
                HomeView()
                    .tabItem {
                        Label(LocalizedStringKey("tabs.home"), systemImage: "house.fill")
                    }
                    .tag("home")
                    .accessibilityLabel(LocalizedStringKey("tabs.accessibility.label.home"))
            }

            if authService.hasPermission(.readPositions) {
                PositionsView()
                    .tabItem {
                        Label(LocalizedStringKey("tabs.positions"), systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag("positions")
            }

            if authService.canAccess("orders") {
                OrdersView()
                    .tabItem {
                        Label(LocalizedStringKey("tabs.orders"), systemImage: "arrow.left.arrow.right")
                    }
                    .tag("orders")
            }

            if authService.hasPermission(.readNotifications) {
                AlertsView()
                    .tabItem {
                        Label(LocalizedStringKey("tabs.alerts"), systemImage: "bell.fill")
                    }
                    .tag("alerts")
            }

            if Self.canShowAccounts(
                hasReadAccountState: authService.hasPermission(.readAccountState),
                canAccessAccountsResource: authService.canAccess("accounts")
            ) {
                AccountsView()
                    .tabItem {
                        Label(LocalizedStringKey("tabs.accounts"), systemImage: "building.columns.fill")
                    }
                    .tag("accounts")
            }

            if authService.canAccess("signals") {
                SignalsView()
                    .tabItem {
                        Label(LocalizedStringKey("tabs.signals"), systemImage: "waveform.path.ecg")
                    }
                    .tag("signals")
            }

            if authService.canAccess("overview") {
                SettingsView()
                    .tabItem {
                        Label(LocalizedStringKey("tabs.settings"), systemImage: "gearshape.fill")
                    }
                    .tag("settings")
            }
        }
        .onAppear {
            /// Normalise the ``@SceneStorage``-restored selection
            /// against the current session's permissions BEFORE any
            /// deep-link consumption — otherwise a stored
            /// ``"alerts"`` from a previous login with a different
            /// permission scope could leave the ``TabView`` pointing at a tag
            /// that the current body conditional does not render.
            normalizeSelectedTab()
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
        .onChange(of: authService.currentUser?.effectivePermissions) { _, _ in
            /// Re-normalise on permission-scope change so a tab that the new session
            /// cannot access is replaced before its body would have
            /// been rendered.
            normalizeSelectedTab()
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
        guard let nextTab = Self.routeDeepLink(
            path: navigationCoordinator.pendingDeepLink,
            alertsPrefix: AppConfig.Endpoints.alerts,
            ordersPrefix: AppConfig.Endpoints.orders,
            positionsPrefix: AppConfig.Endpoints.positions,
            accountsPrefix: AppConfig.Endpoints.accounts,
            systemPrefix: AppConfig.Endpoints.system
        ) else { return }
        guard availableTabIDs.contains(nextTab) else {
            /// Recognized route but the target tab is not visible
            /// for the current permission scope — clear so the stale link does
            /// not linger and re-fire on the next ``MainTabView``
            /// remount (locale flip via ``.id(appState.locale)`` or
            /// identity swap).
            navigationCoordinator.clearPendingDeepLink()
            return
        }
        selectedTab = nextTab
        /// Clear the pending deep link for tabs that consume the
        /// entire path here — without it, a notification tap to
        /// ``/orders/...`` / ``/positions/...`` / ``/system/...``
        /// stays in ``NavigationCoordinator.pendingDeepLink``
        /// indefinitely, and a future ``MainTabView`` re-mount
        /// (e.g. the ``.id(appState.locale)`` re-mount on a
        /// locale flip) re-fires ``.onAppear`` which re-consumes
        /// the stale value and yanks the user back to that tab.
        ///
        /// ``alerts`` is only exempted when there's an actual
        /// ``pendingAlertPublicId`` anchor for ``AlertsView`` to
        /// consume — a bare ``/alerts`` route is fully consumed
        /// by selecting the tab and can be cleared here.
        let alertsHasAnchor = nextTab == "alerts"
            && navigationCoordinator.pendingAlertPublicId != nil
        if !alertsHasAnchor {
            navigationCoordinator.clearPendingDeepLink()
        }
    }

    /// Deep-link routing path-prefix mapping:
    /// - ``/alerts*`` → ``alerts`` (UNCHANGED, preserves
    ///   AlertsView scroll-to-anchor contract).
    /// - ``/orders*`` → ``orders`` (renamed from "trading").
    /// - ``/positions*`` → ``positions`` (now its own tab — previously
    ///   this fell back to Dashboard).
    /// - ``/portfolio/accounts*`` → ``accounts``.
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
        accountsPrefix: String,
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
        if path.hasPrefix(accountsPrefix) {
            return "accounts"
        }
        if path.hasPrefix(systemPrefix) {
            return "home"
        }
        return nil
    }

    static func canShowAccounts(
        hasReadAccountState: Bool,
        canAccessAccountsResource: Bool
    ) -> Bool {
        return hasReadAccountState && canAccessAccountsResource
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
