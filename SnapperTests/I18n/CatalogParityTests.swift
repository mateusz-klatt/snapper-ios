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
/// The bidirectional ``ExpectedKeys.values ⊆ catalog`` assertion
/// activates at end of Phase H rollout via
/// ``Snapper/I18n/PhaseHRolloutStatus.isComplete``. During rollout the
/// v1-locked subset still gets the strict treatment.
final class CatalogParityTests: XCTestCase {

    private static let expectedKeys: Set<String> = ExpectedKeys.values
    private static let v1LockedKeys: Set<String> = ExpectedKeys.v1Locked

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

    func testPolishCharactersStoredAsLiteralUTF8() throws {
        let raw = try String(contentsOf: Self.catalogURL, encoding: .utf8)
        XCTAssertFalse(raw.contains(#"\u00"#),
                       "Catalog contains \\u escapes — Polish characters must be literal UTF-8")
    }

    func testEveryExpectedKeyAppearsInCatalog() throws {
        guard PhaseHRolloutStatus.isComplete else {
            throw XCTSkip("Phase H rollout in progress — bidirectional parity activates when PhaseHRolloutStatus.isComplete flips to true at end of Phase J")
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
