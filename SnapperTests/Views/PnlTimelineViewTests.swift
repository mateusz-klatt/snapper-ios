import XCTest
@testable import Snapper

/// Static-helper coverage for the P&L timeline display surface (no
/// ViewInspector — this project tests pure helpers only). Exercises the
/// incompleteness grouping, net computation, instrument-identity
/// fallback chain, and latest-point selection that drive
/// ``PnlTimelineView``'s sections.
@MainActor
final class PnlTimelineViewTests: XCTestCase {

    private static let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeContribution(
        instrumentPublicId: String = "inst-1",
        nativeSymbol: String? = "BTCUSD",
        exchange: String? = "kraken",
        realized: Double? = 1.0,
        fee: Double? = -0.25,
        accrual: Double? = 0.0,
        unrealized: Double? = 2.0
    ) -> PnlInstrumentContributionData {
        return PnlInstrumentContributionData(
            instrumentPublicId: instrumentPublicId,
            nativeSymbol: nativeSymbol,
            exchange: exchange,
            realizedPnl: realized,
            feePnl: fee,
            accrualPnl: accrual,
            unrealizedPnl: unrealized
        )
    }

    private func makeReason(
        reason: PnlIncompletenessReason,
        tier: PnlWithholdingTier,
        scope: PnlWithholdingScope,
        trigger: String?
    ) -> PnlIncompletenessReasonData {
        return PnlIncompletenessReasonData(
            reason: reason,
            withholdingTier: tier,
            withholdingScope: scope,
            triggerInstrumentPublicId: trigger
        )
    }

    private func makePoint(
        net: Double? = 1.0,
        status: PnlValuationStatus = .complete,
        reasons: [PnlIncompletenessReasonData] = [],
        perInstrument: [PnlInstrumentContributionData] = []
    ) -> PnlTimelinePointData {
        return PnlTimelinePointData(
            pointTime: Self.base,
            realizedPnl: 1.0,
            feePnl: 0.0,
            accrualPnl: 0.0,
            unrealizedPnl: net,
            netPnl: net,
            valuationStatus: status,
            incompletenessReasons: reasons,
            perInstrument: perInstrument,
            attribution: []
        )
    }

    private func makeSeries(points: [PnlTimelinePointData]) -> PnlSeriesData {
        return PnlSeriesData(
            sequenceId: 1,
            publicId: "pnl-1",
            timestamp: Self.base,
            sessionId: "session-1",
            walletPublicId: "wallet-1",
            mode: "live",
            granularity: "1h",
            valuationCcy: "USD",
            fromTime: Self.base,
            toTime: Self.base,
            asOf: Self.base,
            markSource: "finalized_1m_candle_close",
            rateSources: [],
            calcVersion: "5A.13",
            points: points
        )
    }

    func testIncompleteCount() {
        let points = [
            makePoint(status: .complete),
            makePoint(status: .incomplete),
            makePoint(status: .incomplete),
        ]
        XCTAssertEqual(PnlTimelineViewModel.incompleteCount(points: points), 2)
    }

    func testLatestPoint() {
        let first = makePoint(net: 1.0)
        let last = makePoint(net: 9.0)
        let series = makeSeries(points: [first, last])
        XCTAssertEqual(PnlTimelineViewModel.latestPoint(series)?.netPnl, 9.0)
        XCTAssertNil(PnlTimelineViewModel.latestPoint(nil))
        XCTAssertNil(PnlTimelineViewModel.latestPoint(makeSeries(points: [])))
    }

    func testContributionNetSumsWhenAllPresent() {
        let contribution = makeContribution(realized: 1.0, fee: -0.5, accrual: 0.25, unrealized: 2.0)
        XCTAssertEqual(PnlTimelineViewModel.contributionNet(contribution), 2.75)
    }

    func testContributionNetIsNilWhenAnyComponentWithheld() {
        XCTAssertNil(PnlTimelineViewModel.contributionNet(
            makeContribution(realized: nil, fee: 0.5, accrual: 0.25, unrealized: 2.0)
        ), "Withheld realized yields nil")
        XCTAssertNil(PnlTimelineViewModel.contributionNet(
            makeContribution(realized: 1.0, fee: nil, accrual: 0.25, unrealized: 2.0)
        ), "Withheld fee yields nil")
        XCTAssertNil(PnlTimelineViewModel.contributionNet(
            makeContribution(realized: 1.0, fee: 0.5, accrual: nil, unrealized: 2.0)
        ), "Withheld accrual yields nil")
        XCTAssertNil(PnlTimelineViewModel.contributionNet(
            makeContribution(realized: 1.0, fee: 0.5, accrual: 0.25, unrealized: nil)
        ), "Withheld unrealized yields nil")
    }

    func testInstrumentIdentityFallbackChain() {
        XCTAssertEqual(
            PnlTimelineViewModel.instrumentIdentity(makeContribution(nativeSymbol: "BTCUSD", exchange: "kraken")),
            "BTCUSD · kraken"
        )
        XCTAssertEqual(
            PnlTimelineViewModel.instrumentIdentity(makeContribution(nativeSymbol: "BTCUSD", exchange: nil)),
            "BTCUSD"
        )
        XCTAssertEqual(
            PnlTimelineViewModel.instrumentIdentity(
                makeContribution(instrumentPublicId: "inst-9", nativeSymbol: nil, exchange: nil)
            ),
            "inst-9"
        )
    }

    func testGroupedIncompletenessGroupsSortsAndCounts() {
        let markReason = makeReason(reason: .markUnavailable, tier: .markIncomplete, scope: .instrument, trigger: "inst-1")
        let globalReason = makeReason(reason: .beforeActivation, tier: .untrusted, scope: .global, trigger: nil)
        let contribution = makeContribution(instrumentPublicId: "inst-1", nativeSymbol: "BTCUSD", exchange: "kraken")

        let pointA = makePoint(status: .incomplete, reasons: [markReason], perInstrument: [contribution])
        let pointB = makePoint(status: .incomplete, reasons: [markReason, globalReason], perInstrument: [])
        let pointC = makePoint(status: .complete)

        let groups = PnlTimelineViewModel.groupedIncompleteness(points: [pointA, pointB, pointC])

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].reason.reason, .beforeActivation, "Global scope sorts first")
        XCTAssertEqual(groups[0].reason.withholdingScope, .global)
        XCTAssertEqual(groups[0].affectedPointCount, 1)
        XCTAssertNil(groups[0].triggerContribution)

        XCTAssertEqual(groups[1].reason.reason, .markUnavailable)
        XCTAssertEqual(groups[1].reason.withholdingScope, .instrument)
        XCTAssertEqual(groups[1].affectedPointCount, 2)
        XCTAssertEqual(groups[1].triggerContribution?.instrumentPublicId, "inst-1")
    }

    func testGroupedIncompletenessDedupesDuplicateReasonsWithinAPoint() {
        let reason = makeReason(reason: .markUnavailable, tier: .markIncomplete, scope: .global, trigger: nil)
        let point = makePoint(status: .incomplete, reasons: [reason, reason])
        let groups = PnlTimelineViewModel.groupedIncompleteness(points: [point])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].affectedPointCount, 1, "Duplicate reasons in one point count once")
    }

    func testGroupedIncompletenessSortTieBreakers() {
        let reasons = [
            makeReason(reason: .markUnavailable, tier: .untrusted, scope: .instrument, trigger: "inst-b"),
            makeReason(reason: .costBasisUnavailable, tier: .markIncomplete, scope: .instrument, trigger: "inst-a"),
            makeReason(reason: .fxConversionUnproven, tier: .markIncomplete, scope: .instrument, trigger: "inst-a"),
            makeReason(reason: .netNonFinite, tier: .untrusted, scope: .global, trigger: nil),
            makeReason(reason: .beforeActivation, tier: .markIncomplete, scope: .global, trigger: nil),
        ]
        let point = makePoint(status: .incomplete, reasons: reasons)
        let groups = PnlTimelineViewModel.groupedIncompleteness(points: [point])
        let order = groups.map {
            [$0.reason.withholdingScope.rawValue, $0.reason.triggerInstrumentPublicId ?? "∅",
             $0.reason.withholdingTier.rawValue, $0.reason.reason.rawValue]
        }
        XCTAssertEqual(order, [
            ["global", "∅", "mark_incomplete", "before_activation"],
            ["global", "∅", "untrusted", "net_non_finite"],
            ["instrument", "inst-a", "mark_incomplete", "cost_basis_unavailable"],
            ["instrument", "inst-a", "mark_incomplete", "fx_conversion_unproven"],
            ["instrument", "inst-b", "untrusted", "mark_unavailable"],
        ], "Sort: scope global-first, then trigger id, then mark_incomplete-before-untrusted, then reason")
    }
}
