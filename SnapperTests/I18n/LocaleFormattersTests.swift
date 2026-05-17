import XCTest
@testable import Snapper

/// Covers ``LocaleFormatters`` factory methods — verifies that
/// formatters bound to ``AppLocale.westernDigitsLocale`` honor per-locale
/// CLDR conventions (decimal separator, currency symbol position,
/// percent spacing) while pinning numbers to Western digits.
final class LocaleFormattersTests: XCTestCase {

    func testDecimalSeparatorIsDotForEnglishIE() {
        let formatter = LocaleFormatters.decimal(for: .ie, fractionDigits: 2)
        let result = formatter.string(from: NSNumber(value: 1234.56))
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains(".56") ?? false,
                      "EN_IE decimal should use '.' separator: got \(result ?? "nil")")
    }

    func testDecimalSeparatorIsCommaForPolish() {
        let formatter = LocaleFormatters.decimal(for: .pl, fractionDigits: 2)
        let result = formatter.string(from: NSNumber(value: 1234.56))
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains(",56") ?? false,
                      "PL_PL decimal should use ',' separator: got \(result ?? "nil")")
    }

    func testCurrencyFormatterUsesEuroForIE() {
        let formatter = LocaleFormatters.currency(for: .ie, code: "EUR", fractionDigits: 2)
        let result = formatter.string(from: NSNumber(value: 100))
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("€") ?? false,
                      "EUR currency should render with € symbol: got \(result ?? "nil")")
    }

    func testCurrencyFormatterUsesZlotyForPL() {
        let formatter = LocaleFormatters.currency(for: .pl, code: "PLN", fractionDigits: 2)
        let result = formatter.string(from: NSNumber(value: 100))
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("zł") ?? false || result?.contains("PLN") ?? false,
                      "PLN currency should render with zł or PLN symbol: got \(result ?? "nil")")
    }

    func testPercentFormatterReturnsFormattedString() {
        let formatter = LocaleFormatters.percent(for: .ie, fractionDigits: 1)
        let result = formatter.string(from: NSNumber(value: 0.05))
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("%") ?? false,
                      "Percent should include % symbol: got \(result ?? "nil")")
    }

    func testRelativeDateTimeFormatterIsLocaleBound() {
        let formatterIE = LocaleFormatters.relativeDateTime(for: .ie)
        let formatterPL = LocaleFormatters.relativeDateTime(for: .pl)
        XCTAssertEqual(
            formatterIE.locale.language.languageCode?.identifier,
            "ga",
            "EN/IE formatter language tag must be Irish; got \(formatterIE.locale.identifier)"
        )
        XCTAssertEqual(
            formatterPL.locale.language.languageCode?.identifier,
            "pl",
            "PL formatter language tag must be Polish; got \(formatterPL.locale.identifier)"
        )
        XCTAssertEqual(
            formatterIE.locale.numberingSystem.identifier,
            "latn",
            "Numbering system must be Latin for Western-digit policy"
        )
    }

    func testCompactDurationFormatterIsLocaleBound() {
        let formatter = LocaleFormatters.compactDuration(for: .pl)
        XCTAssertEqual(
            formatter.calendar?.locale?.language.languageCode?.identifier,
            "pl",
            "PL formatter calendar locale must be rooted at Polish; got \(formatter.calendar?.locale?.identifier ?? "nil")"
        )
    }

    /// Phase D ergonomic helper — verifies the wrapper routes
    /// ``Double`` through ``LocaleFormatters.decimal`` and produces
    /// locale-aware separators for both EN and PL.
    func testFormattedDecimalRespectsLocaleSeparator() {
        let enIE = (1234.5678).formattedDecimal(in: .ie, fractionDigits: 4)
        let plPL = (1234.5678).formattedDecimal(in: .pl, fractionDigits: 4)

        XCTAssertTrue(enIE.contains("."), "EN_IE decimal expects '.' separator: got \(enIE)")
        XCTAssertTrue(plPL.contains(","), "PL_PL decimal expects ',' separator: got \(plPL)")
        XCTAssertFalse(plPL.contains(".5678"),
                       "PL_PL decimal must not contain '.' fraction: got \(plPL)")
    }

    /// Phase D ergonomic helper — verifies that USD currency
    /// rendering follows CLDR per locale (``$`` prefix in EN-US-style
    /// regions, ``US$`` disambiguator in regions where the local
    /// currency is not USD, suffix ``USD`` in PL).
    func testFormattedCurrencyUSDLocaleVariants() {
        let enIE = (4.21).formattedCurrency(in: .ie, code: "USD", fractionDigits: 2)
        let plPL = (4.21).formattedCurrency(in: .pl, code: "USD", fractionDigits: 2)

        XCTAssertTrue(enIE.contains("$"), "EN_IE USD must contain '$' symbol: got \(enIE)")
        XCTAssertTrue(plPL.contains("USD") || plPL.contains("$"),
                      "PL_PL USD must contain 'USD' or '$' marker: got \(plPL)")
        XCTAssertTrue(plPL.contains(","),
                      "PL_PL USD must use ',' decimal separator: got \(plPL)")
    }

    /// Phase D ergonomic helper — verifies that the percent style
    /// applies the ``×100`` scaling and ``fractionDigits: 0`` yields
    /// a whole-number percent for slider-ratio buttons.
    func testFormattedPercentScalesAndTrimsFraction() {
        let enIE = (0.25).formattedPercent(in: .ie, fractionDigits: 0)
        let plPL = (0.25).formattedPercent(in: .pl, fractionDigits: 0)

        XCTAssertTrue(enIE.contains("25"),
                      "0.25 → 25% expected for EN: got \(enIE)")
        XCTAssertTrue(plPL.contains("25"),
                      "0,25 → 25 % expected for PL: got \(plPL)")
        XCTAssertFalse(enIE.contains(".0"),
                       "fractionDigits=0 must trim fractional part: got \(enIE)")
    }
}
