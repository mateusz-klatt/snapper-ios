import XCTest
@testable import Snapper

/// Test vectors for ``niceAxis(min:max:tickCount:)``. Each
/// expected value is hand-derived by running the Heckbert
/// algorithm on paper — change only if the algorithm changes.
/// See [[plan_2026_05_24_ios_v202_candlestick_primitive_rewrite]]
/// §Tests for the derivation of each vector.
final class NiceAxisTests: XCTestCase {

    func testSimpleRange_0_to_100_5ticks() {
        let result = niceAxis(min: 0, max: 100, tickCount: 5)
        XCTAssertEqual(result.lowerBound, 0)
        XCTAssertEqual(result.upperBound, 100)
        XCTAssertEqual(result.step, 20)
    }

    func testCryptoRange_76519p34_to_76548p70_5ticks() {
        let result = niceAxis(min: 76519.34, max: 76548.70, tickCount: 5)
        XCTAssertEqual(result.lowerBound, 76510)
        XCTAssertEqual(result.upperBound, 76550)
        XCTAssertEqual(result.step, 10)
    }

    func testNegativeRange_neg100_to_100_5ticks() {
        let result = niceAxis(min: -100, max: 100, tickCount: 5)
        XCTAssertEqual(result.lowerBound, -100)
        XCTAssertEqual(result.upperBound, 100)
        XCTAssertEqual(result.step, 50)
    }

    func testZeroRange_minEqualsMax_fallback() {
        let result = niceAxis(min: 42, max: 42, tickCount: 5)
        XCTAssertEqual(result.lowerBound, 41.5)
        XCTAssertEqual(result.upperBound, 42.5)
        XCTAssertEqual(result.step, 1)
    }

    func testInvertedRange_minGreaterThanMax_fallback() {
        let result = niceAxis(min: 100, max: 0, tickCount: 5)
        XCTAssertEqual(result.lowerBound, 99.5)
        XCTAssertEqual(result.upperBound, 100.5)
        XCTAssertEqual(result.step, 1)
    }

    func testZeroRange_fallbackCentersValueAtMidpoint() {
        let result = niceAxis(min: 76500, max: 76500, tickCount: 5)
        XCTAssertEqual(result.lowerBound, 76499.5)
        XCTAssertEqual(result.upperBound, 76500.5)
        XCTAssertEqual((result.lowerBound + result.upperBound) / 2, 76500, accuracy: 0.001)
    }

    func testTickCount_belowTwo_isClampedToTwo() {
        let resultOne = niceAxis(min: 0, max: 100, tickCount: 1)
        let resultZero = niceAxis(min: 0, max: 100, tickCount: 0)
        let resultNegative = niceAxis(min: 0, max: 100, tickCount: -5)
        let baseline = niceAxis(min: 0, max: 100, tickCount: 2)
        XCTAssertEqual(resultOne, baseline)
        XCTAssertEqual(resultZero, baseline)
        XCTAssertEqual(resultNegative, baseline)
        XCTAssertFalse(resultOne.step.isNaN)
        XCTAssertFalse(resultOne.step.isInfinite)
    }

    func testLargeRange_millions_5ticks_stepIsRound() {
        let result = niceAxis(min: 1_234_567, max: 1_345_678, tickCount: 5)
        let allowedSteps: Set<Double> = [10_000, 20_000, 25_000, 50_000]
        XCTAssertTrue(
            allowedSteps.contains(result.step),
            "step \(result.step) not in \(allowedSteps)"
        )
        let stepRemainderLower = result.lowerBound.truncatingRemainder(dividingBy: result.step)
        let stepRemainderUpper = result.upperBound.truncatingRemainder(dividingBy: result.step)
        XCTAssertEqual(stepRemainderLower, 0, accuracy: 1e-6)
        XCTAssertEqual(stepRemainderUpper, 0, accuracy: 1e-6)
        XCTAssertLessThanOrEqual(result.lowerBound, 1_234_567)
        XCTAssertGreaterThanOrEqual(result.upperBound, 1_345_678)
    }

    func testMicroRange_0p001_to_0p002_5ticks_noUnderflow() {
        let result = niceAxis(min: 0.001, max: 0.002, tickCount: 5)
        let allowedSteps: Set<Double> = [0.0001, 0.0002, 0.00025]
        XCTAssertTrue(
            allowedSteps.contains(where: { abs($0 - result.step) < 1e-9 }),
            "step \(result.step) not in \(allowedSteps)"
        )
        XCTAssertFalse(result.step.isNaN)
        XCTAssertFalse(result.lowerBound.isNaN)
        XCTAssertFalse(result.upperBound.isNaN)
        XCTAssertLessThanOrEqual(result.lowerBound, 0.001)
        XCTAssertGreaterThanOrEqual(result.upperBound, 0.002)
    }

    func testStepDivides_lowerAndUpper_remainderZero() {
        for (lo, hi) in [(10.0, 90.0), (0.5, 2.5), (15.0, 47.0)] {
            let result = niceAxis(min: lo, max: hi, tickCount: 5)
            let loRem = result.lowerBound.truncatingRemainder(dividingBy: result.step)
            let hiRem = result.upperBound.truncatingRemainder(dividingBy: result.step)
            XCTAssertEqual(loRem, 0, accuracy: 1e-9, "lower \(result.lowerBound) not multiple of step \(result.step)")
            XCTAssertEqual(hiRem, 0, accuracy: 1e-9, "upper \(result.upperBound) not multiple of step \(result.step)")
        }
    }
}
