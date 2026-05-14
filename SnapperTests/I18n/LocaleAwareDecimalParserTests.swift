import XCTest
@testable import Snapper

/// Covers ``LocaleAwareDecimalParser.parse(_:locale:)`` — locale-aware
/// decimal-string parsing for trading inputs.
final class LocaleAwareDecimalParserTests: XCTestCase {

    func testParsesDotDecimalForEnglish() {
        let result = LocaleAwareDecimalParser.parse("1.5", locale: .ie)
        XCTAssertEqual(result, Decimal(string: "1.5"))
    }

    func testParsesCommaDecimalForPolish() {
        let result = LocaleAwareDecimalParser.parse("1,5", locale: .pl)
        XCTAssertEqual(result, Decimal(string: "1.5"))
    }

    func testParsesDotDecimalForPolishAsFallback() {
        let result = LocaleAwareDecimalParser.parse("1.5", locale: .pl)
        XCTAssertEqual(result, Decimal(string: "1.5"))
    }

    func testStripsThousandsSeparatorForEnglish() {
        let result = LocaleAwareDecimalParser.parse("1,234.56", locale: .ie)
        XCTAssertEqual(result, Decimal(string: "1234.56"))
    }

    func testStripsNonBreakingSpaceForPolish() {
        let result = LocaleAwareDecimalParser.parse("1\u{00A0}234,56", locale: .pl)
        XCTAssertEqual(result, Decimal(string: "1234.56"))
    }

    func testRejectsDoubleDecimal() {
        let result = LocaleAwareDecimalParser.parse("1.5.6", locale: .ie)
        XCTAssertNil(result)
    }

    func testRejectsAlphabetic() {
        let result = LocaleAwareDecimalParser.parse("abc", locale: .ie)
        XCTAssertNil(result)
    }

    func testRejectsEmpty() {
        let result = LocaleAwareDecimalParser.parse("", locale: .ie)
        XCTAssertNil(result)
    }

    func testRejectsWhitespaceOnly() {
        let result = LocaleAwareDecimalParser.parse("   ", locale: .ie)
        XCTAssertNil(result)
    }

    func testAcceptsLeadingNegative() {
        let result = LocaleAwareDecimalParser.parse("-1.5", locale: .ie)
        XCTAssertEqual(result, Decimal(string: "-1.5"))
    }

    func testAcceptsLeadingPositive() {
        let result = LocaleAwareDecimalParser.parse("+2.5", locale: .ie)
        XCTAssertEqual(result, Decimal(string: "2.5"))
    }

    func testRejectsSignInMiddle() {
        let result = LocaleAwareDecimalParser.parse("1-5", locale: .ie)
        XCTAssertNil(result)
    }

    func testTrimsLeadingTrailingWhitespace() {
        let result = LocaleAwareDecimalParser.parse("  1.5  ", locale: .ie)
        XCTAssertEqual(result, Decimal(string: "1.5"))
    }

    func testRejectsSignOnlyInput() {
        let result = LocaleAwareDecimalParser.parse("-", locale: .ie)
        XCTAssertNil(result)
    }
}
