import XCTest
@testable import Snapper

@MainActor
final class MarketSelectorBarTests: XCTestCase {

    func testExchangeLabelUsesUppercasedSelection() {
        XCTAssertEqual(
            MarketSelectorBar.exchangeLabel(selectedExchange: "kraken", language: .pl),
            "KRAKEN"
        )
    }

    func testExchangeLabelFallbackIsLocalized() {
        XCTAssertEqual(MarketSelectorBar.exchangeLabel(selectedExchange: nil, language: .en), "Exchange")
        XCTAssertEqual(MarketSelectorBar.exchangeLabel(selectedExchange: nil, language: .pl), "Giełda")
    }

    func testInstrumentLabelUsesSelectedSymbol() {
        XCTAssertEqual(
            MarketSelectorBar.instrumentLabel(selectedSymbol: "BTC-USD", language: .pl),
            "BTC-USD"
        )
    }

    func testInstrumentLabelFallbackIsLocalized() {
        XCTAssertEqual(MarketSelectorBar.instrumentLabel(selectedSymbol: nil, language: .en), "Pick instrument")
        XCTAssertEqual(MarketSelectorBar.instrumentLabel(selectedSymbol: nil, language: .pl), "Wybierz instrument")
    }
}
