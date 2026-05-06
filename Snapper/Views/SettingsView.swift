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
        NavigationView {
            Form {

                Section("Account") {
                    if let user = authService.currentUser {
                        HStack {
                            Text("Username")
                            Spacer()
                            Text(user.username)
                                .foregroundColor(.secondary)
                        }

                        if let email = user.email {
                            HStack {
                                Text("Email")
                                Spacer()
                                Text(email)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Role")
                            Spacer()
                            Text(user.role.rawValue.capitalized)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Connection") {
                    HStack {
                        Text("WebSocket Status")
                        Spacer()
                        connectionStatusView
                    }

                    HStack {
                        Text("Backend URL")
                        Spacer()
                        Text(displayedBackendURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Change backend…") {
                        showingBackendChangeAlert = true
                    }
                    .disabled(isSwitchingBackend)
                }

                Section("Notifications") {
                    HStack {
                        Text("Permission")
                        Spacer()
                        notificationStatusView
                    }

                    if notificationService.authorizationStatus == .notDetermined {
                        Button("Enable push notifications") {
                            Task {
                                await notificationService.requestAuthorization()
                            }
                        }
                    } else if notificationService.authorizationStatus == .denied {
                        Button("Open Settings") {
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

                    NavigationLink("Manage preferences") {
                        NotificationPrefsView()
                    }
                }

                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.buildVersion)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive, action: { showingLogoutAlert = true }) {
                        HStack {
                            Spacer()
                            Text("Logout")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Color.bgBase)
            .task {
                await notificationService.refreshAuthorizationStatus()
                await refreshDeviceState()
            }
        }
        .alert("Logout", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { /* Dismiss alert with no action */ }
            Button("Logout", role: .destructive) {
                logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Change backend?", isPresented: $showingBackendChangeAlert) {
            Button("Cancel", role: .cancel, action: dismissBackendChangeAlert)
            Button("Continue") {
                backendDraft = ""
                showingBackendEditor = true
            }
        } message: {
            Text("Switching backend signs you out and clears local app state. You'll need to sign in again at the new URL.")
        }
        .sheet(isPresented: $showingBackendEditor) {
            backendEditorSheet
        }
    }

    @ViewBuilder
    private var backendEditorSheet: some View {
        NavigationView {
            Form {
                Section("Custom backend URL") {
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
            .navigationTitle("Change backend")
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

    /// No-op handler for the alert's ``Cancel`` button.
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
        switch notificationService.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .provisional:
            return "Quiet"
        case .ephemeral:
            return "Ephemeral"
        case .notDetermined:
            return "Not set"
        case .denied:
            return "Disabled"
        @unknown default:
            return "Unknown"
        }
    }

    private var connectionStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)

            Text(connectionText)
                .font(.caption)
        }
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
        switch webSocketManager.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .authenticating:
            return "Authenticating"
        case .disconnected:
            return "Disconnected"
        case .error:
            return "Error"
        case .authFailed:
            return "Auth failed"
        }
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
            Text("Device")
            Spacer()
            switch registrationStatus {
            case .succeeded:
                if let pid = registeredDevicePublicId {
                    Text(String(pid.prefix(12)) + "…")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                } else {
                    Text("Registered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .inFlight:
                Text("Registering…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .failed(let attempt, _):
                Text("Failed (attempt \(attempt))")
                    .font(.caption)
                    .foregroundColor(.brandRed)
            case .awaitingLogin, .awaitingToken, .idle:
                Text("Not registered")
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
