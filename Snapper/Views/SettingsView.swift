import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var webSocketManager: WebSocketManager
    @EnvironmentObject var notificationService: NotificationService
    @Environment(AppState.self) private var appState

    @State private var showingLogoutAlert = false
    @State private var registeredDevicePublicId: String?
    @State private var registrationStatus: DeviceRegistrationStatus = .idle
    @State private var isRetrying = false
    @State private var displayedBackendURL = AppConfig.baseURL
    @State private var showingBackendChangeAlert = false
    @State private var showingBackendEditor = false
    @State private var backendDraft = ""
    @State private var isSwitchingBackend = false

    var body: some View {
        NavigationStack {
            Form {

                Section {
                    LocaleSwitcher()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } header: {
                    Text(LocalizedStringKey("settings.section.language"))
                }

                Section {
                    Picker(
                        LocalizedStringKey("settings.financialColor.title"),
                        selection: financialColorPreferenceSelection
                    ) {
                        Text(LocalizedStringKey("settings.financialColor.auto"))
                            .tag(FinancialColorPreference.auto)
                        Text(LocalizedStringKey("settings.financialColor.risingGreen"))
                            .tag(FinancialColorPreference.risingGreen)
                        Text(LocalizedStringKey("settings.financialColor.risingRed"))
                            .tag(FinancialColorPreference.risingRed)
                    }
                    .pickerStyle(.inline)
                    if appState.financialColorPreference == .auto {
                        let effective = resolveFinancialColorConvention(
                            preference: appState.financialColorPreference,
                            locale: appState.locale
                        )
                        let conventionLabelKey =
                            effective == .risingRed
                            ? "settings.financialColor.subtitleRisingRed"
                            : "settings.financialColor.subtitleRisingGreen"
                        Text(
                            String(
                                format: LocaleStrings.localized(
                                    "settings.financialColor.subtitleAutoCurrent",
                                    in: appState.locale.catalogLanguage
                                ),
                                LocaleStrings.localized(
                                    conventionLabelKey,
                                    in: appState.locale.catalogLanguage
                                )
                            )
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                } header: {
                    Text(LocalizedStringKey("settings.section.financialColor"))
                }

                Section(LocalizedStringKey("settings.section.account")) {
                    if let user = authService.currentUser {
                        HStack {
                            Text(LocalizedStringKey("settings.account.username"))
                            Spacer()
                            Text(user.username)
                                .foregroundColor(.secondary)
                        }

                        if let email = user.email {
                            HStack {
                                Text(LocalizedStringKey("settings.account.email"))
                                Spacer()
                                Text(email)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text(
                                String(
                                    format: LocaleStrings.localized("settings.account.role", in: appState.locale.catalogLanguage),
                                    user.role.displayName(in: appState.locale.catalogLanguage)
                                )
                            )
                        }
                    }

                    NavigationLink {
                        DeskView()
                    } label: {
                        Label(LocalizedStringKey("desk.navTitle"), systemImage: "person.2")
                    }
                    .accessibilityIdentifier("settings.desk")
                }

                Section(LocalizedStringKey("settings.section.connection")) {
                    HStack {
                        Text(LocalizedStringKey("settings.connection.status"))
                        Spacer()
                        connectionStatusView
                    }

                    HStack {
                        Text(LocalizedStringKey("settings.connection.backend"))
                        Spacer()
                        Text(displayedBackendURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .environment(\.layoutDirection, .leftToRight)
                    }

                    Button(LocalizedStringKey("settings.connection.changeBackend")) {
                        showingBackendChangeAlert = true
                    }
                    .disabled(isSwitchingBackend)
                }

                Section(LocalizedStringKey("settings.section.notifications")) {
                    HStack {
                        Text(LocalizedStringKey("settings.notifications.permission"))
                        Spacer()
                        notificationStatusView
                    }

                    if notificationService.authorizationStatus == .notDetermined {
                        Button(LocalizedStringKey("settings.notifications.enableButton")) {
                            Task {
                                await notificationService.requestAuthorization()
                            }
                        }
                    } else if notificationService.authorizationStatus == .denied {
                        Button(LocalizedStringKey("settings.notifications.openSystemSettings")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    deviceStatusRow

                    if case .failed = registrationStatus {
                        Button(action: triggerRetry) {
                            HStack {
                                if isRetrying {
                                    ProgressView()
                                }
                                Text(isRetrying ? "Retrying…" : "Retry registration")
                            }
                        }
                        .disabled(isRetrying)
                    }

                    NavigationLink(LocalizedStringKey("settings.notifications.managePreferences")) {
                        NotificationPrefsView()
                    }
                }

                Section(LocalizedStringKey("settings.section.appInfo")) {
                    HStack {
                        Text(LocalizedStringKey("settings.appInfo.version"))
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(LocalizedStringKey("settings.appInfo.build"))
                        Spacer()
                        Text(Bundle.main.buildVersion)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive, action: { showingLogoutAlert = true }) {
                        HStack {
                            Spacer()
                            Text(LocalizedStringKey("settings.logout.button"))
                            Spacer()
                        }
                    }
                    .accessibilityLabel(LocalizedStringKey("settings.accessibility.label.logoutButton"))
                    .accessibilityHint(LocalizedStringKey("settings.accessibility.hint.logoutButton"))
                }
            }
            .navigationTitle(LocalizedStringKey("tabs.settings"))
            .scrollContentBackground(.hidden)
            .background(Color.bgBase)
            .task {
                await notificationService.refreshAuthorizationStatus()
                await refreshDeviceState()
            }
        }
        .alert(LocalizedStringKey("settings.logout.confirmTitle"), isPresented: $showingLogoutAlert) {
            Button(LocalizedStringKey("backend.url.cancel"), role: .cancel, action: dismissLogoutAlert)
            Button(LocalizedStringKey("settings.logout.button"), role: .destructive) {
                logout()
            }
        } message: {
            Text(LocalizedStringKey("settings.logout.confirmMessage"))
        }
        .alert(LocalizedStringKey("settings.connection.changeBackendTitle"), isPresented: $showingBackendChangeAlert) {
            Button(LocalizedStringKey("backend.url.cancel"), role: .cancel, action: dismissBackendChangeAlert)
            Button(LocalizedStringKey("common.continue")) {
                backendDraft = ""
                showingBackendEditor = true
            }
        } message: {
            Text(LocalizedStringKey("settings.connection.changeBackendMessage"))
        }
        .sheet(isPresented: $showingBackendEditor) {
            backendEditorSheet
        }
    }

    private var financialColorPreferenceSelection: Binding<FinancialColorPreference> {
        Binding(
            get: { appState.financialColorPreference },
            set: { appState.financialColorPreference = $0 }
        )
    }

    @ViewBuilder
    private var backendEditorSheet: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("settings.connection.customBackendURL")) {
                    BackendURLEditor(
                        draft: $backendDraft,
                        allowReset: BackendURLStore.shared.hasOverride(),
                        onSave: { url in
                            showingBackendEditor = false
                            performBackendSwitch(to: url)
                        },
                        onReset: {
                            showingBackendEditor = false
                            performBackendSwitch(to: nil)
                        },
                        onCancel: {
                            showingBackendEditor = false
                        }
                    )
                }
            }
            .navigationTitle(LocalizedStringKey("settings.connection.changeBackendNavTitle"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Run the sequenced sign-out triggered by Settings → Change
    /// backend → Save (or Reset).
    ///
    /// Order matters and is invariant:
    /// 1. ``WebSocketManager.disconnect()`` first so the old socket
    ///    does not block on the server-side logout response.
    /// 2. ``AuthService.logout()`` is non-throwing and flips
    ///    ``isAuthenticated = false`` at the end — that flip causes
    ///    ``SnapperApp``'s root conditional to swap ``MainTabView``
    ///    for ``LoginView`` once the actor yields back to MainActor.
    /// 3. Cookie cleanup is host-scoped (``oldURL.host``) so
    ///    path-scoped session cookies under ``/api/auth/refresh`` are
    ///    also dropped, regardless of cookie ``Path`` attribute.
    /// 4. ``saveOverride()`` runs LAST so any in-flight 401 refresh-
    ///    retry that races into this window still resolves against
    ///    the OLD URL via the dynamic ``apiBaseURLProvider`` closure;
    ///    only after this return value is committed does the new
    ///    backend become the effective URL.
    private func performBackendSwitch(to candidate: URL?) {
        guard !isSwitchingBackend else { return }
        isSwitchingBackend = true
        let oldURL = BackendURLStore.shared.currentEffectiveURL()

        Task { @MainActor in
            defer { isSwitchingBackend = false }
            webSocketManager.disconnect()
            await authService.logout()
            let oldHost = oldURL.host?.lowercased()
            let allCookies = HTTPCookieStorage.shared.cookies ?? []
            for cookie in allCookies {
                let domain = cookie.domain.lowercased()
                let trimmed = domain.hasPrefix(".") ? String(domain.dropFirst()) : domain
                if let host = oldHost, host == trimmed {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                }
            }

            URLCache.shared.removeAllCachedResponses()
            appState.selectedWalletPublicId = nil
            appState.availableWallets = []
            appState.availableOperators = []

            if let url = candidate {
                BackendURLStore.shared.saveOverride(url)
            } else {
                BackendURLStore.shared.clearOverride()
            }

            displayedBackendURL = AppConfig.baseURL
        }
    }

    /// No-op handler for the logout alert's ``Cancel`` button.
    ///
    /// SwiftUI dismisses the alert automatically for cancel-role
    /// buttons; naming the no-op keeps the call site free of inline
    /// empty closures and block comments.
    private func dismissLogoutAlert() {}

    /// No-op handler for the backend-change alert's ``Cancel`` button.
    ///
    /// SwiftUI ``alert(_:isPresented:actions:)`` requires a closure
    /// for every button; the Cancel role automatically dismisses the
    /// alert without further state change. Naming the no-op keeps the
    /// call site free of empty closures so the no-comments rule and
    /// Sonar's empty-closure rule (``swift:S1186``) are both satisfied.
    private func dismissBackendChangeAlert() {}

    private var notificationStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(notificationStatusColor)
                .frame(width: 8, height: 8)
            Text(notificationStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var notificationStatusColor: Color {
        switch notificationService.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .brandGreen
        case .notDetermined:
            return .orange
        case .denied:
            return .brandRed
        @unknown default:
            return .gray
        }
    }

    private var notificationStatusText: String {
        let key: String
        switch notificationService.authorizationStatus {
        case .authorized:
            key = "settings.notifications.permission.enabled"
        case .provisional:
            key = "settings.notifications.permission.quiet"
        case .ephemeral:
            key = "settings.notifications.permission.ephemeral"
        case .notDetermined:
            key = "settings.notifications.permission.notSet"
        case .denied:
            key = "settings.notifications.permission.disabled"
        @unknown default:
            key = "settings.notifications.permission.unknown"
        }
        return LocaleStrings.localized(key, in: appState.locale.catalogLanguage)
    }

    /// Status indicator + label rendered via SwiftUI ``Label`` so the
    /// icon flips with ``\.layoutDirection`` instead of always sitting
    /// on the visual-left edge. Under RTL (``ae``/``il``/``ir``) the
    /// plain ``HStack { Circle; Text }`` shape kept the dot on the
    /// pixel-left of the value, which means in reading order the dot
    /// came AFTER the value — opposite of the icon-precedes-value
    /// convention used by iOS native Settings / Wi-Fi / Bloomberg /
    /// Bybit in their RTL renderings. ``Label`` swaps icon and title
    /// positions automatically based on layoutDirection.
    private var connectionStatusView: some View {
        Label {
            Text(connectionText)
                .font(.caption)
        } icon: {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
        }
        .labelStyle(.titleAndIcon)
    }

    private var connectionColor: Color {
        switch webSocketManager.connectionState {
        case .connected:
            return .brandGreen
        case .connecting, .authenticating:
            return .orange
        case .disconnected, .error, .authFailed:
            return .brandRed
        }
    }

    private var connectionText: String {
        return webSocketManager.connectionState.displayName(in: appState.locale.catalogLanguage)
    }

    private func logout() {
        webSocketManager.disconnect()
        Task {
            await authService.logout()
        }
    }

    @ViewBuilder
    private var deviceStatusRow: some View {
        HStack {
            Text(LocalizedStringKey("settings.notifications.device"))
            Spacer()
            switch registrationStatus {
            case .succeeded:
                if let pid = registeredDevicePublicId {
                    Text(String(pid.prefix(12)) + "…")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                } else {
                    Text(LocalizedStringKey("settings.notifications.registered"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .inFlight:
                Text(LocalizedStringKey("settings.notifications.registering"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .failed(let attempt, _):
                Text("Failed (attempt \(attempt))")
                    .font(.caption)
                    .foregroundColor(.brandRed)
            case .awaitingLogin, .awaitingToken, .idle:
                Text(LocalizedStringKey("settings.notifications.notRegistered"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func triggerRetry() {
        guard !isRetrying else { return }
        isRetrying = true
        Task {
            defer { isRetrying = false }
            let service = DeviceRegistrationService.shared()
            await service.retryNow()
            await refreshDeviceState()
        }
    }

    @MainActor
    private func refreshDeviceState() async {
        let service = DeviceRegistrationService.shared()
        registeredDevicePublicId = await service.currentDevicePublicId()
        registrationStatus = await service.currentStatus()
    }
}

extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildVersion: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthService.shared)
            .environmentObject(WebSocketManager.shared)
            .environmentObject(NotificationService.shared)
            .environment(AppState.shared)
    }
}
