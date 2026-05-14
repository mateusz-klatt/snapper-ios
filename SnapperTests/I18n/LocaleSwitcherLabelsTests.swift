import XCTest
@testable import Snapper

/// Pure-function tests for ``LocaleSwitcherLabels.accessibilityLabel``.
/// Asserts both branch templates resolve against the current
/// catalog language and the country name is taken from the
/// current locale's region table.
final class LocaleSwitcherLabelsTests: XCTestCase {

    func testSwitchToPolandFromUSCurrent() {
        let label = LocaleSwitcherLabels.accessibilityLabel(for: .pl, current: .us)
        XCTAssertTrue(label.contains("Switch to"), "Expected EN template, got: \(label)")
        XCTAssertTrue(label.contains("Poland"), "Expected English country name, got: \(label)")
    }

    func testCurrentLanguagePolishWhenCurrentIsPL() {
        let label = LocaleSwitcherLabels.accessibilityLabel(for: .pl, current: .pl)
        XCTAssertTrue(label.contains("Bieżący język"), "Expected Polish template, got: \(label)")
        XCTAssertTrue(label.contains("Polska"), "Expected Polish country name, got: \(label)")
    }

    func testSwitchToIcelandUsesIcelandCase() {
        let label = LocaleSwitcherLabels.accessibilityLabel(for: .iceland, current: .us)
        XCTAssertTrue(label.contains("Switch to"), "Expected EN template, got: \(label)")
        XCTAssertTrue(label.contains("Iceland"), "Expected Iceland, got: \(label)")
    }

    func testSwitchToIndiaUsesIndiaCaseInPolishCurrent() {
        let label = LocaleSwitcherLabels.accessibilityLabel(for: .india, current: .pl)
        XCTAssertTrue(label.contains("Przełącz na"), "Expected Polish template, got: \(label)")
        XCTAssertTrue(label.contains("Indie"), "Expected Polish country name for India, got: \(label)")
    }

    func testCurrentLanguageEnglishWhenCurrentIsIE() {
        let label = LocaleSwitcherLabels.accessibilityLabel(for: .ie, current: .ie)
        XCTAssertTrue(label.contains("Current language"), "Expected EN template, got: \(label)")
        XCTAssertTrue(label.contains("Ireland"), "Expected English country name, got: \(label)")
    }
}
