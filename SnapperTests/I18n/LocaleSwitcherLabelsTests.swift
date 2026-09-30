import XCTest
@testable import Snapper

/// Pure-function tests for ``LocaleSwitcherLabels.accessibilityLabel``.
/// Asserts both branch templates resolve against the current
/// catalog language and announce a language, including script
/// variants, instead of a country name.
final class LocaleSwitcherLabelsTests: XCTestCase {

    func testSwitchToPolishFromUSCurrent() {
        let label = LocaleSwitcherLabels.accessibilityLabel(for: .pl, current: .us)
        XCTAssertTrue(label.contains("Switch to"), "Expected EN template, got: \(label)")
        XCTAssertTrue(label.contains("Polish"), "Expected English language name, got: \(label)")
        XCTAssertFalse(label.contains("Poland"))
    }

    func testCurrentLanguagePolishWhenCurrentIsPL() {
        let label = LocaleSwitcherLabels.accessibilityLabel(for: .pl, current: .pl)
        XCTAssertTrue(label.contains("Bieżący język"), "Expected Polish template, got: \(label)")
        XCTAssertTrue(label.contains("polski"), "Expected Polish language name, got: \(label)")
        XCTAssertFalse(label.contains("Polska"))
    }

    func testSwitchToIcelandicUsesLanguageName() {
        let label = LocaleSwitcherLabels.accessibilityLabel(for: .iceland, current: .us)
        XCTAssertTrue(label.contains("Switch to"), "Expected EN template, got: \(label)")
        XCTAssertTrue(label.contains("Icelandic"), "Expected Icelandic, got: \(label)")
    }

    func testSwitchToHindiUsesLanguageNameInPolishCurrent() {
        let label = LocaleSwitcherLabels.accessibilityLabel(for: .india, current: .pl)
        XCTAssertTrue(label.contains("Przełącz na"), "Expected Polish template, got: \(label)")
        XCTAssertTrue(label.contains("hindi"), "Expected Hindi language name, got: \(label)")
        XCTAssertFalse(label.contains("Indie"))
    }

    func testCurrentLanguageIrishWhenCurrentIsIE() {
        let label = LocaleSwitcherLabels.accessibilityLabel(for: .ie, current: .ie)
        XCTAssertTrue(label.contains("Teanga reatha"), "Expected Irish template, got: \(label)")
        XCTAssertTrue(label.contains("Gaeilge"), "Expected Irish language name, got: \(label)")
        XCTAssertFalse(label.contains("Éire"))
    }

    func testChineseScriptVariantsHaveDistinctLanguageLabels() {
        let simplified = LocaleSwitcherLabels.accessibilityLabel(for: .cn, current: .us)
        let traditional = LocaleSwitcherLabels.accessibilityLabel(for: .hk, current: .us)
        XCTAssertTrue(simplified.contains("Chinese"))
        XCTAssertTrue(traditional.contains("Chinese"))
        XCTAssertNotEqual(simplified, traditional)
        XCTAssertFalse(traditional.contains("Hong Kong"))
    }
}
