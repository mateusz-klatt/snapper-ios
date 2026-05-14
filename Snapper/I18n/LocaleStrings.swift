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
        if let value = lookup(key, in: language.rawValue) {
            return value
        }
        if language != .en, let value = lookup(key, in: CatalogLanguage.en.rawValue) {
            return value
        }
        return key
    }

    /// Resolve ``key`` against a specific lproj folder. Returns ``nil``
    /// when either the resource path or the lookup itself misses
    /// (``NSLocalizedString`` echoes the key on miss, so we
    /// distinguish a real hit by comparing the result to the key).
    private static func lookup(_ key: String, in lang: String) -> String? {
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }
        let value = NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        return value == key ? nil : value
    }
}
