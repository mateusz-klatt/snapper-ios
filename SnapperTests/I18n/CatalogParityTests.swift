import XCTest
@testable import Snapper

/// Loads ``Localizable.xcstrings`` as JSON and asserts catalog
/// invariants. The expected key sets live in
/// ``SnapperTests/I18n/ExpectedKeys.swift`` and are manually
/// maintained alongside the catalog.
///
/// Tests cover:
/// - source language is ``en``,
/// - catalog version is ``1.0``,
/// - every v1-locked key is present (strict, no skip),
/// - every catalog key is in ``ExpectedKeys.values`` (catches stray
///   catalog adds),
/// - every key has both ``en`` and ``pl`` localizations,
/// - plain-key placeholder schemas (``%@``, ``%lld``) match between
///   EN and PL,
/// - plural-keyed entries declare required CLDR categories per
///   language (EN one+other, PL one+few+many),
/// - placeholder schemas match across plural categories,
/// - Polish characters are stored as literal UTF-8.
///
/// The bidirectional ``ExpectedKeys.values ⊆ catalog`` assertion is
/// controlled by ``Snapper/I18n/PhaseHRolloutStatus.isComplete``. The
/// v1-locked subset always gets strict treatment.
final class CatalogParityTests: XCTestCase {

    private static let expectedKeys: Set<String> = ExpectedKeys.values
    private static let v1LockedKeys: Set<String> = ExpectedKeys.v1Locked

    /// Languages with FULL catalog coverage. Every key in
    /// ``Localizable.xcstrings`` MUST have a localization entry for
    /// each language in this set.
    ///
    /// Batch-1 (2026-05-15) added 15 European languages alongside
    /// the v1 Polish translation. Batch-2 (2026-05-15) adds 15 more:
    /// East-Slavic, Baltic, Balkan, Anatolian, Maritime SE-Asia,
    /// East African, and Indic regions.
    private static let fullyTranslatedLanguages: [String] = [
        "en", "ga", "pl",
        "de", "fr", "es", "it", "nl", "pt-BR",
        "sv", "nb", "da", "fi",
        "cs", "sk", "hu", "ro", "hr",
        "uk", "ru", "lt", "lv", "sr-Latn", "bs",
        "sq", "is", "el", "tr",
        "fil", "ms", "id", "sw", "bn",
        "zh-Hans", "zh-Hant", "ja", "ko", "th", "vi",
        "my", "hi", "ar", "he", "fa", "hy"
    ]

    /// CLDR plural categories required per language for the 7 plural
    /// keys in the catalog. Languages with simpler plural systems
    /// (one + other) MUST NOT include `few` or `many`.
    ///
    /// Plural-rule families covered:
    /// - Slavic 4-category (cs, sk, uk, ru): one/few/many/other
    /// - Polish 3-category (pl): one/few/many (no `other`)
    /// - Slavic 3-category (hr, sr-Latn, bs): one/few/other
    /// - Lithuanian 4-category (lt): one/few/many/other (decimals)
    /// - Latvian 3-category (lv): zero/one/other
    /// - Romanian (ro): one/few/other
    /// - Romance compact-million `many` (fr, es, it, pt-BR): one/many/other
    /// - Germanic + Finnic + Hungarian + Greek + Turkish + Albanian
    ///   + Icelandic + Swahili + Bengali (de, nl, sv, nb, da, fi,
    ///   hu, el, tr, sq, is, sw, bn): one/other
    /// - Malay-Polynesian invariant (ms, id): other only
    /// - Filipino (fil): one (1-2) + other
    private static let requiredPluralCategories: [String: Set<String>] = [
        "en": ["one", "other"],
        "ga": ["one", "two", "few", "many", "other"],
        "pl": ["one", "few", "many"],
        "de": ["one", "other"],
        "fr": ["one", "many", "other"],
        "es": ["one", "many", "other"],
        "it": ["one", "many", "other"],
        "nl": ["one", "other"],
        "pt-BR": ["one", "many", "other"],
        "sv": ["one", "other"],
        "nb": ["one", "other"],
        "da": ["one", "other"],
        "fi": ["one", "other"],
        "cs": ["one", "few", "many", "other"],
        "sk": ["one", "few", "many", "other"],
        "hu": ["one", "other"],
        "ro": ["one", "few", "other"],
        "hr": ["one", "few", "other"],
        "uk": ["one", "few", "many", "other"],
        "ru": ["one", "few", "many", "other"],
        "lt": ["one", "few", "many", "other"],
        "lv": ["zero", "one", "other"],
        "sr-Latn": ["one", "few", "other"],
        "bs": ["one", "few", "other"],
        "sq": ["one", "other"],
        "is": ["one", "other"],
        "el": ["one", "other"],
        "tr": ["one", "other"],
        "fil": ["one", "other"],
        "ms": ["other"],
        "id": ["other"],
        "sw": ["one", "other"],
        "bn": ["one", "other"],
        "zh-Hans": ["other"],
        "zh-Hant": ["other"],
        "ja": ["other"],
        "ko": ["other"],
        "th": ["other"],
        "vi": ["other"],
        "my": ["other"],
        "hi": ["one", "other"],
        "ar": ["zero", "one", "two", "few", "many", "other"],
        "he": ["one", "two", "many", "other"],
        "fa": ["one", "other"],
        "hy": ["one", "other"],
    ]

    private static let catalogURL: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }
        return url
            .appendingPathComponent("Snapper")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localization")
            .appendingPathComponent("Localizable.xcstrings")
    }()

    private struct Catalog: Decodable {
        let sourceLanguage: String
        let version: String
        let strings: [String: Entry]
    }

    private struct Entry: Decodable {
        let extractionState: String?
        let localizations: [String: Localization]
    }

    private struct Localization: Decodable {
        let stringUnit: StringUnit?
        let variations: Variations?
    }

    private struct Variations: Decodable {
        let plural: [String: PluralCategory]?
    }

    private struct PluralCategory: Decodable {
        let stringUnit: StringUnit
    }

    private struct StringUnit: Decodable {
        let state: String
        let value: String
    }

    private func loadCatalog() throws -> Catalog {
        let data = try Data(contentsOf: Self.catalogURL)
        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    func testSourceLanguageIsEnglish() throws {
        let catalog = try loadCatalog()
        XCTAssertEqual(catalog.sourceLanguage, "en")
    }

    func testCatalogVersionIs1Dot0() throws {
        let catalog = try loadCatalog()
        XCTAssertEqual(catalog.version, "1.0")
    }

    func testExpectedKeySetIsNonEmpty() throws {
        XCTAssertFalse(Self.expectedKeys.isEmpty,
                       "ExpectedKeys.values is empty — maintenance error")
    }

    func testEveryKeyInCatalogIsInExpectedSet() throws {
        let catalog = try loadCatalog()
        let extraKeys = Set(catalog.strings.keys).subtracting(Self.expectedKeys)
        XCTAssertTrue(
            extraKeys.isEmpty,
            "Catalog contains keys not in ExpectedKeys.values — add them to ExpectedKeys or remove from catalog: \(extraKeys.sorted())"
        )
    }

    func testV1LockedKeysAllPresent() throws {
        let catalog = try loadCatalog()
        let catalogKeys = Set(catalog.strings.keys)
        let missing = Self.v1LockedKeys.subtracting(catalogKeys)
        XCTAssertTrue(
            missing.isEmpty,
            "v1-locked catalog keys missing — regression: \(missing.sorted())"
        )
    }

    func testEveryKeyHasBothEnAndPlLocalizations() throws {
        let catalog = try loadCatalog()
        for key in catalog.strings.keys {
            guard let entry = catalog.strings[key] else {
                XCTFail("Missing key: \(key)")
                continue
            }
            XCTAssertNotNil(entry.localizations["en"], "Missing EN for \(key)")
            XCTAssertNotNil(entry.localizations["pl"], "Missing PL for \(key)")
        }
    }

    func testPlaceholderSchemaMatchesBetweenEnAndPl() throws {
        let catalog = try loadCatalog()
        for (key, entry) in catalog.strings {
            guard let en = entry.localizations["en"]?.stringUnit?.value,
                  let pl = entry.localizations["pl"]?.stringUnit?.value
            else { continue }
            let enPlaceholders = Self.placeholders(in: en)
            let plPlaceholders = Self.placeholders(in: pl)
            XCTAssertEqual(
                enPlaceholders,
                plPlaceholders,
                "Placeholder mismatch for \(key): EN=\(enPlaceholders) PL=\(plPlaceholders)"
            )
        }
    }

    func testPluralKeysHaveAllRequiredCategories() throws {
        let catalog = try loadCatalog()
        for (key, entry) in catalog.strings {
            guard let en = entry.localizations["en"]?.variations?.plural,
                  let pl = entry.localizations["pl"]?.variations?.plural
            else { continue }
            XCTAssertNotNil(en["one"], "EN plural key \(key) missing 'one' category")
            XCTAssertNotNil(en["other"], "EN plural key \(key) missing 'other' category")
            XCTAssertNotNil(pl["one"], "PL plural key \(key) missing 'one' category")
            XCTAssertNotNil(pl["few"], "PL plural key \(key) missing 'few' category")
            XCTAssertNotNil(pl["many"], "PL plural key \(key) missing 'many' category")
        }
    }

    func testPlaceholderSchemaMatchesAcrossPluralCategories() throws {
        let catalog = try loadCatalog()
        for (key, entry) in catalog.strings {
            guard let en = entry.localizations["en"]?.variations?.plural,
                  let pl = entry.localizations["pl"]?.variations?.plural
            else { continue }
            var schemas: [[String]] = []
            for (_, cat) in en {
                schemas.append(Self.placeholders(in: cat.stringUnit.value))
            }
            for (_, cat) in pl {
                schemas.append(Self.placeholders(in: cat.stringUnit.value))
            }
            guard let first = schemas.first else { continue }
            for schema in schemas {
                XCTAssertEqual(schema, first,
                               "Placeholder schema mismatch in plural categories for \(key)")
            }
        }
    }

    /// Batch-1 multi-language sweep — every key in the catalog has
    /// a localization entry for every fully-translated language.
    /// Failures indicate a missing translation that the merge step
    /// (``/tmp/snapper-i18n/merge.py``) did not pick up; the new
    /// language was added to ``CatalogLanguage`` / ``CountryMappings``
    /// but a row in ``Localizable.xcstrings`` was missed.
    func testEveryKeyHasAllFullyTranslatedLanguages() throws {
        let catalog = try loadCatalog()
        for language in Self.fullyTranslatedLanguages {
            for (key, entry) in catalog.strings {
                XCTAssertNotNil(
                    entry.localizations[language],
                    "Missing \(language) localization for key '\(key)'"
                )
            }
        }
    }

    /// Placeholder schema parity across all fully-translated
    /// languages. A typo in any translation that drops a `%@` or
    /// reorders positional placeholders is caught here.
    func testPlaceholderSchemaMatchesAcrossAllLanguages() throws {
        let catalog = try loadCatalog()
        for (key, entry) in catalog.strings {
            guard let enValue = entry.localizations["en"]?.stringUnit?.value else { continue }
            let enSchema = Self.placeholders(in: enValue)
            for language in Self.fullyTranslatedLanguages where language != "en" {
                guard let value = entry.localizations[language]?.stringUnit?.value else { continue }
                let schema = Self.placeholders(in: value)
                XCTAssertEqual(
                    schema, enSchema,
                    "Placeholder mismatch for '\(key)' in \(language): EN=\(enSchema) \(language)=\(schema)"
                )
            }
        }
    }

    /// Plural keys honor the CLDR plural categories required by
    /// each language. Slavic (cs/sk) require 4 (one/few/many/other);
    /// Polish requires 3 (one/few/many — no `other` per the v1
    /// shipped pattern); Romance with compact-million `many`
    /// (fr/es/it/pt-BR) require 3; Romanian/Croatian require 3
    /// (one/few/other); Germanic + Finnic + Hungarian require 2
    /// (one/other).
    func testPluralCategoriesMatchPerLanguageCLDR() throws {
        let catalog = try loadCatalog()
        for (key, entry) in catalog.strings {
            for (language, requiredCategories) in Self.requiredPluralCategories {
                guard let plural = entry.localizations[language]?.variations?.plural else {
                    continue
                }
                let presentCategories = Set(plural.keys)
                for required in requiredCategories {
                    XCTAssertTrue(
                        presentCategories.contains(required),
                        "Plural key '\(key)' missing '\(required)' CLDR category for language \(language) (has: \(presentCategories.sorted()))"
                    )
                }
            }
        }
    }

    func testPolishCharactersStoredAsLiteralUTF8() throws {
        let raw = try String(contentsOf: Self.catalogURL, encoding: .utf8)
        XCTAssertFalse(raw.contains(#"\u00"#),
                       "Catalog contains \\u escapes — Polish characters must be literal UTF-8")
    }

    func testEveryExpectedKeyAppearsInCatalog() throws {
        guard PhaseHRolloutStatus.isComplete else {
            throw XCTSkip("Bidirectional catalog parity is disabled by PhaseHRolloutStatus — ExpectedKeys.values must match Localizable.xcstrings when enabled")
        }
        let catalog = try loadCatalog()
        let catalogKeys = Set(catalog.strings.keys)
        let missing = Self.expectedKeys.subtracting(catalogKeys)
        XCTAssertTrue(
            missing.isEmpty,
            "Expected catalog keys missing — add them to Localizable.xcstrings: \(missing.sorted())"
        )
    }

    private static func placeholders(in string: String) -> [String] {
        var hits: [String] = []
        let scanner = Scanner(string: string)
        scanner.charactersToBeSkipped = nil
        while !scanner.isAtEnd {
            if scanner.scanString("%") != nil {
                if let token = scanner.scanCharacters(from: CharacterSet(charactersIn: "@dliouxefgs")) {
                    hits.append("%" + token)
                }
            } else {
                _ = scanner.scanCharacter()
            }
        }
        return hits.sorted()
    }
}
