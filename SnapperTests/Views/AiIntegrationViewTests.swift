import XCTest
@testable import Snapper

@MainActor
final class AiIntegrationViewTests: XCTestCase {

    func testShouldShowLoadErrorWhenEmptyAndLoadFailed() {
        XCTAssertTrue(AiIntegrationViewModel.shouldShowLoadError(count: 0, loadError: .httpError(503), isLoading: false))
    }

    func testShouldNotShowLoadErrorWhenListNonEmpty() {
        XCTAssertFalse(AiIntegrationViewModel.shouldShowLoadError(count: 2, loadError: .invalidResponse, isLoading: false))
    }

    func testShouldNotShowLoadErrorWhileLoading() {
        XCTAssertFalse(AiIntegrationViewModel.shouldShowLoadError(count: 0, loadError: .invalidResponse, isLoading: true))
    }

    func testShouldNotShowLoadErrorWhenNoError() {
        XCTAssertFalse(AiIntegrationViewModel.shouldShowLoadError(count: 0, loadError: nil, isLoading: false))
    }

    /// An active delegate reads "active"; a deactivated one reads
    /// "revoked" (not "inactive").
    func testStatusLabelKey() {
        XCTAssertEqual(AiIntegrationViewModel.statusLabelKey(isActive: true), "aiIntegration.status.active")
        XCTAssertEqual(AiIntegrationViewModel.statusLabelKey(isActive: false), "aiIntegration.status.revoked")
    }

    /// An unset cap renders the passed-in default label; a set integer
    /// cap renders its value.
    func testCapValueTextFallsBackToDefault() {
        XCTAssertEqual(AiIntegrationViewModel.capValueText(nil, defaultLabel: "Default"), "Default")
        XCTAssertEqual(AiIntegrationViewModel.capValueText(5, defaultLabel: "Default"), "5")
    }

    /// An unset USD cap renders the default label; a set value renders a
    /// locale-formatted currency string containing the amount.
    func testCapCurrencyTextFallsBackToDefault() {
        XCTAssertEqual(
            AiIntegrationViewModel.capCurrencyText(nil, locale: .us, defaultLabel: "Default"),
            "Default"
        )
        let formatted = AiIntegrationViewModel.capCurrencyText(10_000, locale: .us, defaultLabel: "Default")
        XCTAssertNotEqual(formatted, "Default")
        XCTAssertTrue(formatted.contains("10"), "expected the amount, got \(formatted)")
    }
}
