import Foundation

/// Typed error surface for the login flow.
///
/// Replaces the prior ``AuthService.errorMessage: String?`` stringly-
/// typed surface so the view boundary can localize error messages
/// against the user's current ``AppLocale`` without losing the
/// distinction between server-provided detail (rendered VERBATIM per L1)
/// and client-generated error cases (routed through the catalog).
///
/// Each case maps to a specific catalog key under ``errors.login.*``.
/// The ``.serverDetail`` case is the verbatim escape hatch: the
/// server's ``detail`` field flows through unchanged so server-side
/// error messages are not double-localized.
enum LoginViewError: Equatable {

    /// Login URL could not be constructed from the backend prefix.
    case invalidURL

    /// JSONEncoder failed to serialize the outbound login envelope.
    case serializationFailed

    /// HTTP response shape was not ``HTTPURLResponse``.
    case invalidResponse

    /// Login failed with no parsed server detail (fallback case).
    case loginFailed

    /// Server returned a non-200 with a parsed ``detail`` field. The
    /// detail is rendered VERBATIM (per ``L1`` of the Phase H plan —
    /// server text stays in the source language).
    case serverDetail(String)

    /// Network-level transport failure with the underlying error's
    /// ``localizedDescription``.
    case network(String)

    /// Map to a localized user-visible message in the requested
    /// language.
    func localizedMessage(in language: CatalogLanguage) -> String {
        switch self {
        case .invalidURL:
            return LocaleStrings.localized("errors.login.invalidURL", in: language)
        case .serializationFailed:
            return LocaleStrings.localized("errors.login.serializationFailed", in: language)
        case .invalidResponse:
            return LocaleStrings.localized("errors.login.invalidResponse", in: language)
        case .loginFailed:
            return LocaleStrings.localized("errors.login.loginFailed", in: language)
        case .serverDetail(let detail):
            return detail
        case .network(let underlying):
            let template = LocaleStrings.localized("errors.login.network", in: language)
            return String(format: template, underlying)
        }
    }
}
