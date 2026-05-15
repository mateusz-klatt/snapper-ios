import Foundation
import XCTest
@testable import Snapper

/// Locks the catalog-language fallback and BCP-47 identifier
/// derivation for every ``AppLocale`` code. Batch-1 rollout
/// (2026-05-15) adds 15 European languages on top of v1 Polish;
/// country codes outside this set still fall back to ``.en`` while
/// keeping their country-region suffix for date formatting.
final class CountryMappingsTests: XCTestCase {

    /// Country code → catalog language, in the same order the
    /// rows render on the locale picker. Updated each time a new
    /// language ships translations.
    private static let translatedLanguageMappings: [(AppLocale, CatalogLanguage)] = [
        (.pl, .pl),
        (.de, .de),
        (.fr, .fr),
        (.es, .es),
        (.it, .it),
        (.nl, .nl),
        (.br, .ptBR),
        (.se, .sv),
        (.no, .nb),
        (.dk, .da),
        (.fi, .fi),
        (.cz, .cs),
        (.sk, .sk),
        (.hu, .hu),
        (.ro, .ro),
        (.hr, .hr),
        (.ua, .uk),
        (.ru, .ru),
        (.lt, .lt),
        (.lv, .lv),
        (.rs, .srLatn),
        (.ba, .bs),
        (.al, .sq),
        (.iceland, .icelandic),
        (.gr, .el),
        (.tr, .tr),
        (.ph, .fil),
        (.my, .ms),
        (.id, .id),
        (.ke, .sw),
        (.bd, .bn),
        (.cn, .zhHans),
        (.hk, .zhHant),
        (.jp, .ja),
        (.kr, .ko),
        (.th, .th),
        (.vn, .vi),
        (.mm, .my),
        (.india, .hi),
        (.ae, .ar),
        (.il, .he),
        (.ir, .fa),
        (.am, .hy),
    ]

    func testTranslatedLanguagesMapToTheirOwnCatalog() {
        for (code, expected) in Self.translatedLanguageMappings {
            XCTAssertEqual(
                CountryMappings.catalogLanguage(for: code),
                expected,
                "Expected \(code.rawValue) → .\(expected.rawValue)"
            )
        }
    }

    func testUntranslatedCodesFallBackToEnglishCatalog() {
        let translatedCodes = Set(Self.translatedLanguageMappings.map { $0.0 })
        for code in AppLocale.allCases where !translatedCodes.contains(code) {
            XCTAssertEqual(
                CountryMappings.catalogLanguage(for: code),
                .en,
                "Expected \(code.rawValue) → .en (no translation column yet)"
            )
        }
    }

    func testIntlLocaleIdentifierSampledCodes() {
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .ie), "en-IE")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .pl), "pl-PL")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .de), "de-DE")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .br), "pt-BR")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .ae), "ar-AE")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .us), "en-US")
    }

    /// Reserved-keyword raw-value regression: both Iceland (`.iceland`,
    /// raw value "is") and India (`.india`, raw value "in") now map
    /// to dedicated catalog languages — Iceland → Icelandic (``is-IS``)
    /// in batch-2 and India → Hindi (``hi-IN``) in batch-3.
    func testIntlLocaleIdentifierKeywordRawValueCodes() {
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .iceland), "is-IS")
        XCTAssertEqual(CountryMappings.intlLocaleIdentifier(for: .india), "hi-IN")
    }

    func testIntlLocaleIdentifierAlwaysHasCatalogLanguagePrefix() {
        for code in AppLocale.allCases {
            let id = CountryMappings.intlLocaleIdentifier(for: code)
            let catalog = CountryMappings.catalogLanguage(for: code).rawValue
            XCTAssertTrue(
                id == catalog || id.hasPrefix("\(catalog)-"),
                "\(code.rawValue) → \(id) should be \(catalog) or start with \(catalog)-"
            )
        }
    }
}
