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
/// Batch-1 rollout (2026-05-15) adds 15 European languages:
/// de, fr, es, it, nl, pt-BR, sv, nb, da, fi, cs, sk, hu, ro, hr.
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
}
