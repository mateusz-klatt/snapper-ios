import Foundation

/// Pure mappings from ``AppLocale`` country code to catalog
/// language and BCP-47 locale identifier. Extracted from
/// ``AppLocale`` so the lookup logic is unit-testable without
/// importing SwiftUI and without constructing app state.
///
/// Mirror of the ``COUNTRY_TO_LANGUAGE`` and
/// ``COUNTRY_TO_INTL_LOCALE`` maps in
/// ``frontend/src/i18n/countryLanguages.ts``. Updating one side
/// without the other is caught by
/// ``AppLocale+ParityTests``.
enum CountryMappings {

    /// Catalog language for a given country code. v1 ships English
    /// as the source language and Polish as the only translation;
    /// every code except ``pl`` falls back to ``en``.
    static func catalogLanguage(for code: AppLocale) -> CatalogLanguage {
        if code == .pl {
            return .pl
        }
        return .en
    }

    /// BCP-47 identifier ``<catalogLanguage>-<COUNTRY>`` produced
    /// by joining the catalog language with the uppercased country
    /// code. Example: ``.ie`` → ``"en-IE"``, ``.pl`` → ``"pl-PL"``,
    /// ``.de`` → ``"en-DE"``.
    ///
    /// Country codes like ``ie`` / ``br`` / ``se`` are themselves
    /// valid BCP-47 LANGUAGE tags for unrelated languages (Irish
    /// Gaelic, Breton, Northern Sami), so passing the raw country
    /// code to ``Intl.DateTimeFormat`` / ``Locale`` would produce
    /// wrong semantics. Always prefix with the catalog language.
    static func intlLocaleIdentifier(for code: AppLocale) -> String {
        "\(catalogLanguage(for: code).rawValue)-\(code.rawValue.uppercased())"
    }
}
