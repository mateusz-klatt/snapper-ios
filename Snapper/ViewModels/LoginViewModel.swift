import Foundation
import Combine

@MainActor
class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false

    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthService = .shared) {
        self.authService = authService

        authService.$isAuthenticated
            .assign(to: &$isAuthenticated)

        authService.$errorMessage
            .assign(to: &$errorMessage)
    }

    var isLoginEnabled: Bool {
        !username.isEmpty && !password.isEmpty && !isLoading
    }

    func login() async {
        isLoading = true
        errorMessage = nil

        await authService.login(username: username, password: password)

        // Clear the plaintext password from memory once the login
        // request resolves — `@Published` properties stay live for
        // the view's lifetime otherwise, leaving the password
        // observable to anything holding the view model. The
        // privacy policy promises this clear; AuthService has the
        // session-establishing tokens / cookies it needs, so the
        // password is no longer required.
        password = ""
        isLoading = false
    }
}
