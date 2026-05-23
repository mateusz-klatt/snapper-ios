import XCTest
@testable import Snapper

final class CachedCandleConversionTests: XCTestCase {

    private func makeCached(
        openAtMs: Int = 1_700_000_000_000,
        open: Double = 2000.45,
        high: Double = 2010.0,
        low: Double = 1995.55,
        close: Double = 2005.12,
        volume: Double = 12_345.67
    ) -> CachedCandle {
        return CachedCandle(
            openAtMs: openAtMs,
            timeframe: "1h",
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume
        )
    }

    func testIntegerSecondTimestamp() throws {
        let candle = makeCached(openAtMs: 1_700_000_000_000)
        let result = try XCTUnwrap(candle.toMarketCandle())
        XCTAssertEqual(
            result.openAt.timeIntervalSince1970,
            1_700_000_000.0,
            accuracy: 0.0005
        )
    }

    func testSubSecondPrecisionPreserved() throws {
        let candle = makeCached(openAtMs: 1_700_000_000_123)
        let result = try XCTUnwrap(candle.toMarketCandle())
        XCTAssertEqual(
            result.openAt.timeIntervalSince1970,
            1_700_000_000.123,
            accuracy: 0.0005
        )
    }

    func testTypicalGoldValuesRoundTripToExpectedDecimals() {
        let candle = makeCached(open: 2000.45, high: 2010.0, low: 1995.55, close: 2005.12, volume: 12_345.67)
        let result = candle.toMarketCandle()
        XCTAssertEqual(result?.open, Decimal(string: "2000.45"))
        XCTAssertEqual(result?.high, Decimal(string: "2010.0"))
        XCTAssertEqual(result?.low, Decimal(string: "1995.55"))
        XCTAssertEqual(result?.close, Decimal(string: "2005.12"))
        XCTAssertEqual(result?.volume, Decimal(string: "12345.67"))
    }

    func testForexLikeSmallValuesRoundTrip() {
        let candle = makeCached(open: 1.0834, high: 1.0850, low: 1.0815, close: 1.0842, volume: 5_000_000)
        let result = candle.toMarketCandle()
        XCTAssertEqual(result?.open, Decimal(string: "1.0834"))
        XCTAssertEqual(result?.close, Decimal(string: "1.0842"))
    }

    func testBitcoinLargeValuesRoundTrip() {
        let candle = makeCached(open: 70_123.5, high: 70_500.0, low: 69_800.0, close: 70_200.0, volume: 1_500)
        let result = candle.toMarketCandle()
        XCTAssertEqual(result?.open, Decimal(string: "70123.5"))
        XCTAssertEqual(result?.high, Decimal(string: "70500.0"))
    }

    func testVwapAndTradesAreNil() {
        let result = makeCached().toMarketCandle()
        XCTAssertNil(result?.vwap)
        XCTAssertNil(result?.trades)
    }

    func testNaNInputReturnsNil() {
        let candle = makeCached(open: .nan)
        XCTAssertNil(candle.toMarketCandle())
    }

    func testInfinityInputReturnsNil() {
        let candle = makeCached(high: .infinity)
        XCTAssertNil(candle.toMarketCandle())
    }
}
