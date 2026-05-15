import XCTest
@testable import Snapper

/// Covers ``LocaleStrings.localizedPlural(_:count:in:)`` — the
/// bundle-backed plural lookup. Exercises the fallback path (key
/// returned when no plural variation is found) and the live
/// ``home.heartbeatAge.seconds`` integration used by
/// ``HomeView.connectionText(at:)``.
///
/// The five other plural keys originally seeded during Phase H
/// (``home.openPositions.count``, ``home.recentOrders.count``,
/// ``alerts.empty.count.count``, ``orders.empty.totalCount.count``,
/// ``notifications.prefs.mutedDuration.count``,
/// ``positions.row.lots.count``) were removed in the post-Phase-H
/// cleanup once it became clear no UI consumed them. If a future
/// summary card needs a plural-aware label, re-add the key with all
/// CLDR categories required for the 44 fully-translated languages.
final class LocaleStringsPluralTests: XCTestCase {

    func testMissingKeyReturnsKey() {
        let result = LocaleStrings.localizedPlural(
            "nonexistent.plural.key",
            count: 5,
            in: .en
        )
        XCTAssertEqual(result, "nonexistent.plural.key")
    }

    func testMissingKeyReturnsKeyForPolish() {
        let result = LocaleStrings.localizedPlural(
            "another.missing.key",
            count: 12,
            in: .pl
        )
        XCTAssertEqual(result, "another.missing.key")
    }

    func testZeroCountStillReturnsKeyOnMiss() {
        let result = LocaleStrings.localizedPlural(
            "yet.another.missing",
            count: 0,
            in: .en
        )
        XCTAssertEqual(result, "yet.another.missing")
    }

    func testNegativeCountStillReturnsKeyOnMiss() {
        let result = LocaleStrings.localizedPlural(
            "negative.count.miss",
            count: -1,
            in: .pl
        )
        XCTAssertEqual(result, "negative.count.miss")
    }

    /// ``home.heartbeatAge.seconds`` is wired live in
    /// ``HomeView.connectionText(at:)``. Guard the compiled
    /// ``.xcstrings`` plural path so a future catalog edit that drops
    /// the EN ``other`` or PL ``many`` category surfaces here instead
    /// of silently producing the wrong UI string.
    func testHeartbeatPluralEnglishOther() {
        let result = LocaleStrings.localizedPlural(
            "home.heartbeatAge.seconds",
            count: 5,
            in: .en
        )
        XCTAssertNotEqual(result, "home.heartbeatAge.seconds")
        XCTAssertTrue(result.contains("5"), "EN plural value should contain the count: \(result)")
    }

    func testHeartbeatPluralPolishMany() {
        let result = LocaleStrings.localizedPlural(
            "home.heartbeatAge.seconds",
            count: 5,
            in: .pl
        )
        XCTAssertNotEqual(result, "home.heartbeatAge.seconds")
        XCTAssertTrue(result.contains("5"), "PL plural value should contain the count: \(result)")
    }
}
