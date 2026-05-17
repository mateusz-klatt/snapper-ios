import XCTest
@testable import Snapper

/// Covers ``AppLocale.westernDigitsLocale`` and the routing through
/// ``LocaleFormatters`` for trading surfaces.
///
/// Rationale lives in the digit-policy section of the 2026-05-17
/// visual-QA findings: ``ae``/``ir`` previously mixed Eastern-Arabic
/// digits on the chart x-axis with Western digits on the price tile,
/// inconsistent within a single screen. Bloomberg/Bybit/Binance all
/// render Western digits in Arabic / Persian UIs for numerical
/// legibility — this test asserts Snapper follows the same convention.
final class WesternDigitsLocaleTests: XCTestCase {

    func testWesternDigitsLocaleIsAppliedForArabicEmirates() {
        let formatter = LocaleFormatters.decimal(for: .ae, fractionDigits: 2)
        let result = formatter.string(from: NSNumber(value: 78158.6)) ?? ""
        XCTAssertEqual(result.unicodeScalars.filter { $0.properties.isAlphabetic == false }.count,
                       result.unicodeScalars.count,
                       "Decimal output may contain only digit/punctuation scalars: got \(result)")
        for character in result {
            for scalar in character.unicodeScalars {
                if scalar.properties.numericType != nil {
                    XCTAssertLessThanOrEqual(
                        scalar.value,
                        UInt32(0x39),
                        "Arabic-Emirates decimal must use Western digits (0-9), got scalar \(scalar.value) in \(result)"
                    )
                }
            }
        }
        XCTAssertTrue(result.contains("78"), "Western digits must surface 78xxx; got \(result)")
    }

    func testWesternDigitsLocaleIsAppliedForPersianIran() {
        let formatter = LocaleFormatters.decimal(for: .ir, fractionDigits: 2)
        let result = formatter.string(from: NSNumber(value: 78241.6)) ?? ""
        for character in result {
            for scalar in character.unicodeScalars {
                if scalar.properties.numericType != nil {
                    XCTAssertLessThanOrEqual(
                        scalar.value,
                        UInt32(0x39),
                        "Persian-Iran decimal must use Western digits (0-9), got scalar \(scalar.value) in \(result)"
                    )
                }
            }
        }
        XCTAssertTrue(result.contains("78"), "Western digits must surface 78xxx; got \(result)")
    }

    func testWesternDigitsLocaleIsAppliedForBengali() {
        let formatter = LocaleFormatters.decimal(for: .bd, fractionDigits: 2)
        let result = formatter.string(from: NSNumber(value: 78000.5)) ?? ""
        for character in result {
            for scalar in character.unicodeScalars {
                if scalar.properties.numericType != nil {
                    XCTAssertLessThanOrEqual(
                        scalar.value,
                        UInt32(0x39),
                        "Bengali decimal must use Western digits (0-9), got scalar \(scalar.value) in \(result)"
                    )
                }
            }
        }
        XCTAssertTrue(result.contains("78"), "Western digits must surface 78xxx; got \(result)")
    }

    func testWesternDigitsLocalePreservesDecimalSeparator() {
        let plFormatter = LocaleFormatters.decimal(for: .pl, fractionDigits: 2)
        let plResult = plFormatter.string(from: NSNumber(value: 1234.56)) ?? ""
        XCTAssertTrue(
            plResult.contains(",56"),
            "PL must still use ',' as decimal separator even with western-digit pinning; got \(plResult)"
        )

        let ieFormatter = LocaleFormatters.decimal(for: .ie, fractionDigits: 2)
        let ieResult = ieFormatter.string(from: NSNumber(value: 1234.56)) ?? ""
        XCTAssertTrue(
            ieResult.contains(".56"),
            "EN/IE must still use '.' as decimal separator; got \(ieResult)"
        )
    }

    func testWesternDigitsLocaleIdentifierEncodesNumberingSystem() {
        let aeLocale = AppLocale.ae.westernDigitsLocale
        XCTAssertEqual(
            aeLocale.numberingSystem.identifier,
            "latn",
            "ae westernDigitsLocale must declare latn numbering system; got \(aeLocale.numberingSystem.identifier)"
        )
        let irLocale = AppLocale.ir.westernDigitsLocale
        XCTAssertEqual(
            irLocale.numberingSystem.identifier,
            "latn",
            "ir westernDigitsLocale must declare latn numbering system; got \(irLocale.numberingSystem.identifier)"
        )
    }

    func testWesternDigitsLocaleDoesNotChangeLanguageTag() {
        let aeLocale = AppLocale.ae.westernDigitsLocale
        XCTAssertEqual(aeLocale.language.languageCode?.identifier, "ar",
                       "ae westernDigitsLocale must preserve Arabic language tag")
        let irLocale = AppLocale.ir.westernDigitsLocale
        XCTAssertEqual(irLocale.language.languageCode?.identifier, "fa",
                       "ir westernDigitsLocale must preserve Persian language tag")
    }
}
