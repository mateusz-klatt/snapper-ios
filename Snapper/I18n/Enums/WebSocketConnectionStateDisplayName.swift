import Foundation

extension WebSocketManager.ConnectionState {

    /// Localized display value for the connection state, looked up
    /// under the ``home.connectionState.*`` catalog namespace. The
    /// ``.error`` and ``.authFailed`` cases interpolate the server-
    /// provided detail VERBATIM via ``%@`` (per Phase H L1 — server
    /// text stays in the source language).
    func displayName(in language: CatalogLanguage) -> String {
        switch self {
        case .disconnected:
            return LocaleStrings.localized("home.connectionState.disconnected", in: language)
        case .connecting:
            return LocaleStrings.localized("home.connectionState.connecting", in: language)
        case .authenticating:
            return LocaleStrings.localized("home.connectionState.authenticating", in: language)
        case .connected:
            return LocaleStrings.localized("home.connectionState.connected", in: language)
        case .error(let detail):
            let template = LocaleStrings.localized("home.connectionState.error", in: language)
            return String(format: template, detail)
        case .authFailed(let detail):
            let template = LocaleStrings.localized("home.connectionState.authFailed", in: language)
            return String(format: template, detail)
        }
    }
}
