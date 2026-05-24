import XCTest
@testable import Snapper

/// Locks the per-timeframe banner probe limits + the hourly
/// metrics window. Drift between either value and the corresponding
/// ``MarketDataViewModel`` request would re-introduce the
/// "banner says X / Y but server was asked for Z" mismatch the
/// refactor fixed.
///
/// Values follow the backend's 100-bar 1m cache deque cap minus
/// worst-case alignment loss (``bucket-1`` 1m bars at the start)
/// for derived frames; long DB-backed frames stay at a 25-bar
/// hourly horizon. The math is documented inside
/// ``MarketCacheLimits.bannerProbeLimit(for:)`` and tested here so
/// a future contributor who tweaks the constants without reading
/// the rationale fails CI.
final class MarketCacheLimitsTests: XCTestCase {

    func testOneMinuteIs100() {
        XCTAssertEqual(MarketCacheLimits.bannerProbeLimit(for: .oneMinute), 100)
    }

    func testFiveMinutesIs19WorstCaseAlignment() {
        XCTAssertEqual(MarketCacheLimits.bannerProbeLimit(for: .fiveMinutes), 19)
    }

    func testFifteenMinutesIs5WorstCaseAlignment() {
        XCTAssertEqual(MarketCacheLimits.bannerProbeLimit(for: .fifteenMinutes), 5)
    }

    func testOneHourIs25HourlyHorizon() {
        XCTAssertEqual(MarketCacheLimits.bannerProbeLimit(for: .oneHour), 25)
    }

    func testFourHoursIs25HourlyHorizon() {
        XCTAssertEqual(MarketCacheLimits.bannerProbeLimit(for: .fourHours), 25)
    }

    func testOneDayIs25HourlyHorizon() {
        XCTAssertEqual(MarketCacheLimits.bannerProbeLimit(for: .oneDay), 25)
    }

    func testMetricsHourlyLimitIs25() {
        XCTAssertEqual(MarketCacheLimits.metricsHourlyLimit, 25)
    }

    func testBannerProbeLimitCoversEveryTimeframeCase() {
        for tf in MarketTimeframe.allCases {
            let limit = MarketCacheLimits.bannerProbeLimit(for: tf)
            XCTAssertGreaterThan(
                limit,
                0,
                "bannerProbeLimit must return a positive integer for \(tf.rawValue)"
            )
        }
    }
}
