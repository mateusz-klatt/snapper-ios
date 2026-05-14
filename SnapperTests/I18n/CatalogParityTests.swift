import XCTest
@testable import Snapper

/// Loads ``Localizable.xcstrings`` as JSON and asserts:
/// - the exact 18-key set from v7 D.3 is present,
/// - every key has both ``en`` and ``pl`` localizations,
/// - placeholder schemas (``%@``, ``%lld``) match between EN and PL,
/// - Polish characters are stored as literal UTF-8 (no ``\u`` escapes).
final class CatalogParityTests: XCTestCase {

    private static let expectedKeys: Set<String> = [
        "auth.login.subtitle",
        "auth.login.usernamePlaceholder",
        "auth.login.passwordPlaceholder",
        "auth.login.signIn",
        "auth.login.advancedDisclosure",
        "auth.login.currentBackend",
        "backend.url.placeholder",
        "backend.url.willSaveAs",
        "backend.url.invalidDebug",
        "backend.url.invalidRelease",
        "backend.url.help",
        "backend.url.cancel",
        "backend.url.resetToDefault",
        "backend.url.save",
        "settings.section.language",
        "common.localeSwitcher.triggerAccessibilityLabel",
        "common.localeSwitcher.flagAccessibilityLabel",
        "common.localeSwitcher.currentAccessibilityLabel",
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

    func testEveryExpectedKeyIsPresent() throws {
        let catalog = try loadCatalog()
        let actual = Set(catalog.strings.keys)
        XCTAssertEqual(
            actual,
            Self.expectedKeys,
            "Catalog key set drift: added=\(actual.subtracting(Self.expectedKeys)) removed=\(Self.expectedKeys.subtracting(actual))"
        )
    }

    func testEveryKeyHasBothEnAndPlLocalizations() throws {
        let catalog = try loadCatalog()
        for key in Self.expectedKeys {
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
        for key in Self.expectedKeys {
            guard let entry = catalog.strings[key],
                  let en = entry.localizations["en"]?.stringUnit.value,
                  let pl = entry.localizations["pl"]?.stringUnit.value
            else {
                XCTFail("Catalog missing rows for \(key)")
                continue
            }
            let enPlaceholders = Self.placeholders(in: en)
            let plPlaceholders = Self.placeholders(in: pl)
            XCTAssertEqual(
                enPlaceholders,
                plPlaceholders,
                "Placeholder mismatch for \(key): EN=\(enPlaceholders) PL=\(plPlaceholders)"
            )
        }
    }

    func testPolishCharactersStoredAsLiteralUTF8() throws {
        let raw = try String(contentsOf: Self.catalogURL, encoding: .utf8)
        XCTAssertFalse(raw.contains(#"\u00"#), "Catalog contains \\u escapes — Polish characters must be literal UTF-8")
        XCTAssertTrue(raw.contains("ł") || raw.contains("ś") || raw.contains("ę") || raw.contains("ą"),
                      "Expected at least one Polish diacritic character in catalog source")
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
