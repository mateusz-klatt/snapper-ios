import XCTest
@testable import Snapper

@MainActor
final class MarketStatusRowTests: XCTestCase {

    func testLoadErrorMessagePrefersExistingDescription() {
        XCTAssertEqual(
            MarketStatusRow.loadErrorMessage(errorDescription: "Venue unavailable", language: .pl),
            "Venue unavailable"
        )
    }

    func testLoadErrorMessageFallbackIsLocalized() {
        XCTAssertEqual(MarketStatusRow.loadErrorMessage(errorDescription: nil, language: .en), "Failed to load")
        XCTAssertEqual(
            MarketStatusRow.loadErrorMessage(errorDescription: nil, language: .pl),
            "Nie udało się wczytać"
        )
    }
}
