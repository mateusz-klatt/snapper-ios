import XCTest
@testable import Snapper

/// Pure-function tests for ``LocaleSwitcherFocus`` — the grid
/// walker that powers iPad keyboard navigation in
/// ``LocaleSwitcher``.
final class LocaleSwitcherFocusTests: XCTestCase {

    func testPositionForRow1Start() {
        let pos = LocaleSwitcherFocus.position(of: .ie)
        XCTAssertEqual(pos?.row, 0)
        XCTAssertEqual(pos?.col, 0)
    }

    func testPositionForIcelandIsRow1Col13() {
        let pos = LocaleSwitcherFocus.position(of: .iceland)
        XCTAssertEqual(pos?.row, 0)
        XCTAssertEqual(pos?.col, 13)
    }

    func testPositionForIndiaIsRow2Col10() {
        let pos = LocaleSwitcherFocus.position(of: .india)
        XCTAssertEqual(pos?.row, 1)
        XCTAssertEqual(pos?.col, 10)
    }

    func testPositionForRow3End() {
        let pos = LocaleSwitcherFocus.position(of: .am)
        XCTAssertEqual(pos?.row, 2)
        XCTAssertEqual(pos?.col, 14)
    }

    func testRightFromRow1StartMovesToUS() {
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .ie, by: 1, vertical: false), .us)
    }

    func testLeftFromRow1StartIsNil() {
        XCTAssertNil(LocaleSwitcherFocus.next(from: .ie, by: -1, vertical: false))
    }

    func testRightFromRow1EndIsNilNotWrap() {
        XCTAssertNil(LocaleSwitcherFocus.next(from: .gr, by: 1, vertical: false))
    }

    func testDownFromIEColumnAlignsToCN() {
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .ie, by: 1, vertical: true), .cn)
    }

    func testDownFromCNColumnAlignsToCZ() {
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .cn, by: 1, vertical: true), .cz)
    }

    func testDownFromRow3IsNil() {
        XCTAssertNil(LocaleSwitcherFocus.next(from: .am, by: 1, vertical: true))
    }

    func testUpFromRow1IsNil() {
        XCTAssertNil(LocaleSwitcherFocus.next(from: .ie, by: -1, vertical: true))
    }

    func testUpFromCZColumnAlignsToCN() {
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .cz, by: -1, vertical: true), .cn)
    }

    func testDownFromIcelandStaysInColumn() {
        let down = LocaleSwitcherFocus.next(from: .iceland, by: 1, vertical: true)
        XCTAssertEqual(down, AppLocale.row2[13])
        XCTAssertEqual(down, .ae)
    }

    func testRightFromIndiaGoesToBD() {
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .india, by: 1, vertical: false), .bd)
    }
}
