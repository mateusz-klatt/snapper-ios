import Foundation
import Observation

/// LoginView's MVVM seam — wraps `AuthService` so the form's
/// `username / password / isLoading` state is testable in isolation.
///
/// Migrated to `@Observable` in v0.3.1 — see `docs/architecture-mvvm.md`
/// for the View / VM split and the testing rules.
/// `AuthService` itself stays `ObservableObject` for now — the
/// `SnapperApp` root and several other services bind to it via
/// `@StateObject`, and migrating it sits outside this PR's scope.
///
/// `errorMessage(in:)` and `isAuthenticated` are computed passthroughs
/// to the underlying `AuthService` so tests keep their existing
/// assertion shape without needing Combine bridging. The View observes
/// the VM through `@State` (iOS 17+ `@Observable` integration) and
/// implicitly observes `AuthService` through the parent `@StateObject`
/// in `SnapperApp`, so passthrough reads stay reactive.
///
/// Login errors flow through `AuthService.error: LoginViewError?`
/// which the VM localizes against the user's current `CatalogLanguage`
/// when the view asks for a string. `.serverDetail` errors render the
/// server-provided detail VERBATIM (per Phase H L1).
@MainActor
@Observable
final class LoginViewModel {

    var username = ""
    var password = ""
    var isLoading = false

    private let authService: AuthService

    init(authService: AuthService = .shared) {
        self.authService = authService
    }

    var isLoginEnabled: Bool {
        return !username.isEmpty && !password.isEmpty && !isLoading
    }

    func errorMessage(in language: CatalogLanguage) -> String? {
        return authService.error?.localizedMessage(in: language)
    }

    var error: LoginViewError? {
        return authService.error
    }

    var isAuthenticated: Bool {
        return authService.isAuthenticated
    }

    func login() async {
        isLoading = true
        /// Clear the prior error before firing a retry. `error` is a
        /// computed passthrough to AuthService, so without this reset
        /// the previous attempt's error stays visible until the new
        /// request finishes — that's a UX regression from the
        /// pre-`@Observable` flow where the VM held its own
        /// `@Published` slot and zeroed it here on every entry.
        authService.error = nil

        await authService.login(username: username, password: password)

        /// Clear the plaintext password from memory once the login
        /// request resolves — `@Observable` properties stay live for
        /// the view's lifetime otherwise, leaving the password
        /// observable to anything holding the view model. The
        /// privacy policy promises this clear; AuthService has the
        /// session-establishing tokens / cookies it needs, so the
        /// password is no longer required.
        password = ""
        isLoading = false
    }
}
