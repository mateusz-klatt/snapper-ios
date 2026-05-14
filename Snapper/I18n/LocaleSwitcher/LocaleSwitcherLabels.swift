import Foundation

/// Pure accessibility-label builder for ``LocaleSwitcher`` flag
/// buttons. Picks between the "Switch to <country>" and "Current
/// language: <country>" templates based on whether the target
/// ``code`` is already the current locale; resolves the country
/// name via ``Locale.localizedString(forRegionCode:)`` so it
/// follows the active catalog language.
///
/// Extracted as a pure function (no SwiftUI environment, no
/// ``AppState`` injection) so the test surface mirrors the
/// MainTabView-style pure-helper pattern.
enum LocaleSwitcherLabels {

    /// Returns the localized accessibility label for a flag button.
    ///
    /// - Parameter code: The country code the flag button represents.
    /// - Parameter current: The currently-selected locale (drives
    ///   both the template selection and the locale passed to
    ///   ``String(localized:locale:)`` so the format string
    ///   resolves against the active catalog language).
    static func accessibilityLabel(for code: AppLocale, current: AppLocale) -> String {
        let locale = current.nativeLocale
        let country = locale.localizedString(forRegionCode: code.rawValue.uppercased())
            ?? code.rawValue.uppercased()
        let key = code == current
            ? "common.localeSwitcher.currentAccessibilityLabel"
            : "common.localeSwitcher.flagAccessibilityLabel"
        let template = LocaleStrings.localized(key, in: current.catalogLanguage)
        return String(format: template, locale: locale, country)
    }
}
