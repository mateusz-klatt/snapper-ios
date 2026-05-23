import XCTest
@testable import Snapper

@MainActor
final class PairStatsRowLogicTests: XCTestCase {

    private func makePayload(
        left: String,
        right: String,
        pearsonR: Double? = 0.5,
        cointPvalue: Double? = 0.02,
        isWarm: Bool = true
    ) -> CachedStatsPayload {
        return CachedStatsPayload(
            left: left,
            right: right,
            pearsonR: pearsonR,
            pearsonN: 100,
            cointT: nil,
            cointPvalue: cointPvalue,
            cointCriticalValues: nil,
            computedAt: nil,
            sampleCount: 100,
            isWarm: isWarm
        )
    }

    func testSignedPearsonPositive() {
        XCTAssertEqual(PairStatsRowLogic.signedPearsonString(0.853), "+0.85")
    }

    func testSignedPearsonNegativeUsesU2212MinusSign() {
        let result = PairStatsRowLogic.signedPearsonString(-0.853)
        XCTAssertEqual(result, "\u{2212}0.85")
        XCTAssertFalse(result.contains("-"), "Must use U+2212, not ASCII hyphen.")
    }

    func testSignedPearsonZero() {
        XCTAssertEqual(PairStatsRowLogic.signedPearsonString(0.0), "+0.00")
    }

    func testSignedPearsonNil() {
        XCTAssertEqual(PairStatsRowLogic.signedPearsonString(nil), "—")
    }

    func testPvalueBelowThreshold() {
        XCTAssertEqual(PairStatsRowLogic.pvalueString(0.00009), "<0.001")
    }

    func testPvalueAboveThreshold() {
        XCTAssertEqual(PairStatsRowLogic.pvalueString(0.04321), "0.043")
    }

    func testPvalueAtThreshold() {
        XCTAssertEqual(PairStatsRowLogic.pvalueString(0.001), "0.001")
    }

    func testPvalueNil() {
        XCTAssertEqual(PairStatsRowLogic.pvalueString(nil), "—")
    }

    func testIsCointegratedBelowThreshold() {
        XCTAssertTrue(PairStatsRowLogic.isCointegrated(0.049))
    }

    func testIsCointegratedAtThresholdIsFalse() {
        XCTAssertFalse(
            PairStatsRowLogic.isCointegrated(0.05),
            "Strict-less-than: p == threshold is NOT cointegrated."
        )
    }

    func testIsCointegratedNil() {
        XCTAssertFalse(PairStatsRowLogic.isCointegrated(nil))
    }

    func testSplitPairKeySimple() {
        let result = PairStatsRowLogic.splitPairKey("polygon:GLD")
        XCTAssertEqual(result?.exchange, "polygon")
        XCTAssertEqual(result?.symbol, "GLD")
    }

    func testSplitPairKeyNoColonReturnsNil() {
        XCTAssertNil(PairStatsRowLogic.splitPairKey("polygonGLD"))
    }

    func testSplitPairKeyLeadingColonReturnsNil() {
        XCTAssertNil(PairStatsRowLogic.splitPairKey(":GLD"))
    }

    func testSplitPairKeyMultipleColonsSplitsOnFirst() {
        let result = PairStatsRowLogic.splitPairKey("a:b:c")
        XCTAssertEqual(result?.exchange, "a")
        XCTAssertEqual(result?.symbol, "b:c")
    }

    func testBuildChipsSelfOnLeftExtractsRight() {
        let pairs = [makePayload(left: "polygon:GLD", right: "polygon:IAU")]
        let chips = PairStatsRowLogic.buildChips(pairs: pairs, selfKey: "polygon:GLD")
        XCTAssertEqual(chips.count, 1)
        XCTAssertEqual(chips[0].otherExchange, "polygon")
        XCTAssertEqual(chips[0].otherSymbol, "IAU")
    }

    func testBuildChipsSelfOnRightExtractsLeft() {
        let pairs = [makePayload(left: "polygon:IAU", right: "polygon:GLD")]
        let chips = PairStatsRowLogic.buildChips(pairs: pairs, selfKey: "polygon:GLD")
        XCTAssertEqual(chips.count, 1)
        XCTAssertEqual(chips[0].otherSymbol, "IAU")
    }

    func testBuildChipsNeitherSideSkipped() {
        let pairs = [makePayload(left: "polygon:SPY", right: "polygon:VOO")]
        let chips = PairStatsRowLogic.buildChips(pairs: pairs, selfKey: "polygon:GLD")
        XCTAssertEqual(chips.count, 0)
    }

    func testBuildChipsMalformedOtherKeySkipped() {
        let pairs = [makePayload(left: "polygon:GLD", right: "no-colon-here")]
        let chips = PairStatsRowLogic.buildChips(pairs: pairs, selfKey: "polygon:GLD")
        XCTAssertEqual(chips.count, 0)
    }

    func testBuildChipsSortOrderPvalueAscendingPearsonDesc() {
        let pairs = [
            makePayload(left: "polygon:GLD", right: "polygon:A", pearsonR: 0.7, cointPvalue: 0.04),
            makePayload(left: "polygon:GLD", right: "polygon:B", pearsonR: 0.9, cointPvalue: 0.01),
            makePayload(left: "polygon:GLD", right: "polygon:C", pearsonR: 0.6, cointPvalue: 0.01),
            makePayload(left: "polygon:GLD", right: "polygon:D", pearsonR: 0.5, cointPvalue: nil),
        ]
        let chips = PairStatsRowLogic.buildChips(pairs: pairs, selfKey: "polygon:GLD")
        XCTAssertEqual(chips.map(\.otherSymbol), ["B", "C", "A", "D"])
    }

    func testResolveChipStyleLowPvalueWarmReturnsCointegrated() {
        let chip = PairStatsChipModel(
            otherExchange: "polygon",
            otherSymbol: "X",
            pearsonR: 0.9,
            cointPvalue: 0.01,
            isWarm: true
        )
        XCTAssertEqual(PairStatsRowLogic.resolveChipStyle(chip: chip), .cointegrated)
    }

    func testResolveChipStyleHighPvalueWarmReturnsWarmNonCointegrated() {
        let chip = PairStatsChipModel(
            otherExchange: "polygon",
            otherSymbol: "X",
            pearsonR: 0.4,
            cointPvalue: 0.5,
            isWarm: true
        )
        XCTAssertEqual(PairStatsRowLogic.resolveChipStyle(chip: chip), .warmNonCointegrated)
    }

    func testResolveChipStyleColdReturnsCold() {
        let chip = PairStatsChipModel(
            otherExchange: "polygon",
            otherSymbol: "X",
            pearsonR: 0.9,
            cointPvalue: 0.01,
            isWarm: false
        )
        XCTAssertEqual(PairStatsRowLogic.resolveChipStyle(chip: chip), .cold)
    }
}
