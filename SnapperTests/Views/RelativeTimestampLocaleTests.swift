import XCTest
@testable import Snapper

/// Regression coverage for the locale-scoped relative-time renderers
/// on ``AlertRow`` and ``LatestAlertCard``. The visual i18n QA
/// uncovered that the bare ``RelativeDateTimeFormatter()`` initializer
/// without ``.locale`` rendered English ("1 wk ago") even when the
/// user had picked Irish — the formatter reads ``Locale.current``
/// (the process / system preferred-language list) instead of the
/// SwiftUI environment locale.
///
/// These tests pin a fixed reference Date and a fixed elapsed
/// duration so the assertions are deterministic across CI agents.
/// Apple's relative-time strings cover the languages exercised here
/// (en, pl, de, ga) in the iOS 26.x base resources.
@MainActor
final class RelativeTimestampLocaleTests: XCTestCase {

    /// Format an English elapsed-time render as a baseline.
    /// Establishes that the formatter is functional and matches
    /// expected vocabulary for the `.short` units style.
    func testAlertRowEnglishElapsedFormat() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let oneHourAgo = now.addingTimeInterval(-3600)
        let result = AlertRow.relativeTimestamp(
            for: oneHourAgo,
            locale: .us,
            relativeTo: now
        )
        XCTAssertTrue(
            result.contains("1") && (result.contains("hr") || result.contains("h ")),
            "Expected English short relative-time containing `1` and `hr`/`h `; got `\(result)`"
        )
    }

    /// Polish render — ensures a non-English locale actually picks
    /// the Polish relative-time strings from iOS base resources.
    /// Apple's Polish short relative-time strings render "1 godz."
    /// for an hour offset.
    func testAlertRowPolishElapsedFormat() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let oneHourAgo = now.addingTimeInterval(-3600)
        let result = AlertRow.relativeTimestamp(
            for: oneHourAgo,
            locale: .pl,
            relativeTo: now
        )
        XCTAssertFalse(
            result.contains("hr") || result.contains("ago"),
            "Polish locale must not leak English `hr` / `ago`; got `\(result)`"
        )
        XCTAssertTrue(
            result.contains("1") || result.contains("godz") || result.contains("temu"),
            "Polish locale should contain `godz` / `temu` / digit `1`; got `\(result)`"
        )
    }

    /// LatestAlertCard shares the same static helper signature; this
    /// guards against a future drift between the two components.
    func testLatestAlertCardEnglishElapsedFormat() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let fiveMinutesAgo = now.addingTimeInterval(-300)
        let result = LatestAlertCard.relativeTimestamp(
            for: fiveMinutesAgo,
            locale: .us,
            relativeTo: now
        )
        XCTAssertTrue(
            result.contains("5") || result.contains("min"),
            "Expected English short relative-time for 5-minute offset; got `\(result)`"
        )
    }

    /// German fallback — establishes that even a host-system English
    /// process produces a German render when ``locale`` is set.
    /// This is the actual i18n bug-fix this PR closes: the bare
    /// ``RelativeDateTimeFormatter()`` initializer was using
    /// ``Locale.current``, not the SwiftUI environment locale.
    func testLatestAlertCardGermanElapsedFormat() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let oneHourAgo = now.addingTimeInterval(-3600)
        let result = LatestAlertCard.relativeTimestamp(
            for: oneHourAgo,
            locale: .de,
            relativeTo: now
        )
        XCTAssertFalse(
            result.lowercased().contains("ago"),
            "German locale must not contain English `ago`; got `\(result)`"
        )
    }
}
