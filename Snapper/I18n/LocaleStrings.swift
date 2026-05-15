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

    /// Look up a raw-String display value under a catalog namespace.
    ///
    /// Used for ViewModel-level ``[String]`` tables (``alertTypes``,
    /// ``priorityValues``, ``orderTypes`` etc.) where the iOS surface
    /// keeps the API rawValue rather than decoding into a typed enum.
    /// ``namespace`` is the catalog hierarchy (e.g. ``"alerts.alertType"``);
    /// ``rawValue`` is the API rawValue (e.g. ``"order_fill_full"``).
    /// Falls back to the rawValue itself on catalog miss.
    static func localizedRawValue(
        _ rawValue: String,
        namespace: String,
        in language: CatalogLanguage
    ) -> String {
        let key = "\(namespace).\(rawValue)"
        let value = localized(key, in: language)
        return value == key ? rawValue : value
    }

    /// Look up a plural-variation catalog key with a count argument.
    ///
    /// Resolves the language-specific ``.stringsdict`` template via
    /// ``NSLocalizedString(_:tableName:bundle:value:comment:)`` against
    /// the lproj path for ``language``, then formats it with a
    /// ``Locale``-scoped ``String(format:locale:_)`` call so the CLDR
    /// plural rules of the LOOKUP language are honored — not the
    /// process locale (Polish needs ``one``/``few``/``many`` even when
    /// the system locale is English, otherwise the macro expansion
    /// asks the bundle for an EN ``other`` entry that does not exist
    /// in the PL stringsdict and returns ``(null)``).
    ///
    /// Falls back to the EN bundle when the requested language's
    /// resource path is missing; falls back to the key itself when the
    /// EN bundle is also missing.
    static func localizedPlural(_ key: String, count: Int, in language: CatalogLanguage) -> String {
        let bundle = resolveBundle(for: language)
        let template = NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        if template == key { return key }
        let locale = Locale(identifier: language.rawValue)
        return String(format: template, locale: locale, count)
    }

    /// Resolve a ``Bundle`` for ``language`` with the same fallback
    /// chain as ``localized(_:in:)`` — requested language -> EN ->
    /// main bundle. Public-private because ``localizedPlural`` needs to
    /// call ``NSLocalizedString`` directly (the format-string variant
    /// path) rather than going through ``lookup``.
    private static func resolveBundle(for language: CatalogLanguage) -> Bundle {
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        if language != .en,
           let path = Bundle.main.path(forResource: CatalogLanguage.en.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
}
