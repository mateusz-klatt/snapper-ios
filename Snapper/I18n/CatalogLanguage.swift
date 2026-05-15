import Foundation

/// Languages with string-catalog coverage.
///
/// Source language is ``en``. Every other case represents a translated
/// column in ``Localizable.xcstrings`` (``Resources/Localization``).
/// Adding a language means adding a case here AND extending the
/// xcstrings file AND updating ``CountryMappings/catalogLanguage(for:)``
/// for every country code that should pick the new language.
///
/// Country codes outside of this set still pick a BCP-47 locale
/// identifier (e.g. ``AppLocale/ke`` → ``"en-KE"``) so date formatting
/// follows the regional convention, but the catalog falls back to
/// English when the country code does not map to a translated language.
///
/// Batch-1 (2026-05-15) added 15 European languages:
/// de, fr, es, it, nl, pt-BR, sv, nb, da, fi, cs, sk, hu, ro, hr.
///
/// Batch-2 (2026-05-15) adds 15 more: uk, ru, lt, lv, sr-Latn, bs,
/// sq, is, el, tr, fil, ms, id, sw, bn — covering Slavic East, Baltic,
/// Balkan, Anatolian, Maritime SE-Asia, East Africa, and Indic regions.
///
/// Batch-3 (2026-05-15) closes the 45-country picker with 12 more
/// languages: zh-Hans (mainland Chinese), zh-Hant (HK/TW Chinese),
/// ja, ko, th, vi, my (Burmese), hi, ar (RTL), he (RTL), fa (RTL),
/// hy — adding CJK, Indic, Arabic-script RTL, and Armenian coverage.
enum CatalogLanguage: String, CaseIterable, Codable, Sendable {
    case en
    case pl
    case de
    case fr
    case es
    case it
    case nl
    case ptBR = "pt-BR"
    case sv
    case nb
    case da
    case fi
    case cs
    case sk
    case hu
    case ro
    case hr
    case uk
    case ru
    case lt
    case lv
    case srLatn = "sr-Latn"
    case bs
    case sq
    case icelandic = "is"
    case el
    case tr
    case fil
    case ms
    case id
    case sw
    case bn
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case ja
    case ko
    case th
    case vi
    case my
    case hi
    case ar
    case he
    case fa
    case hy
}
