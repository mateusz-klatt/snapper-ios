import XCTest
@testable import Snapper

@MainActor
final class InstrumentDescriptionBannerLogicTests: XCTestCase {

    override func setUp() {
        super.setUp()
        /// Pin to US locale so the catalog-resolution helpers fall
        /// through deterministically. ``AppState.shared`` resolves
        /// ``locale`` from system preferred languages on first launch,
        /// which can land on ``.ie`` (catalog language ``.ga``) on a
        /// freshly-booted simulator — that catalog has no entries and
        /// would cause every ``LocaleStrings.localized`` lookup to
        /// miss in a way that masks the test intent.
        AppState.shared.locale = .us
    }

    private func makeUnderlying(
        name: String = "SPDR Gold Trust",
        assetClass: String = "commodity",
        sector: String? = "Precious Metals",
        description: String? = "Backend description."
    ) -> RelatedInstrumentsUnderlying {
        return RelatedInstrumentsUnderlying(
            publicId: "underlying-test",
            ticker: "GLD",
            name: name,
            assetClass: assetClass,
            sector: sector,
            description: description
        )
    }

    func testNormalizeAssetClassKnown() {
        XCTAssertEqual(InstrumentDescriptionBannerLogic.normalizeAssetClass("crypto"), .crypto)
        XCTAssertEqual(InstrumentDescriptionBannerLogic.normalizeAssetClass("commodity"), .commodity)
        XCTAssertEqual(InstrumentDescriptionBannerLogic.normalizeAssetClass("forex"), .forex)
        XCTAssertEqual(InstrumentDescriptionBannerLogic.normalizeAssetClass("index"), .index)
        XCTAssertEqual(InstrumentDescriptionBannerLogic.normalizeAssetClass("yield"), .yield)
    }

    func testNormalizeAssetClassUppercase() {
        XCTAssertEqual(InstrumentDescriptionBannerLogic.normalizeAssetClass("CRYPTO"), .crypto)
        XCTAssertEqual(InstrumentDescriptionBannerLogic.normalizeAssetClass("Commodity"), .commodity)
    }

    func testNormalizeAssetClassUnknownReturnsUnknown() {
        XCTAssertEqual(InstrumentDescriptionBannerLogic.normalizeAssetClass("magic"), .unknown)
        XCTAssertEqual(InstrumentDescriptionBannerLogic.normalizeAssetClass(""), .unknown)
    }

    func testSlugifySectorIndustrialMetals() {
        XCTAssertEqual(
            InstrumentDescriptionBannerLogic.slugifySector("Industrial Metals"),
            "industrial-metals"
        )
    }

    func testSlugifySectorSingleWord() {
        XCTAssertEqual(
            InstrumentDescriptionBannerLogic.slugifySector("Energy"),
            "energy"
        )
    }

    func testSlugifySectorAlreadySlug() {
        XCTAssertEqual(
            InstrumentDescriptionBannerLogic.slugifySector("us-tech"),
            "us-tech"
        )
    }

    /// Until the ``market.sector.*`` catalog entries land (next step
    /// adds the port script + xcstrings regeneration), the
    /// localized-sector lookup misses and the helper falls through
    /// to step 2 (raw sector string). Asserts the step-2 path.
    func testChipLabelFallsBackToRawSectorWhenCatalogMisses() {
        let label = InstrumentDescriptionBannerLogic.chipLabel(
            sector: "Precious Metals",
            assetClass: .commodity,
            lang: .en
        )
        XCTAssertEqual(label, "Precious Metals")
    }

    func testChipLabelUnknownSectorReturnsRawString() {
        let label = InstrumentDescriptionBannerLogic.chipLabel(
            sector: "Bespoke Vintage Carbon",
            assetClass: .commodity,
            lang: .en
        )
        XCTAssertEqual(label, "Bespoke Vintage Carbon")
    }

    func testChipLabelNilSectorReturnsAssetClassLabel() {
        let label = InstrumentDescriptionBannerLogic.chipLabel(
            sector: nil,
            assetClass: .commodity,
            lang: .en
        )
        XCTAssertEqual(label, "Commodity", "Falls through to localized asset-class label.")
    }

    func testChipLabelEmptySectorTreatedAsNil() {
        let label = InstrumentDescriptionBannerLogic.chipLabel(
            sector: "",
            assetClass: .crypto,
            lang: .en
        )
        XCTAssertEqual(label, "Cryptocurrency")
    }

    func testChipLabelKnownSectorReturnsLocalizedLabelEN() {
        let label = InstrumentDescriptionBannerLogic.chipLabel(
            sector: "Precious Metals",
            assetClass: .commodity,
            lang: .en
        )
        XCTAssertEqual(label, "Precious Metals")
    }

    func testChipLabelKnownSectorReturnsLocalizedLabelPL() {
        let label = InstrumentDescriptionBannerLogic.chipLabel(
            sector: "Precious Metals",
            assetClass: .commodity,
            lang: .pl
        )
        XCTAssertEqual(label, "Metale szlachetne")
    }

    func testResolvedDescriptionNonNilReturnsBackendString() {
        let underlying = makeUnderlying(description: "A specific backend description.")
        let result = InstrumentDescriptionBannerLogic.resolvedDescription(
            underlying: underlying,
            lang: .en
        )
        XCTAssertEqual(result, "A specific backend description.")
    }

    func testResolvedDescriptionNilReturnsFallback() {
        let underlying = makeUnderlying(description: nil)
        let result = InstrumentDescriptionBannerLogic.resolvedDescription(
            underlying: underlying,
            lang: .en
        )
        XCTAssertEqual(result, "SPDR Gold Trust · Commodity", "Fallback uses localized asset-class label.")
    }

    func testResolvedDescriptionEmptyTreatedAsNil() {
        let underlying = makeUnderlying(description: "")
        let result = InstrumentDescriptionBannerLogic.resolvedDescription(
            underlying: underlying,
            lang: .en
        )
        XCTAssertEqual(result, "SPDR Gold Trust · Commodity")
    }

    func testResolvedDescriptionUnknownAssetClass() {
        let underlying = makeUnderlying(
            assetClass: "magic-thing",
            description: nil
        )
        let result = InstrumentDescriptionBannerLogic.resolvedDescription(
            underlying: underlying,
            lang: .en
        )
        XCTAssertEqual(result, "SPDR Gold Trust · Other", "Unknown asset class maps to localized 'Other'.")
    }

    func testResolvedDescriptionFallbackPL() {
        let underlying = makeUnderlying(description: nil)
        let result = InstrumentDescriptionBannerLogic.resolvedDescription(
            underlying: underlying,
            lang: .pl
        )
        XCTAssertEqual(result, "SPDR Gold Trust · Towar")
    }
}
