import XCTest
@testable import Snapper

/// Pure-function tests for ``LocaleSwitcherStyling.isSelected``.
final class LocaleSwitcherStylingTests: XCTestCase {

    func testIsSelectedTrueWhenCodeMatchesCurrent() {
        XCTAssertTrue(LocaleSwitcherStyling.isSelected(code: .pl, current: .pl))
    }

    func testIsSelectedFalseWhenCodeDiffers() {
        XCTAssertFalse(LocaleSwitcherStyling.isSelected(code: .pl, current: .ie))
        XCTAssertFalse(LocaleSwitcherStyling.isSelected(code: .ie, current: .pl))
        XCTAssertFalse(LocaleSwitcherStyling.isSelected(code: .us, current: .pl))
    }

    func testIsSelectedTrueForBacktickedIS() {
        XCTAssertTrue(LocaleSwitcherStyling.isSelected(code: .`is`, current: .`is`))
    }

    func testIsSelectedTrueForBacktickedIN() {
        XCTAssertTrue(LocaleSwitcherStyling.isSelected(code: .`in`, current: .`in`))
    }

    func testIsSelectedFalseAcrossBacktickedCodes() {
        XCTAssertFalse(LocaleSwitcherStyling.isSelected(code: .`is`, current: .`in`))
        XCTAssertFalse(LocaleSwitcherStyling.isSelected(code: .`in`, current: .`is`))
    }

    func testExactlyOneCodeIsSelectedPerCurrent() {
        for current in AppLocale.allCases {
            let selected = AppLocale.allCases.filter {
                LocaleSwitcherStyling.isSelected(code: $0, current: current)
            }
            XCTAssertEqual(selected, [current], "Exactly one code should be selected for current=\(current.rawValue)")
        }
    }
}
