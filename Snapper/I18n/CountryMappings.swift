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
    /// bs, sq, is, el, tr, fil, ms, id, sw, bn. Countries not in
    /// either batch still fall back to ``.en``.
    static func catalogLanguage(for code: AppLocale) -> CatalogLanguage {
        switch code {
        case .pl: return .pl
        case .de: return .de
        case .fr: return .fr
        case .es: return .es
        case .it: return .it
        case .nl: return .nl
        case .br: return .ptBR
        case .se: return .sv
        case .no: return .nb
        case .dk: return .da
        case .fi: return .fi
        case .cz: return .cs
        case .sk: return .sk
        case .hu: return .hu
        case .ro: return .ro
        case .hr: return .hr
        case .ua: return .uk
        case .ru: return .ru
        case .lt: return .lt
        case .lv: return .lv
        case .rs: return .srLatn
        case .ba: return .bs
        case .al: return .sq
        case .iceland: return .`is`
        case .gr: return .el
        case .tr: return .tr
        case .ph: return .fil
        case .my: return .ms
        case .id: return .id
        case .ke: return .sw
        case .bd: return .bn
        default: return .en
        }
    }

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
