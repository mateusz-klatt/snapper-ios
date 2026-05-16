import XCTest
@testable import Snapper

/// Covers ``WebSocketManager.ConnectionState.displayName(in:)`` — typed
/// connection state to localized display value. The ``.error`` and
/// ``.authFailed`` cases interpolate the server-provided detail
/// VERBATIM (per Phase H L1).
final class WebSocketConnectionStateDisplayNameTests: XCTestCase {

    func testDisconnectedInEnglish() {
        XCTAssertEqual(WebSocketManager.ConnectionState.disconnected.displayName(in: .en),
                       "Disconnected")
    }

    func testDisconnectedInPolish() {
        XCTAssertEqual(WebSocketManager.ConnectionState.disconnected.displayName(in: .pl),
                       "Rozłączono")
    }

    func testConnectingInEnglish() {
        XCTAssertEqual(WebSocketManager.ConnectionState.connecting.displayName(in: .en),
                       "Connecting…")
    }

    func testConnectedInPolish() {
        XCTAssertEqual(WebSocketManager.ConnectionState.connected.displayName(in: .pl),
                       "Połączono")
    }

    func testAuthenticatingInEnglish() {
        XCTAssertEqual(WebSocketManager.ConnectionState.authenticating.displayName(in: .en),
                       "Authenticating…")
    }

    func testErrorCaseSubstitutesServerDetailVerbatim() {
        let state = WebSocketManager.ConnectionState.error("connection timeout")
        XCTAssertEqual(state.displayName(in: .en), "Error: connection timeout")
        XCTAssertEqual(state.displayName(in: .pl), "Błąd: connection timeout")
    }

    func testAuthFailedSubstitutesServerDetailVerbatim() {
        let state = WebSocketManager.ConnectionState.authFailed("token expired")
        XCTAssertEqual(state.displayName(in: .en), "Auth failed: token expired")
        XCTAssertEqual(state.displayName(in: .pl), "Uwierzytelnianie nie powiodło się: token expired")
    }
}
