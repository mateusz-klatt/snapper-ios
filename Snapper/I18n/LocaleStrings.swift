import Foundation

/// Force a catalog lookup against a SPECIFIC language regardless
/// of the system / process preferred-language list. Required
/// because ``String(localized:locale:)`` interprets ``locale:`` as
/// the FORMATTING locale only (numbers, dates, interpolation
/// inflection) — not as the lookup language for the catalog. To
/// switch the lookup language at runtime, we have to ask the
/// bundle for the lproj path directly and resolve through
/// ``NSLocalizedString``.
///
/// SwiftUI views can keep using ``Text(LocalizedStringKey(...))``
/// because ``.environment(\.locale)`` at the app root DOES drive
/// re-resolution there. ``LocaleStrings.localized`` is only for
/// places where a ``String`` value is required (accessibility
/// labels, `TextField` prompts that need a `String`-typed value,
/// `String.init(format:locale:_:)` templates).
enum LocaleStrings {

    /// Look up ``key`` in the catalog scoped to ``language``.
    /// Falls back to the default catalog (system preferred
    /// language) when the lproj bundle cannot be located; the
    /// fallback path is exercised only if the build pipeline drops
    /// the language's resources, which the catalog parity test
    /// catches at build time.
    static func localized(_ key: String, in language: CatalogLanguage) -> String {
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }
        return NSLocalizedString(key, comment: "")
    }
}
