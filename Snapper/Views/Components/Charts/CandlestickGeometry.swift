import CoreGraphics
import Foundation

/// Pure-math coordinate mapping used by ``CandlestickChartView``'s
/// ``Canvas`` drawing pass. Extracted from the view so the math is
/// unit-testable without spinning up a simulator.
///
/// X-axis is index-based: candles are laid out evenly across the
/// plot rect under the assumption that the backend emits a
/// uniformly-sampled timeframe series with no gaps. (See plan
/// [[plan_2026_05_24_ios_v202_candlestick_primitive_rewrite]].)
///
/// Y-axis is price-based and inverted: SwiftUI's Y grows downward,
/// but a higher price renders higher on screen, so ``pixelY``
/// subtracts the data offset from ``plotMaxY``.
enum CandlestickGeometry {

    /// Pixel center of the candle at ``index`` (zero-based) inside
    /// a plot rect whose horizontal extent is
    /// ``[plotMinX, plotMinX + plotWidth]`` and which carries
    /// ``count`` candles in total.
    ///
    /// Edge candles sit a half-step in from the rect edges so
    /// their bodies don't collide with the Y-axis label gutter.
    static func pixelX(
        index: Int,
        count: Int,
        plotWidth: CGFloat,
        plotMinX: CGFloat
    ) -> CGFloat {
        guard count > 0 else { return plotMinX + plotWidth / 2 }
        let candleWidth = plotWidth / CGFloat(count)
        return plotMinX + candleWidth * (CGFloat(index) + 0.5)
    }

    /// Pixel Y of ``price`` inside a plot rect whose vertical
    /// extent is ``[plotMinY, plotMaxY]`` and whose data domain
    /// is ``domain``.
    ///
    /// Inverted: ``price == domain.lowerBound`` maps to
    /// ``plotMaxY`` (bottom of plot), ``price == domain.upperBound``
    /// maps to ``plotMinY`` (top), and the midpoint maps to the
    /// plot center.
    static func pixelY(
        price: Double,
        domain: NiceAxis,
        plotMinY: CGFloat,
        plotMaxY: CGFloat
    ) -> CGFloat {
        let span = domain.upperBound - domain.lowerBound
        guard span > 0 else { return (plotMinY + plotMaxY) / 2 }
        let plotHeight = plotMaxY - plotMinY
        let offset = (price - domain.lowerBound) / span
        return plotMaxY - plotHeight * CGFloat(offset)
    }

    /// Rectangle for the candle body (the ``[open, close]`` band)
    /// at ``index``. Width is fixed at ``bodyWidth`` (centered on
    /// the candle's ``pixelX``), height spans the open-close range
    /// in Y-pixel space.
    ///
    /// Returns a minimum height of 1pt for doji candles
    /// (``open == close``) so the body is still visible.
    static func candleBodyRect(
        index: Int,
        count: Int,
        open: Double,
        close: Double,
        domain: NiceAxis,
        plotRect: CGRect,
        bodyWidth: CGFloat
    ) -> CGRect {
        let centerX = pixelX(
            index: index,
            count: count,
            plotWidth: plotRect.width,
            plotMinX: plotRect.minX
        )
        let openY = pixelY(
            price: open,
            domain: domain,
            plotMinY: plotRect.minY,
            plotMaxY: plotRect.maxY
        )
        let closeY = pixelY(
            price: close,
            domain: domain,
            plotMinY: plotRect.minY,
            plotMaxY: plotRect.maxY
        )
        let topY = min(openY, closeY)
        let bottomY = max(openY, closeY)
        let height = max(bottomY - topY, 1)
        return CGRect(
            x: centerX - bodyWidth / 2,
            y: topY,
            width: bodyWidth,
            height: height
        )
    }

    /// Endpoints of the candle's wick line (vertical, from
    /// ``low`` to ``high``). Drawn as a stroked ``Path`` in the
    /// view layer.
    static func candleWickEndpoints(
        index: Int,
        count: Int,
        high: Double,
        low: Double,
        domain: NiceAxis,
        plotRect: CGRect
    ) -> (top: CGPoint, bottom: CGPoint) {
        let centerX = pixelX(
            index: index,
            count: count,
            plotWidth: plotRect.width,
            plotMinX: plotRect.minX
        )
        let highY = pixelY(
            price: high,
            domain: domain,
            plotMinY: plotRect.minY,
            plotMaxY: plotRect.maxY
        )
        let lowY = pixelY(
            price: low,
            domain: domain,
            plotMinY: plotRect.minY,
            plotMaxY: plotRect.maxY
        )
        return (
            top: CGPoint(x: centerX, y: highY),
            bottom: CGPoint(x: centerX, y: lowY)
        )
    }
}
