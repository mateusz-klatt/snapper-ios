import XCTest
@testable import Snapper

/// Locks the catalog-language fallback and BCP-47 identifier
/// derivation for every ``AppLocale`` code. Only ``.pl`` resolves
/// to a non-English catalog in v1; every other code falls back to
/// ``.en`` while keeping its country-region suffix.
final class CountryMappingsTests: XCTestCase {

    func testPolandMapsToPolishCatalog() {
        XCTAssertEqual(CountryMappings.catalogLanguage(for: .pl), .pl)
    }

    func testEveryOtherCodeMapsToEnglishCatalog() {
        for code in AppLocale.allCases where code != .pl {
            XCTAssertEqual(
                CountryMappings.catalogLanguage(for: code),
                .en,
                "Expected \(code.rawValue) → .en"
            )
        }
    }

    func testIntlLocaleIdentifierSampledCodes() {
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .ie), "en-IE")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .pl), "pl-PL")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .de), "en-DE")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .ae), "en-AE")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .us), "en-US")
    }

    /// Backtick regression — both reserved-keyword cases must
    /// resolve to ``en-IS`` / ``en-IN`` (not the unrelated Icelandic
    /// / Hindi language tags that ``is`` / ``in`` are also valid for).
    func testIntlLocaleIdentifierBacktickedCodes() {
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .`is`), "en-IS")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .`in`), "en-IN")
    }

    func testIntlLocaleIdentifierAlwaysHasCatalogLanguagePrefix() {
        for code in AppLocale.allCases {
            let id = CountryMappings.intlLocaleIdentifier(for: code)
            let catalog = CountryMappings.catalogLanguage(for: code).rawValue
            XCTAssertTrue(
                id.hasPrefix("\(catalog)-"),
                "\(code.rawValue) → \(id) should start with \(catalog)-"
            )
        }
    }
}
