import CoreGraphics
import XCTest
@testable import Snapper

/// Test vectors for ``CandlestickGeometry``. Each ``pixelX`` /
/// ``pixelY`` expectation is hand-derived from the formulas
/// stated in the plan
/// [[plan_2026_05_24_ios_v202_candlestick_primitive_rewrite]]
/// §Coordinate system.
final class CandlestickGeometryTests: XCTestCase {

    func testPixelX_singleCandle_centeredInPlot() {
        let x = CandlestickGeometry.pixelX(
            index: 0,
            count: 1,
            plotWidth: 100,
            plotMinX: 0
        )
        XCTAssertEqual(x, 50, accuracy: 0.001)
    }

    func testPixelX_tenCandles_firstAndLast() {
        let first = CandlestickGeometry.pixelX(
            index: 0,
            count: 10,
            plotWidth: 100,
            plotMinX: 0
        )
        XCTAssertEqual(first, 5, accuracy: 0.001)

        let last = CandlestickGeometry.pixelX(
            index: 9,
            count: 10,
            plotWidth: 100,
            plotMinX: 0
        )
        XCTAssertEqual(last, 95, accuracy: 0.001)
    }

    func testPixelX_offsetPlotMinX() {
        let x = CandlestickGeometry.pixelX(
            index: 2,
            count: 5,
            plotWidth: 50,
            plotMinX: 20
        )
        XCTAssertEqual(x, 45, accuracy: 0.001)
    }

    func testPixelX_zeroCount_returnsPlotCenter() {
        let x = CandlestickGeometry.pixelX(
            index: 0,
            count: 0,
            plotWidth: 100,
            plotMinX: 0
        )
        XCTAssertEqual(x, 50, accuracy: 0.001)
    }

    func testPixelY_priceAtLowerBound_atPlotMaxY() {
        let domain = NiceAxis(lowerBound: 100, upperBound: 200, step: 25)
        let y = CandlestickGeometry.pixelY(
            price: 100,
            domain: domain,
            plotMinY: 10,
            plotMaxY: 110
        )
        XCTAssertEqual(y, 110, accuracy: 0.001)
    }

    func testPixelY_priceAtUpperBound_atPlotMinY() {
        let domain = NiceAxis(lowerBound: 100, upperBound: 200, step: 25)
        let y = CandlestickGeometry.pixelY(
            price: 200,
            domain: domain,
            plotMinY: 10,
            plotMaxY: 110
        )
        XCTAssertEqual(y, 10, accuracy: 0.001)
    }

    func testPixelY_priceAtMidpoint_atPlotCenter() {
        let domain = NiceAxis(lowerBound: 100, upperBound: 200, step: 25)
        let y = CandlestickGeometry.pixelY(
            price: 150,
            domain: domain,
            plotMinY: 10,
            plotMaxY: 110
        )
        XCTAssertEqual(y, 60, accuracy: 0.5)
    }

    func testPixelY_zeroSpanDomain_returnsPlotCenter() {
        let domain = NiceAxis(lowerBound: 100, upperBound: 100, step: 1)
        let y = CandlestickGeometry.pixelY(
            price: 100,
            domain: domain,
            plotMinY: 10,
            plotMaxY: 110
        )
        XCTAssertEqual(y, 60, accuracy: 0.001)
    }

    func testCandleBodyRect_risingCandle_topAtClose_bottomAtOpen() {
        let domain = NiceAxis(lowerBound: 100, upperBound: 200, step: 25)
        let plot = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect = CandlestickGeometry.candleBodyRect(
            index: 0,
            count: 1,
            open: 120,
            close: 180,
            domain: domain,
            plotRect: plot,
            bodyWidth: 5
        )
        XCTAssertEqual(rect.origin.x, 47.5, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, 5, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 20, accuracy: 0.001)
        XCTAssertEqual(rect.maxY, 80, accuracy: 0.001)
    }

    func testCandleBodyRect_dojiCandle_minimumHeightOnePoint() {
        let domain = NiceAxis(lowerBound: 100, upperBound: 200, step: 25)
        let plot = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect = CandlestickGeometry.candleBodyRect(
            index: 0,
            count: 1,
            open: 150,
            close: 150,
            domain: domain,
            plotRect: plot,
            bodyWidth: 5
        )
        XCTAssertEqual(rect.size.height, 1, accuracy: 0.001)
    }

    func testCandleWickEndpoints_topAtHigh_bottomAtLow() {
        let domain = NiceAxis(lowerBound: 100, upperBound: 200, step: 25)
        let plot = CGRect(x: 0, y: 0, width: 100, height: 100)
        let (top, bottom) = CandlestickGeometry.candleWickEndpoints(
            index: 0,
            count: 1,
            high: 200,
            low: 100,
            domain: domain,
            plotRect: plot
        )
        XCTAssertEqual(top.x, 50, accuracy: 0.001)
        XCTAssertEqual(top.y, 0, accuracy: 0.001)
        XCTAssertEqual(bottom.x, 50, accuracy: 0.001)
        XCTAssertEqual(bottom.y, 100, accuracy: 0.001)
    }
}
