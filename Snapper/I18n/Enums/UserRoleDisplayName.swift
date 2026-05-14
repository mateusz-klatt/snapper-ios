import Foundation

extension UserRole {

    /// Localized display value for the role, looked up under the
    /// ``user.role.*`` catalog namespace. Unknown raw values fall
    /// back to the rawValue itself.
    func displayName(in language: CatalogLanguage) -> String {
        switch self {
        case .aiDelegate:
            return LocaleStrings.localized("user.role.aiDelegate", in: language)
        case .viewer:
            return LocaleStrings.localized("user.role.viewer", in: language)
        case .operatorRole:
            return LocaleStrings.localized("user.role.operatorRole", in: language)
        case .admin:
            return LocaleStrings.localized("user.role.admin", in: language)
        }
    }
}
