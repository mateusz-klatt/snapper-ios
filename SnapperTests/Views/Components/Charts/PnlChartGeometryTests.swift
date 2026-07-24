import CoreGraphics
import XCTest
@testable import Snapper

/// Pure-math coverage for ``PnlChartGeometry`` — the segment splitting,
/// decimation, and coordinate mapping behind ``PnlLineChartView``.
final class PnlChartGeometryTests: XCTestCase {

    func testSegmentsSplitsOnInteriorNil() {
        let values: [Double?] = [nil, 1, 2, nil, 3]
        XCTAssertEqual(PnlChartGeometry.segments(values), [[1, 2], [4]])
    }

    func testSegmentsWholeSeriesWhenNoNil() {
        let values: [Double?] = [1, 2, 3]
        XCTAssertEqual(PnlChartGeometry.segments(values), [[0, 1, 2]])
    }

    func testSegmentsLeadingAndTrailingNil() {
        XCTAssertEqual(PnlChartGeometry.segments([nil, 1]), [[1]])
        XCTAssertEqual(PnlChartGeometry.segments([1, nil]), [[0]])
    }

    func testSegmentsAllNilIsEmpty() {
        let values: [Double?] = [nil, nil, nil]
        XCTAssertEqual(PnlChartGeometry.segments(values), [])
    }

    func testSegmentsSinglePoint() {
        XCTAssertEqual(PnlChartGeometry.segments([5]), [[0]])
        XCTAssertEqual(PnlChartGeometry.segments([]), [])
    }

    func testDecimationStride() {
        XCTAssertEqual(PnlChartGeometry.decimationStride(count: 0, maxSamples: 2_000), 1)
        XCTAssertEqual(PnlChartGeometry.decimationStride(count: 2_000, maxSamples: 2_000), 1)
        XCTAssertEqual(PnlChartGeometry.decimationStride(count: 2_001, maxSamples: 2_000), 2)
        XCTAssertEqual(PnlChartGeometry.decimationStride(count: 6_000, maxSamples: 2_000), 3)
        XCTAssertEqual(PnlChartGeometry.decimationStride(count: 100, maxSamples: 0), 1)
    }

    func testDecimateRunKeepsEndpoints() {
        XCTAssertEqual(PnlChartGeometry.decimateRun([0, 1, 2, 3, 4, 5], stride: 3), [0, 3, 5],
                       "Terminal index 5 survives even though it is not stride-aligned")
        XCTAssertEqual(PnlChartGeometry.decimateRun([0, 1, 2, 3, 4, 5, 6], stride: 3), [0, 3, 6],
                       "Stride-aligned terminal index is not duplicated")
        XCTAssertEqual(PnlChartGeometry.decimateRun([0, 1, 2], stride: 3), [0, 2],
                       "First and last kept, interior dropped")
        XCTAssertEqual(PnlChartGeometry.decimateRun([0, 1], stride: 3), [0, 1],
                       "Runs of two or fewer are returned unchanged")
        XCTAssertEqual(PnlChartGeometry.decimateRun([0, 1, 2, 3], stride: 1), [0, 1, 2, 3],
                       "Stride 1 keeps every index")
    }

    func testRenderRunsPreservesGapsAndRunEndpoints() {
        let values: [Double?] = [0, 1, 2, 3, 4, 5, nil, 7, 8, 9, 10, 11]
        let runs = PnlChartGeometry.renderRuns(values: values, maxSamples: 8)
        XCTAssertEqual(runs.count, 2, "The interior nil must keep the two runs separate (gap preserved)")
        XCTAssertEqual(runs[0], [0, 2, 4, 5], "First run decimates at stride 2 but keeps terminal index 5")
        XCTAssertEqual(runs[1], [7, 9, 11], "Second run keeps its terminal index 11")
    }

    func testRenderRunsWithoutDecimationPreservesEveryPointAndGap() {
        let values: [Double?] = [1, 2, nil, 4]
        XCTAssertEqual(PnlChartGeometry.renderRuns(values: values, maxSamples: 2_000), [[0, 1], [3]])
    }

    func testRenderRunsAllNilIsEmpty() {
        XCTAssertEqual(PnlChartGeometry.renderRuns(values: [nil, nil], maxSamples: 4), [])
    }

    func testRenderRunsUsesExactPathWithinBudget() {
        let values: [Double?] = [1, 2, nil, 4]
        XCTAssertEqual(PnlChartGeometry.renderRuns(values: values, maxSamples: 2_000), [[0, 1], [3]],
                       "Within budget, the exact run-splitting path is used unchanged")
    }

    func testRenderRunsGlobalBudgetCapsAlternatingDenseSeries() {
        var values = [Double?](repeating: nil, count: 50_000)
        for index in 0..<50_000 where index % 2 == 0 {
            values[index] = Double(index)
        }
        for index in 25_000..<30_000 {
            values[index] = nil
        }
        let runs = PnlChartGeometry.renderRuns(values: values, maxSamples: 2_000)
        let drawn = runs.reduce(0) { $0 + $1.count }
        XCTAssertLessThanOrEqual(drawn, 2_000,
                                 "The global budget caps total drawn samples for a pathological series")
        XCTAssertGreaterThanOrEqual(runs.count, 2,
                                    "A withheld region spanning whole buckets preserves a gap")
        XCTAssertEqual(runs.last?.last, 49_998, "The exact final finite point is always retained")
    }

    func testBucketedRunsKeepsFinalFiniteAndCapsSamples() {
        var values: [Double?] = Array(repeating: 1.0, count: 10)
        values[8] = 5.0
        values[9] = nil
        let runs = PnlChartGeometry.bucketedRuns(values: values, maxSamples: 3)
        let drawn = runs.reduce(0) { $0 + $1.count }
        XCTAssertLessThanOrEqual(drawn, 3)
        XCTAssertEqual(runs.last?.last, 8, "Final finite index (8, with a trailing nil at 9) retained")
    }

    func testBucketedRunsSplitsWhenNullRunStraddlesBuckets() {
        var values = [Double?](repeating: nil, count: 12)
        values[0] = 1.0
        values[7] = 2.0
        values[8] = 3.0
        let runs = PnlChartGeometry.bucketedRuns(values: values, maxSamples: 3)
        XCTAssertEqual(
            runs, [[0], [7, 8]],
            "A null run straddling buckets 0/1 (finite-early 0 to finite-late 7) splits; adjacent 7/8 stay joined"
        )
    }

    func testBucketedRunsSplitsFiniteLateToFiniteEarlyAcrossNullRun() {
        var values = [Double?](repeating: nil, count: 12)
        values[3] = 1.0
        values[8] = 2.0
        let runs = PnlChartGeometry.bucketedRuns(values: values, maxSamples: 3)
        XCTAssertEqual(
            runs, [[3], [8]],
            "Finite-late in bucket 0 (index 3) to finite-early in bucket 2 (index 8) with a null run between splits"
        )
    }

    func testPixelXDistributesUniformly() {
        XCTAssertEqual(PnlChartGeometry.pixelX(index: 0, count: 3, plotMinX: 0, plotWidth: 100), 0, accuracy: 0.0001)
        XCTAssertEqual(PnlChartGeometry.pixelX(index: 1, count: 3, plotMinX: 0, plotWidth: 100), 50, accuracy: 0.0001)
        XCTAssertEqual(PnlChartGeometry.pixelX(index: 2, count: 3, plotMinX: 0, plotWidth: 100), 100, accuracy: 0.0001)
    }

    func testPixelXSinglePointCenters() {
        XCTAssertEqual(PnlChartGeometry.pixelX(index: 0, count: 1, plotMinX: 10, plotWidth: 80), 50, accuracy: 0.0001)
    }

    func testPixelYIsInverted() {
        let domain = NiceAxis(lowerBound: 0, upperBound: 10, step: 2)
        XCTAssertEqual(PnlChartGeometry.pixelY(value: 0, domain: domain, plotMinY: 0, plotMaxY: 100), 100, accuracy: 0.0001)
        XCTAssertEqual(PnlChartGeometry.pixelY(value: 10, domain: domain, plotMinY: 0, plotMaxY: 100), 0, accuracy: 0.0001)
        XCTAssertEqual(PnlChartGeometry.pixelY(value: 5, domain: domain, plotMinY: 0, plotMaxY: 100), 50, accuracy: 0.0001)
    }

    func testPixelYDegenerateDomainCenters() {
        let domain = NiceAxis(lowerBound: 5, upperBound: 5, step: 1)
        XCTAssertEqual(PnlChartGeometry.pixelY(value: 5, domain: domain, plotMinY: 0, plotMaxY: 100), 50, accuracy: 0.0001)
    }
}
