import Foundation

/// Languages with full string-catalog coverage in v1.
///
/// Today: English (source) + Polish. Adding a third language means
/// adding a new case here AND extending ``Localizable.xcstrings``
/// with the new locale column AND updating
/// ``CountryMappings/catalogLanguage(for:)`` if a new country code
/// should pick the new language.
///
/// Country codes outside of this set still pick a locale identifier
/// (e.g. ``AppLocale/de`` → ``"en-DE"``) so date formatting follows
/// the regional convention, but the catalog falls back to English.
enum CatalogLanguage: String, CaseIterable, Codable, Sendable {
    case en
    case pl
}
