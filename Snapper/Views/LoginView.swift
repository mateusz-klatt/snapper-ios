import SwiftUI

struct LoginView: View {
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

                    VStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Text("Snapper")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Text("Trading Platform")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.bottom, 32)

                    VStack(spacing: 16) {
                        TextField("Username", text: $viewModel.username)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)

                        if let errorMessage = viewModel.errorMessage {
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
                                    Text("Sign In")
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
                    }
                    .padding(.horizontal, 32)

                    DisclosureGroup(isExpanded: $advancedExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current backend: \(displayedBackendURL)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            BackendURLEditor(
                                draft: $backendDraft,
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
                        Text("Advanced (custom backend)")
                            .font(.footnote)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
                .padding(.top, 80)
            }
            .navigationBarHidden(true)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
