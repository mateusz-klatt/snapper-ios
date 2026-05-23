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

    func testClusterHeaderDerivativePL() {
        let result = RelatedInstrumentsRowLogic.clusterHeader(
            group: makeGroup(relationshipType: "derivative"),
            lang: .pl
        )
        XCTAssertEqual(result, "Instrumenty pochodne:")
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

    func testEmptyStateMessageHandlesNilSelection() {
        let result = RelatedInstrumentsRowLogic.emptyStateMessage(
            symbol: nil,
            exchange: nil,
            lang: .en
        )
        XCTAssertEqual(result, "No related instruments configured for  on .")
    }

    func testEmptyStateMessagePL() {
        let result = RelatedInstrumentsRowLogic.emptyStateMessage(
            symbol: "GLD",
            exchange: "polygon",
            lang: .pl
        )
        XCTAssertEqual(result, "Brak skonfigurowanych powiązanych instrumentów dla GLD na polygon.")
    }
}
