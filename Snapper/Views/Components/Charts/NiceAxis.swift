import Foundation

/// "Nice" round-number axis layout, computed via the Heckbert 1990
/// algorithm (Graphics Gems I, "Nice Numbers for Graph Labels").
///
/// Returned by ``niceAxis(min:max:tickCount:)`` for use as the Y-axis
/// domain of ``CandlestickChartView``. The pair
/// ``[lowerBound, upperBound]`` always contains the requested
/// ``[min, max]`` and is expanded so each tick lands on a round
/// multiple of ``step`` — e.g. ``76510, 76520, 76530, 76540, 76550``
/// rather than the arbitrary endpoints ``76519.34, ..., 76548.70``.
///
/// We own this math because v2.0.1 hit a Swift Charts rendering bug
/// in iOS 26.2 (the framework silently ignores ``.foregroundStyle``
/// on ``RectangleMark`` / ``RuleMark`` for ``.red`` / ``.green``),
/// forcing the chart off ``Chart`` + ``RectangleMark`` and onto raw
/// SwiftUI ``Canvas`` primitives where we draw axes ourselves.
struct NiceAxis: Equatable {
    let lowerBound: Double
    let upperBound: Double
    let step: Double
}

/// Round ``x`` to the closest "nice" value (``1``, ``2``, ``5`` or
/// ``10`` times a power of ten). With ``round: true`` the closest
/// nice value is chosen; with ``round: false`` the smallest nice
/// value ``>= x`` is chosen.
///
/// The bucket boundaries (``< 1.5`` / ``< 3`` / ``< 7`` when
/// rounding, ``<= 1`` / ``<= 2`` / ``<= 5`` otherwise) reproduce
/// Heckbert's reference table exactly so unit-test vectors derived
/// by hand remain stable across Swift versions.
private func niceNumber(_ x: Double, round: Bool) -> Double {
    let exp = floor(log10(x))
    let f = x / pow(10, exp)
    let nf: Double
    if round {
        if f < 1.5 {
            nf = 1
        } else if f < 3 {
            nf = 2
        } else if f < 7 {
            nf = 5
        } else {
            nf = 10
        }
    } else {
        if f <= 1 {
            nf = 1
        } else if f <= 2 {
            nf = 2
        } else if f <= 5 {
            nf = 5
        } else {
            nf = 10
        }
    }
    return nf * pow(10, exp)
}

/// Compute a Y-axis layout that contains ``[min, max]`` and lands
/// on round tick marks. The returned ``NiceAxis`` may extend
/// slightly beyond ``[min, max]`` so the chart can label axis
/// ticks at ``lowerBound, lowerBound + step, …, upperBound``.
///
/// ``tickCount`` is the *desired* number of ticks; the actual
/// number lies in ``[tickCount - 1, tickCount + 1]`` depending on
/// the data range, matching the Swift Charts heuristic for
/// ``.automatic(desiredCount:)``.
///
/// Falls back to a unit-span domain CENTERED on ``min`` when
/// ``max <= min`` (flat market — every candle has identical
/// OHLC). The fallback uses ``(min - 0.5, min + 0.5, 1)`` so the
/// degenerate value lands at the plot's vertical midpoint rather
/// than against the bottom edge where ``CandlestickGeometry``'s
/// clip-to-plot pipeline would render it invisible.
func niceAxis(min: Double, max: Double, tickCount: Int) -> NiceAxis {
    guard max > min else {
        return NiceAxis(
            lowerBound: min - 0.5,
            upperBound: min + 0.5,
            step: 1
        )
    }
    let range = niceNumber(max - min, round: false)
    let step = niceNumber(range / Double(tickCount - 1), round: true)
    return NiceAxis(
        lowerBound: floor(min / step) * step,
        upperBound: ceil(max / step) * step,
        step: step
    )
}
