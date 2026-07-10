import XCTest
@testable import Snapper

@MainActor
final class AdminViewTests: XCTestCase {

    func testShouldShowLoadErrorWhenEmptyAndLoadFailed() {
        XCTAssertTrue(AdminViewModel.shouldShowLoadError(count: 0, loadError: .httpError(503), isLoading: false))
    }

    func testShouldNotShowLoadErrorWhenListNonEmpty() {
        XCTAssertFalse(AdminViewModel.shouldShowLoadError(count: 4, loadError: .invalidResponse, isLoading: false))
    }

    func testShouldNotShowLoadErrorWhileLoading() {
        XCTAssertFalse(AdminViewModel.shouldShowLoadError(count: 0, loadError: .invalidResponse, isLoading: true))
    }

    func testShouldNotShowLoadErrorWhenNoError() {
        XCTAssertFalse(AdminViewModel.shouldShowLoadError(count: 0, loadError: nil, isLoading: false))
    }

    /// Only an explicit ``true`` reads as active; ``false`` and ``nil``
    /// both map to the inactive label.
    func testStatusLabelKey() {
        XCTAssertEqual(AdminViewModel.statusLabelKey(isActive: true), "admin.status.active")
        XCTAssertEqual(AdminViewModel.statusLabelKey(isActive: false), "admin.status.inactive")
        XCTAssertEqual(AdminViewModel.statusLabelKey(isActive: nil), "admin.status.inactive")
    }
}
