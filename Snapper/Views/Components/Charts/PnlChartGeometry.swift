import CoreGraphics
import Foundation

/// Pure-math geometry for the hand-rolled P&L line chart
/// (``PnlLineChartView``). Extracted from the view so the segment
/// splitting, decimation, and coordinate mapping are unit-testable
/// without a simulator.
///
/// The chart draws three cumulative/stock P&L series (net, realized,
/// unrealized) whose per-point values are ``Double?``. A ``nil`` value
/// is an honestly withheld point and MUST render as a visual GAP.
///
/// Ordering is deliberate and load-bearing: each series is split into
/// contiguous non-nil runs FIRST (``segments(_:)``) and decimation is
/// applied only WITHIN each run (``decimateRun(_:stride:)``), always
/// retaining the run's first AND last index. A run is never joined to
/// its neighbor across a gap, so a withheld interval can never be
/// misrendered as a continuous line and the terminal point of a run is
/// never dropped by a non-aligned stride.
///
/// Global budget: ``renderRuns(values:maxSamples:)`` uses that exact
/// run-splitting path whenever its output already fits within
/// ``maxSamples`` samples. A pathological series (e.g. value/nil
/// alternating) would otherwise produce tens of thousands of singleton
/// runs despite the budget, so when the exact output would exceed it
/// the geometry falls back to fixed-width bucketing: the point range is
/// divided into ``maxSamples`` buckets, a bucket with at least one
/// finite value renders exactly one sample (the last finite index in
/// the bucket) and the exact final finite point is always retained,
/// while an all-nil bucket renders as a gap. At that fallback
/// resolution, sub-bucket withheld gaps visually close — the
/// incompleteness summary, not the line, remains the authoritative
/// signal for withholding.
enum PnlChartGeometry {

    /// Default decimation ceiling — the drawn sample count stays at or
    /// below this after ``decimationStride(count:maxSamples:)``.
    static let defaultMaxSamples: Int = 2_000

    /// Contiguous runs of indices whose value is non-nil. A ``nil``
    /// value ends the current run; the next non-nil value starts a new
    /// one. Leading, trailing, and interior nils all break runs. An
    /// all-nil input yields ``[]``; a single non-nil value yields one
    /// run of length 1 (rendered as a dot).
    static func segments(_ values: [Double?]) -> [[Int]] {
        var runs: [[Int]] = []
        var current: [Int] = []
        for (index, value) in values.enumerated() {
            if value == nil {
                if !current.isEmpty {
                    runs.append(current)
                    current = []
                }
            } else {
                current.append(index)
            }
        }
        if !current.isEmpty {
            runs.append(current)
        }
        return runs
    }

    /// Decimation stride: ``1`` when ``count <= maxSamples`` (draw
    /// every point), otherwise ``ceil(count / maxSamples)`` so the
    /// retained sample count stays near ``maxSamples``. Guards against
    /// non-positive inputs by returning ``1``.
    static func decimationStride(count: Int, maxSamples: Int) -> Int {
        guard count > maxSamples, maxSamples > 0 else { return 1 }
        return Int((Double(count) / Double(maxSamples)).rounded(.up))
    }

    /// Decimate ONE run (a list of original point indices), keeping
    /// every ``stride``-th index and ALWAYS the run's first and last
    /// index. A stride ``<= 1`` or a run of ``<= 2`` points is returned
    /// unchanged. Endpoint preservation guarantees the run's terminal
    /// value survives regardless of stride alignment.
    static func decimateRun(_ run: [Int], stride: Int) -> [Int] {
        guard stride > 1, run.count > 2 else { return run }
        var kept: [Int] = []
        var position = 0
        while position < run.count {
            kept.append(run[position])
            position += stride
        }
        if let last = run.last, kept.last != last {
            kept.append(last)
        }
        return kept
    }

    /// Render-ready runs for a series. Preferred (exact) path: split
    /// into non-nil runs and decimate within each run at a stride
    /// derived from the TOTAL point count, preserving every gap and each
    /// run's endpoints. That path is used whenever its total sample
    /// count already fits within ``maxSamples``.
    ///
    /// Fallback (global budget): when the exact output would exceed
    /// ``maxSamples`` — e.g. an alternating value/nil series whose
    /// singleton runs defeat per-run decimation — the geometry buckets
    /// the point range into ``maxSamples`` fixed-width buckets via
    /// ``bucketedRuns(values:maxSamples:)``, guaranteeing at most
    /// ``maxSamples`` drawn samples. Sub-bucket withheld gaps close at
    /// that resolution; bucket-wide withheld regions still render as
    /// gaps.
    static func renderRuns(values: [Double?], maxSamples: Int) -> [[Int]] {
        let stride = decimationStride(count: values.count, maxSamples: maxSamples)
        let exact = segments(values).map { decimateRun($0, stride: stride) }
        let drawn = exact.reduce(0) { $0 + $1.count }
        if drawn <= maxSamples {
            return exact
        }
        return bucketedRuns(values: values, maxSamples: maxSamples)
    }

    /// Fixed-width bucketing fallback that enforces a hard global sample
    /// budget. The index range ``[0, count)`` is partitioned into
    /// ``maxSamples`` contiguous buckets; a bucket containing at least
    /// one finite value contributes exactly one sample (its LAST finite
    /// index, a deterministic pick), an all-nil bucket contributes none
    /// and breaks the current run. The exact final finite index of the
    /// whole series is always retained. Consecutive sampled buckets form
    /// one polyline; an all-nil bucket between them preserves the gap.
    static func bucketedRuns(values: [Double?], maxSamples: Int) -> [[Int]] {
        let count = values.count
        guard count > 0, maxSamples > 0 else { return [] }
        var finalFinite: Int?
        var scan = count - 1
        while scan >= 0 {
            if values[scan] != nil {
                finalFinite = scan
                break
            }
            scan -= 1
        }
        guard let finalFinite else { return [] }

        var runs: [[Int]] = []
        var current: [Int] = []
        for bucket in 0..<maxSamples {
            let start = bucket * count / maxSamples
            let end = (bucket + 1) * count / maxSamples
            guard start < end else { continue }
            var picked: Int?
            var index = end - 1
            while index >= start {
                if values[index] != nil {
                    picked = index
                    break
                }
                index -= 1
            }
            if let picked {
                if let previous = current.last,
                   intervalContainsNull(values, after: previous, before: picked) {
                    runs.append(current)
                    current = [picked]
                } else {
                    current.append(picked)
                }
            } else if !current.isEmpty {
                runs.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            runs.append(current)
        }
        if runs.isEmpty {
            return [[finalFinite]]
        }
        if runs[runs.count - 1].last != finalFinite {
            runs[runs.count - 1].append(finalFinite)
        }
        return runs
    }

    /// ``true`` when any value strictly between ``start`` and ``end``
    /// (exclusive) is ``nil``. Used to prevent the bucketing fallback
    /// from joining two consecutive bucket samples with a line when a
    /// withheld run sits between them — even though both buckets are
    /// non-empty, the intervening gap must stay a gap.
    private static func intervalContainsNull(_ values: [Double?], after start: Int, before end: Int) -> Bool {
        guard start + 1 < end else { return false }
        var index = start + 1
        while index < end {
            if values[index] == nil {
                return true
            }
            index += 1
        }
        return false
    }

    /// Pixel X for the point at ``index`` (of ``count`` total),
    /// distributed uniformly across ``[plotMinX, plotMinX +
    /// plotWidth]``. Using the ORIGINAL index (not the decimated
    /// position) keeps all three series time-aligned. A single point
    /// centers horizontally.
    static func pixelX(
        index: Int,
        count: Int,
        plotMinX: CGFloat,
        plotWidth: CGFloat
    ) -> CGFloat {
        guard count > 1 else { return plotMinX + plotWidth / 2 }
        let fraction = CGFloat(index) / CGFloat(count - 1)
        return plotMinX + plotWidth * fraction
    }

    /// Pixel Y of ``value`` inside a plot rect whose vertical extent is
    /// ``[plotMinY, plotMaxY]`` and whose data domain is ``domain``.
    /// Inverted so ``domain.lowerBound`` maps to ``plotMaxY`` (bottom).
    /// Reuses the same mapping as ``CandlestickGeometry/pixelY``.
    static func pixelY(
        value: Double,
        domain: NiceAxis,
        plotMinY: CGFloat,
        plotMaxY: CGFloat
    ) -> CGFloat {
        let span = domain.upperBound - domain.lowerBound
        guard span > 0 else { return (plotMinY + plotMaxY) / 2 }
        let plotHeight = plotMaxY - plotMinY
        let offset = (value - domain.lowerBound) / span
        return plotMaxY - plotHeight * CGFloat(offset)
    }
}
