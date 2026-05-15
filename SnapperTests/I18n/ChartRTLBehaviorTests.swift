import SwiftUI
import XCTest
@testable import Snapper

/// Covers ``ChartRTLBehavior`` — chart axis-orientation helper.
final class ChartRTLBehaviorTests: XCTestCase {

    func testIsRTLFalseForLTRLocaleAndLTRLayout() {
        XCTAssertFalse(ChartRTLBehavior.isRTL(locale: .ie, environmentLayout: .leftToRight))
    }

    func testIsRTLTrueForRTLLocaleAndLTRLayout() {
        XCTAssertTrue(ChartRTLBehavior.isRTL(locale: .ae, environmentLayout: .leftToRight))
        XCTAssertTrue(ChartRTLBehavior.isRTL(locale: .il, environmentLayout: .leftToRight))
        XCTAssertTrue(ChartRTLBehavior.isRTL(locale: .ir, environmentLayout: .leftToRight))
    }

    func testIsRTLTrueForLTRLocaleAndRTLLayout() {
        XCTAssertTrue(ChartRTLBehavior.isRTL(locale: .ie, environmentLayout: .rightToLeft))
    }

    func testIsRTLTrueForRTLLocaleAndRTLLayout() {
        XCTAssertTrue(ChartRTLBehavior.isRTL(locale: .ae, environmentLayout: .rightToLeft))
    }

    func testYAxisEdgeIsTrailingForLTR() {
        XCTAssertEqual(ChartRTLBehavior.yAxisEdge(locale: .ie, environmentLayout: .leftToRight), .trailing)
    }

    func testYAxisEdgeIsLeadingForRTL() {
        XCTAssertEqual(ChartRTLBehavior.yAxisEdge(locale: .ae, environmentLayout: .leftToRight), .leading)
        XCTAssertEqual(ChartRTLBehavior.yAxisEdge(locale: .ie, environmentLayout: .rightToLeft), .leading)
    }
}
