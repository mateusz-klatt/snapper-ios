import XCTest
@testable import Snapper

/// Covers ``LocaleFormatters`` factory methods — verifies that
/// formatters bound to ``AppLocale.nativeLocale`` honor per-locale
/// CLDR conventions (decimal separator, currency symbol position,
/// percent spacing).
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
        let formatterEN = LocaleFormatters.relativeDateTime(for: .ie)
        let formatterPL = LocaleFormatters.relativeDateTime(for: .pl)
        XCTAssertEqual(formatterEN.locale.identifier, "en-IE")
        XCTAssertEqual(formatterPL.locale.identifier, "pl-PL")
    }

    func testCompactDurationFormatterIsLocaleBound() {
        let formatter = LocaleFormatters.compactDuration(for: .pl)
        XCTAssertEqual(formatter.calendar?.locale?.identifier, "pl-PL")
    }
}
