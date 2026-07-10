import XCTest
@testable import Snapper

@MainActor
final class HealthViewTests: XCTestCase {

    func testShouldShowLoadErrorWhenNoDataAndError() {
        XCTAssertTrue(
            HealthViewModel.shouldShowLoadError(
                hasData: false,
                loadError: .httpError(503),
                isLoading: false
            )
        )
    }

    /// A cached snapshot takes priority over the error variant — an
    /// error banner must not hide health data the user can still read.
    func testShouldNotShowLoadErrorWhenHasData() {
        XCTAssertFalse(
            HealthViewModel.shouldShowLoadError(
                hasData: true,
                loadError: .invalidResponse,
                isLoading: false
            )
        )
    }

    func testShouldNotShowLoadErrorWhileLoading() {
        XCTAssertFalse(
            HealthViewModel.shouldShowLoadError(
                hasData: false,
                loadError: .invalidResponse,
                isLoading: true
            )
        )
    }

    func testShouldNotShowLoadErrorWhenNoError() {
        XCTAssertFalse(
            HealthViewModel.shouldShowLoadError(
                hasData: false,
                loadError: nil,
                isLoading: false
            )
        )
    }

    /// Severity mapping mirrors the backend ``HealthStatusEnum``
    /// (healthy / warning / error) and is case-insensitive; anything
    /// else falls to ``.unknown`` for a neutral render.
    func testSeverityMapping() {
        XCTAssertEqual(HealthViewModel.severity(for: "healthy"), .healthy)
        XCTAssertEqual(HealthViewModel.severity(for: "HEALTHY"), .healthy)
        XCTAssertEqual(HealthViewModel.severity(for: "warning"), .warning)
        XCTAssertEqual(HealthViewModel.severity(for: "error"), .error)
        XCTAssertEqual(HealthViewModel.severity(for: "degraded"), .unknown)
        XCTAssertEqual(HealthViewModel.severity(for: ""), .unknown)
    }

    func testSeverityLocalizationKeys() {
        XCTAssertEqual(HealthSeverity.healthy.localizationKey, "health.status.healthy")
        XCTAssertEqual(HealthSeverity.warning.localizationKey, "health.status.warning")
        XCTAssertEqual(HealthSeverity.error.localizationKey, "health.status.error")
        XCTAssertEqual(HealthSeverity.unknown.localizationKey, "health.status.unknown")
    }
}
