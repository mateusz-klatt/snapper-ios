import XCTest
@testable import Snapper

@MainActor
final class DeskViewTests: XCTestCase {

    func testDeskViewCanBeInstantiated() {
        XCTAssertNotNil(DeskView())
    }

    func testLoadErrorReplacesOnlyAnEmptySettledScreen() {
        XCTAssertTrue(DeskViewModel.shouldShowLoadError(
            deskCount: 0,
            loadError: .httpError(503),
            isLoading: false
        ))
        XCTAssertFalse(DeskViewModel.shouldShowLoadError(
            deskCount: 1,
            loadError: .httpError(503),
            isLoading: false
        ))
        XCTAssertFalse(DeskViewModel.shouldShowLoadError(
            deskCount: 0,
            loadError: .httpError(503),
            isLoading: true
        ))
        XCTAssertFalse(DeskViewModel.shouldShowLoadError(
            deskCount: 0,
            loadError: nil,
            isLoading: false
        ))
    }
}
