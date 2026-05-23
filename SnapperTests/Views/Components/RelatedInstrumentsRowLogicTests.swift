import XCTest
@testable import Snapper

@MainActor
final class RelatedInstrumentsRowLogicTests: XCTestCase {

    private func makeGroup(
        relationshipType: String,
        label: String = "Backend Label",
        itemSymbols: [String] = ["X"]
    ) -> RelatedInstrumentsGroup {
        return RelatedInstrumentsGroup(
            relationshipType: relationshipType,
            label: label,
            items: itemSymbols.map { sym in
                RelatedInstrumentData(
                    type: "related_instrument_data",
                    sequenceId: 1,
                    publicId: "rel-\(sym)",
                    timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                    sessionId: "session-test",
                    topic: nil,
                    instrumentPublicId: "inst-\(sym)",
                    nativeSymbol: sym,
                    exchange: "polygon",
                    assetType: "etf",
                    relationshipType: relationshipType,
                    contractFamily: nil,
                    isSelected: false
                )
            }
        )
    }

    func testClusterHeaderDerivativeEN() {
        let result = RelatedInstrumentsRowLogic.clusterHeader(
            group: makeGroup(relationshipType: "derivative"),
            lang: .en
        )
        XCTAssertEqual(result, "Derivatives:")
    }

    func testClusterHeaderDerivativePLDiffersFromEN() {
        let pl = RelatedInstrumentsRowLogic.clusterHeader(
            group: makeGroup(relationshipType: "derivative"),
            lang: .pl
        )
        let en = RelatedInstrumentsRowLogic.clusterHeader(
            group: makeGroup(relationshipType: "derivative"),
            lang: .en
        )
        XCTAssertTrue(pl.hasSuffix(":"), "PL header must use the labelSeparator template.")
        XCTAssertFalse(pl.isEmpty, "PL header must not be empty.")
        XCTAssertNotEqual(pl, en, "PL header must differ from EN so the localization path is exercised.")
    }

    func testClusterHeaderENCatalogHitDoesNotUseGroupLabelFallback() {
        let group = makeGroup(
            relationshipType: "exact",
            label: "Backend Fallback"
        )
        let baseline = RelatedInstrumentsRowLogic.clusterHeader(group: group, lang: .en)
        XCTAssertFalse(
            baseline.contains("Backend Fallback"),
            "EN catalog hit must NOT use the fallback (regression guard)."
        )
        XCTAssertEqual(baseline, "Same underlying:")
    }

    func testClusterHeaderExactEN() {
        let result = RelatedInstrumentsRowLogic.clusterHeader(
            group: makeGroup(relationshipType: "exact"),
            lang: .en
        )
        XCTAssertEqual(result, "Same underlying:")
    }

    func testClusterHeaderProxyEN() {
        let result = RelatedInstrumentsRowLogic.clusterHeader(
            group: makeGroup(relationshipType: "proxy"),
            lang: .en
        )
        XCTAssertEqual(result, "Proxies:")
    }

    func testClusterHeaderUnknownTypeFallsBackToGroupLabel() {
        let result = RelatedInstrumentsRowLogic.clusterHeader(
            group: makeGroup(
                relationshipType: "spinoff-of-spinoff",
                label: "Backend-Specific Label"
            ),
            lang: .en
        )
        XCTAssertEqual(result, "Backend-Specific Label:")
    }

    func testChipExchangeSuffixENRendersDotSeparator() {
        let result = RelatedInstrumentsRowLogic.chipExchangeSuffix(
            exchange: "polygon",
            lang: .en
        )
        XCTAssertEqual(result, "· polygon")
    }

    func testChipExchangeSuffixPL() {
        let result = RelatedInstrumentsRowLogic.chipExchangeSuffix(
            exchange: "kraken",
            lang: .pl
        )
        XCTAssertEqual(result, "· kraken")
    }

    func testEmptyStateMessageSubstitutesSymbolAndExchange() {
        let result = RelatedInstrumentsRowLogic.emptyStateMessage(
            symbol: "GLD",
            exchange: "polygon",
            lang: .en
        )
        XCTAssertEqual(result, "No related instruments configured for GLD on polygon.")
    }

    func testEmptyStateMessagePLDiffersFromENAndSubstitutes() {
        let pl = RelatedInstrumentsRowLogic.emptyStateMessage(
            symbol: "GLD",
            exchange: "polygon",
            lang: .pl
        )
        let en = RelatedInstrumentsRowLogic.emptyStateMessage(
            symbol: "GLD",
            exchange: "polygon",
            lang: .en
        )
        XCTAssertTrue(pl.contains("GLD"), "PL message must substitute the instrument placeholder.")
        XCTAssertTrue(pl.contains("polygon"), "PL message must substitute the exchange placeholder.")
        XCTAssertNotEqual(pl, en, "PL message must differ from EN so the localization path is exercised.")
    }
}
