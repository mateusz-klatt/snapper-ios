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

    /// Catalog language for a given country code. Defaults to
    /// ``CatalogLanguage/en`` when the country does not have a
    /// dedicated translation column in ``Localizable.xcstrings``.
    ///
    /// Batch-1 (2026-05-15) adds 15 European languages alongside
    /// the v1 Polish translation: de, fr, es, it, nl, pt-BR (Brazil),
    /// sv, nb (Norway), da, fi, cs, sk, hu, ro, hr.
    ///
    /// Batch-2 (2026-05-15) adds 15 more: uk, ru, lt, lv, sr-Latn,
    /// bs, sq, is, el, tr, fil, ms, id, sw, bn.
    ///
    /// Batch-3 (2026-05-15) closes the 45-country picker with 12
    /// more languages — every country code in ``AppLocale`` except
    /// ``.ie`` and ``.us`` (which share ``en``) now has a dedicated
    /// catalog translation.
    static func catalogLanguage(for code: AppLocale) -> CatalogLanguage {
        return catalogLanguagesByCode[code, default: .en]
    }

    private static let catalogLanguagesByCode: [AppLocale: CatalogLanguage] = [
        .pl: .pl,
        .de: .de,
        .fr: .fr,
        .es: .es,
        .it: .it,
        .nl: .nl,
        .br: .ptBR,
        .se: .sv,
        .no: .nb,
        .dk: .da,
        .fi: .fi,
        .cz: .cs,
        .sk: .sk,
        .hu: .hu,
        .ro: .ro,
        .hr: .hr,
        .ua: .uk,
        .ru: .ru,
        .lt: .lt,
        .lv: .lv,
        .rs: .srLatn,
        .ba: .bs,
        .al: .sq,
        .iceland: .icelandic,
        .gr: .el,
        .tr: .tr,
        .ph: .fil,
        .my: .ms,
        .id: .id,
        .ke: .sw,
        .bd: .bn,
        .cn: .zhHans,
        .hk: .zhHant,
        .jp: .ja,
        .kr: .ko,
        .th: .th,
        .vn: .vi,
        .mm: .my,
        .india: .hi,
        .ae: .ar,
        .il: .he,
        .ir: .fa,
        .am: .hy,
    ]

    /// BCP-47 identifier ``<catalogLanguage>-<COUNTRY>`` produced
    /// by joining the catalog language with the uppercased country
    /// code. Example: ``.ie`` → ``"en-IE"``, ``.pl`` → ``"pl-PL"``,
    /// ``.de`` → ``"de-DE"``.
    ///
    /// Country codes like ``ie`` / ``br`` / ``se`` are themselves
    /// valid BCP-47 LANGUAGE tags for unrelated languages (Irish
    /// Gaelic, Breton, Northern Sami), so passing the raw country
    /// code to ``Intl.DateTimeFormat`` / ``Locale`` would produce
    /// wrong semantics. Always prefix with the catalog language.
    ///
    /// Special case: when the catalog language rawValue already
    /// encodes a region (e.g. ``"pt-BR"`` for Brazilian Portuguese),
    /// the language tag is returned as-is rather than appended with
    /// another country suffix — ``"pt-BR-BR"`` is invalid BCP-47.
    static func intlLocaleIdentifier(for code: AppLocale) -> String {
        let language = catalogLanguage(for: code).rawValue
        if language.contains("-") {
            return language
        }
        return "\(language)-\(code.rawValue.uppercased())"
    }
}
