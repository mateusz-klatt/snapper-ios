import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = LoginViewModel()
    @State private var advancedExpanded = false
    @State private var backendDraft = ""
    @State private var displayedBackendURL = AppConfig.baseURL

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgBase
                    .ignoresSafeArea()

                VStack(spacing: 24) {

                    HStack {
                        Spacer()
                        LocaleSwitcher()
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Text(verbatim: "Snapper")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Text(LocalizedStringKey("auth.login.subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.bottom, 32)

                    VStack(spacing: 16) {
                        TextField(LocalizedStringKey("auth.login.usernamePlaceholder"), text: $viewModel.username)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .accessibilityIdentifier("login.username")

                        SecureField(LocalizedStringKey("auth.login.passwordPlaceholder"), text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.asciiCapable)
                            .accessibilityIdentifier("login.password")

                        if let errorMessage = viewModel.errorMessage(in: appState.locale.catalogLanguage) {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(Color.lossRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: { Task { await viewModel.login() } }) {
                            Group {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(LocalizedStringKey("auth.login.signIn"))
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .background(Color.brandRed)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!viewModel.isLoginEnabled)
                        .accessibilityIdentifier("login.signIn")
                    }
                    .padding(.horizontal, 32)

                    DisclosureGroup(isExpanded: $advancedExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(currentBackendCaption)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            BackendURLEditor(
                                draft: $backendDraft,
                                allowReset: BackendURLStore.shared.hasOverride(),
                                onSave: { url in
                                    BackendURLStore.shared.saveOverride(url)
                                    displayedBackendURL = AppConfig.baseURL
                                    backendDraft = ""
                                    advancedExpanded = false
                                },
                                onReset: {
                                    BackendURLStore.shared.clearOverride()
                                    displayedBackendURL = AppConfig.baseURL
                                    backendDraft = ""
                                    advancedExpanded = false
                                },
                                onCancel: {
                                    backendDraft = ""
                                    advancedExpanded = false
                                }
                            )
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text(LocalizedStringKey("auth.login.advancedDisclosure"))
                            .font(.footnote)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationBarHidden(true)
            .task { await runDevAutoLoginIfRequested() }
        }
    }

    /// Render the "Current backend: <URL>" caption against the
    /// active catalog language. ``LocalizedStringKey`` is not used
    /// because the result is a single ``String`` interpolated into
    /// a ``Text``; using the helper keeps the lookup language
    /// consistent across runtime-picked locales.
    private var currentBackendCaption: String {
        let template = LocaleStrings.localized(
            "auth.login.currentBackend",
            in: appState.locale.catalogLanguage
        )
        return String(
            format: template,
            locale: appState.locale.nativeLocale,
            displayedBackendURL
        )
    }

    /// DEBUG-only hook to skip manual credential entry when the
    /// app is launched against a local-dev backend over a
    /// trycloudflare tunnel from automation. Reads UserDefaults
    /// keys ``snapper.devAutoLoginUser`` and
    /// ``snapper.devAutoLoginPass`` once at first appear; if
    /// both are non-empty, fills the VM and immediately invokes
    /// the same login path the Sign In button would. Defaults
    /// keys are NEVER read in non-DEBUG builds (e.g. TestFlight,
    /// App Store) so the production login surface is unaffected.
    @MainActor
    private func runDevAutoLoginIfRequested() async {
        #if DEBUG
        guard viewModel.username.isEmpty, viewModel.password.isEmpty else { return }
        let defaults = UserDefaults.standard
        guard let user = defaults.string(forKey: "snapper.devAutoLoginUser"),
              let pass = defaults.string(forKey: "snapper.devAutoLoginPass"),
              !user.isEmpty, !pass.isEmpty else { return }
        viewModel.username = user
        viewModel.password = pass
        await viewModel.login()
        #endif
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environment(AppState.shared)
    }
}
