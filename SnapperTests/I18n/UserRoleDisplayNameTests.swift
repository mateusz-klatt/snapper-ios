import XCTest
@testable import Snapper

/// Covers ``UserRole.displayName(in:)`` — typed enum to catalog
/// localized display value mapping.
final class UserRoleDisplayNameTests: XCTestCase {

    func testAiDelegateInEnglish() {
        XCTAssertEqual(UserRole.aiDelegate.displayName(in: .en), "AI delegate")
    }

    func testAiDelegateInPolish() {
        XCTAssertEqual(UserRole.aiDelegate.displayName(in: .pl), "Delegat AI")
    }

    func testViewerInEnglish() {
        XCTAssertEqual(UserRole.viewer.displayName(in: .en), "Viewer")
    }

    func testViewerInPolish() {
        XCTAssertEqual(UserRole.viewer.displayName(in: .pl), "Obserwator")
    }

    func testOperatorRoleInEnglish() {
        XCTAssertEqual(UserRole.operatorRole.displayName(in: .en), "Operator")
    }

    func testOperatorRoleInPolish() {
        XCTAssertEqual(UserRole.operatorRole.displayName(in: .pl), "Operator")
    }

    func testAdminInEnglish() {
        XCTAssertEqual(UserRole.admin.displayName(in: .en), "Admin")
    }

    func testAdminInPolish() {
        XCTAssertEqual(UserRole.admin.displayName(in: .pl), "Administrator")
    }
}
