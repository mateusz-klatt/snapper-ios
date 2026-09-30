import Foundation

/// Pure detection logic for the user's initial locale, extracted
/// from ``AppState`` so the lookup is unit-testable without
/// constructing app state or touching UserDefaults.
///
/// Precedence:
/// 1. Stored value under ``localeKey`` in the passed
///    ``UserDefaults`` (matches the web v3 ``snapper-locale``
///    localStorage key).
/// 2. First supported language and script in ``preferredLanguages``.
///    A regional picker value is retained only when it uses that
///    language; otherwise the language's supported country is used.
/// 3. ``AppLocale/defaultLocale`` (``.ie``).
enum LocaleResolver {

    /// Resolve from both UserDefaults precedence + system preferred
    /// languages. Used by ``AppState.init`` at app startup.
    static func resolveInitialLocale(
        userDefaults: UserDefaults,
        preferredLanguages: [String],
        localeKey: String
    ) -> AppLocale {
        if let stored = userDefaults.string(forKey: localeKey),
           let app = AppLocale(rawValue: stored) {
            return app
        }
        return Self.resolveFromPreferredLanguages(preferredLanguages)
    }

    /// Pure function. Tests pass literal arrays without UserDefaults.
    ///
    /// Resolve BCP-47 language/script/region preferences in order.
    /// English in Poland stays English; Burmese ``my`` does not
    /// become Malaysian ``ms``. Chinese script takes precedence over
    /// region, while a region-only Chinese preference uses its likely
    /// script. Unicode/private extensions do not become country codes.
    /// Unsupported preferences fall through to the next language.
    static func resolveFromPreferredLanguages(_ preferredLanguages: [String]) -> AppLocale {
        for tag in preferredLanguages {
            let identifier = tag.replacingOccurrences(of: "_", with: "-")
            guard !identifier.split(separator: "-", omittingEmptySubsequences: false)
                .contains(where: \.isEmpty) else { continue }
            let preference = Locale.Language(identifier: identifier)
            guard let language = catalogLanguage(for: preference) else { continue }
            if let region = preference.region?.identifier.lowercased(),
               let app = AppLocale(rawValue: region), app.catalogLanguage == language {
                return app
            }
            if let app = AppLocale.allCases.first(where: { $0.catalogLanguage == language }) {
                return app
            }
        }
        return .defaultLocale
    }

    /// Match supported catalog variants without treating language codes
    /// as countries. Norwegian ``no`` aliases Bokmal; explicit Nynorsk
    /// remains unsupported. Serbian and Portuguese use the available
    /// Latin and Brazilian catalogs. Foundation preserves legacy ISO
    /// aliases, so normalize Hebrew ``iw``, Indonesian ``in`` and
    /// Tagalog ``tl`` here to match the browser's catalog resolution.
    private static func catalogLanguage(for preference: Locale.Language) -> CatalogLanguage? {
        guard let code = preference.languageCode?.identifier.lowercased() else { return nil }
        switch code {
        case "zh": return preference.script?.identifier == "Hant" ? .zhHant : .zhHans
        case "pt": return .ptBR
        case "no": return .nb
        case "sr": return .srLatn
        case "iw": return .he
        case "in": return .id
        case "tl": return .fil
        default: return CatalogLanguage(rawValue: code)
        }
    }
}
