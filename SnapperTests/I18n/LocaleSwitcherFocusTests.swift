import XCTest
@testable import Snapper

/// Pure-function tests for ``LocaleSwitcherFocus`` — the grid
/// walker that powers iPad keyboard navigation in
/// ``LocaleSwitcher``.
///
/// Grid orientation: 15 rows × 3 columns. Column 0 is the
/// original ``row1`` (Western Europe + Americas), column 1 is
/// ``row2`` (Asia + Middle East), column 2 is ``row3`` (CEE +
/// Balkans + Caucasus). Vertical movement steps through the
/// regional block; horizontal movement crosses regions at the
/// same depth in each block.
final class LocaleSwitcherFocusTests: XCTestCase {

    func testGridDimensionsAre15x3() {
        XCTAssertEqual(LocaleSwitcherFocus.rowCount, 15)
        XCTAssertEqual(LocaleSwitcherFocus.columnCount, 3)
        XCTAssertEqual(LocaleSwitcherFocus.rows.count, 15)
        for row in LocaleSwitcherFocus.rows {
            XCTAssertEqual(row.count, 3)
        }
    }

    func testEvery45CodeAppearsExactlyOnce() {
        let flat = LocaleSwitcherFocus.rows.flatMap { $0 }
        XCTAssertEqual(flat.count, 45)
        XCTAssertEqual(Set(flat).count, 45)
    }

    func testColumnsMirrorOriginalRowsTopDown() {
        for r in 0..<15 {
            XCTAssertEqual(LocaleSwitcherFocus.rows[r][0], AppLocale.row1[r])
            XCTAssertEqual(LocaleSwitcherFocus.rows[r][1], AppLocale.row2[r])
            XCTAssertEqual(LocaleSwitcherFocus.rows[r][2], AppLocale.row3[r])
        }
    }

    func testPositionForTopLeftIsZeroZero() {
        let pos = LocaleSwitcherFocus.position(of: .ie)
        XCTAssertEqual(pos?.row, 0)
        XCTAssertEqual(pos?.col, 0)
    }

    func testPositionForTopRightIsZeroTwo() {
        let pos = LocaleSwitcherFocus.position(of: .cz)
        XCTAssertEqual(pos?.row, 0)
        XCTAssertEqual(pos?.col, 2)
    }

    func testPositionForBottomLeftIsFourteenZero() {
        let pos = LocaleSwitcherFocus.position(of: .gr)
        XCTAssertEqual(pos?.row, 14)
        XCTAssertEqual(pos?.col, 0)
    }

    func testPositionForBottomRightIsFourteenTwo() {
        let pos = LocaleSwitcherFocus.position(of: .am)
        XCTAssertEqual(pos?.row, 14)
        XCTAssertEqual(pos?.col, 2)
    }

    func testPositionForIcelandKeywordCase() {
        let pos = LocaleSwitcherFocus.position(of: .iceland)
        XCTAssertEqual(pos?.row, 13)
        XCTAssertEqual(pos?.col, 0)
    }

    func testPositionForIndiaKeywordCase() {
        let pos = LocaleSwitcherFocus.position(of: .india)
        XCTAssertEqual(pos?.row, 10)
        XCTAssertEqual(pos?.col, 1)
    }

    func testRightFromColumnZeroMovesToColumnOneSameRow() {
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .ie, by: 1, vertical: false), .cn)
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .us, by: 1, vertical: false), .hk)
    }

    func testRightFromColumnOneMovesToColumnTwoSameRow() {
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .cn, by: 1, vertical: false), .cz)
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .india, by: 1, vertical: false), .ba)
    }

    func testRightFromColumnTwoIsNilNotWrap() {
        XCTAssertNil(LocaleSwitcherFocus.next(from: .cz, by: 1, vertical: false))
        XCTAssertNil(LocaleSwitcherFocus.next(from: .am, by: 1, vertical: false))
    }

    func testLeftFromColumnZeroIsNilNotWrap() {
        XCTAssertNil(LocaleSwitcherFocus.next(from: .ie, by: -1, vertical: false))
        XCTAssertNil(LocaleSwitcherFocus.next(from: .gr, by: -1, vertical: false))
    }

    func testDownFromRowZeroMovesToRowOneSameColumn() {
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .ie, by: 1, vertical: true), .us)
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .cn, by: 1, vertical: true), .hk)
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .cz, by: 1, vertical: true), .sk)
    }

    func testDownFromBottomRowIsNilNotWrap() {
        XCTAssertNil(LocaleSwitcherFocus.next(from: .gr, by: 1, vertical: true))
        XCTAssertNil(LocaleSwitcherFocus.next(from: .il, by: 1, vertical: true))
        XCTAssertNil(LocaleSwitcherFocus.next(from: .am, by: 1, vertical: true))
    }

    func testUpFromRowZeroIsNilNotWrap() {
        XCTAssertNil(LocaleSwitcherFocus.next(from: .ie, by: -1, vertical: true))
        XCTAssertNil(LocaleSwitcherFocus.next(from: .cn, by: -1, vertical: true))
        XCTAssertNil(LocaleSwitcherFocus.next(from: .cz, by: -1, vertical: true))
    }

    func testUpFromMidRowMovesToRowAboveSameColumn() {
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .pl, by: -1, vertical: true), .us)
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .jp, by: -1, vertical: true), .hk)
        XCTAssertEqual(LocaleSwitcherFocus.next(from: .hu, by: -1, vertical: true), .sk)
    }
}
