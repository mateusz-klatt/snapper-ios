import XCTest
@testable import Snapper

@MainActor
final class CacheWarmingBannerLogicTests: XCTestCase {

    func testShouldRenderNilStateReturnsFalse() {
        XCTAssertFalse(CacheWarmingBannerLogic.shouldRender(cacheState: nil))
    }

    func testShouldRenderWarmReturnsFalse() {
        let state = CacheStateSnapshot(isWarm: true, sampleCount: 100, source: "cache")
        XCTAssertFalse(CacheWarmingBannerLogic.shouldRender(cacheState: state))
    }

    func testShouldRenderColdReturnsTrue() {
        let state = CacheStateSnapshot(isWarm: false, sampleCount: 50, source: "derived")
        XCTAssertTrue(CacheWarmingBannerLogic.shouldRender(cacheState: state))
    }

    func testMessageSourceCacheOmitsSuffixAndTrimsTrailingSpace() {
        let state = CacheStateSnapshot(isWarm: false, sampleCount: 50, source: "cache")
        let result = CacheWarmingBannerLogic.message(cacheState: state, expected: 100, lang: .en)
        XCTAssertEqual(result, "Cache warming up: 50 / 100 candles available")
        XCTAssertFalse(
            result.hasSuffix(" "),
            "Trailing whitespace from the empty %3$@ slot must be trimmed."
        )
    }

    func testMessageSourceDerivedIncludesLocalizedSuffix() {
        let state = CacheStateSnapshot(isWarm: false, sampleCount: 50, source: "derived")
        let result = CacheWarmingBannerLogic.message(cacheState: state, expected: 100, lang: .en)
        XCTAssertTrue(
            result.contains("(derived from 1m)"),
            "Derived source must surface the localized parenthetical."
        )
    }

    func testMessageSourceDbIncludesLocalizedSuffix() {
        let state = CacheStateSnapshot(isWarm: false, sampleCount: 50, source: "db")
        let result = CacheWarmingBannerLogic.message(cacheState: state, expected: 100, lang: .en)
        XCTAssertTrue(
            result.contains("(from DB)"),
            "DB source must surface the localized parenthetical."
        )
    }

    func testMessagePLDiffersFromEN() {
        let state = CacheStateSnapshot(isWarm: false, sampleCount: 50, source: "derived")
        let en = CacheWarmingBannerLogic.message(cacheState: state, expected: 100, lang: .en)
        let pl = CacheWarmingBannerLogic.message(cacheState: state, expected: 100, lang: .pl)
        XCTAssertNotEqual(pl, en, "PL message must differ from EN so the localization path is exercised.")
        XCTAssertTrue(pl.contains("50"), "PL must substitute sampleCount.")
        XCTAssertTrue(pl.contains("100"), "PL must substitute expected.")
    }

    func testRawSourceCaptionReturnsRawToken() {
        let state = CacheStateSnapshot(isWarm: false, sampleCount: 50, source: "derived")
        XCTAssertEqual(
            CacheWarmingBannerLogic.rawSourceCaption(cacheState: state),
            "derived",
            "Raw caption must NOT use the localized parenthetical — it's the wire token for operator debug."
        )
    }

    func testLocalizedSourceSuffixCacheReturnsEmpty() {
        XCTAssertEqual(
            CacheWarmingBannerLogic.localizedSourceSuffix(source: "cache", lang: .en),
            "",
            "EN catalog defines source 'cache' as the empty string."
        )
    }

    func testLocalizedSourceSuffixUnknownReturnsEmpty() {
        XCTAssertEqual(
            CacheWarmingBannerLogic.localizedSourceSuffix(source: "magic-future-source", lang: .en),
            "",
            "Unknown source → catalog miss → fall through to empty suffix (no parenthetical clutter)."
        )
    }
}
