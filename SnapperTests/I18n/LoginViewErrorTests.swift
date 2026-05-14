import XCTest
@testable import Snapper

/// Covers ``LoginViewError.localizedMessage(in:)`` — typed login-error
/// surface. Catalog entries land in Phase G; until then, missing-key
/// fallback returns the catalog key as the message body. Server-detail
/// case is verified to bypass the catalog (verbatim per L1).
final class LoginViewErrorTests: XCTestCase {

    func testServerDetailReturnsVerbatim() {
        let error = LoginViewError.serverDetail("Invalid credentials")
        XCTAssertEqual(error.localizedMessage(in: .en), "Invalid credentials")
        XCTAssertEqual(error.localizedMessage(in: .pl), "Invalid credentials")
    }

    func testServerDetailUTF8Preserved() {
        let error = LoginViewError.serverDetail("Błąd uwierzytelniania")
        XCTAssertEqual(error.localizedMessage(in: .en), "Błąd uwierzytelniania")
        XCTAssertEqual(error.localizedMessage(in: .pl), "Błąd uwierzytelniania")
    }

    func testInvalidURLEquatable() {
        XCTAssertEqual(LoginViewError.invalidURL, LoginViewError.invalidURL)
        XCTAssertNotEqual(LoginViewError.invalidURL, LoginViewError.loginFailed)
    }

    func testServerDetailEquatableByValue() {
        XCTAssertEqual(LoginViewError.serverDetail("X"), LoginViewError.serverDetail("X"))
        XCTAssertNotEqual(LoginViewError.serverDetail("X"), LoginViewError.serverDetail("Y"))
    }

    func testNetworkEquatableByValue() {
        XCTAssertEqual(LoginViewError.network("X"), LoginViewError.network("X"))
        XCTAssertNotEqual(LoginViewError.network("X"), LoginViewError.network("Y"))
    }

    func testInvalidURLMessageInEnglish() {
        let error = LoginViewError.invalidURL
        XCTAssertEqual(error.localizedMessage(in: .en), "Invalid URL")
    }

    func testInvalidURLMessageInPolish() {
        let error = LoginViewError.invalidURL
        XCTAssertEqual(error.localizedMessage(in: .pl), "Nieprawidłowy URL")
    }

    func testSerializationFailedMessageInEnglish() {
        let error = LoginViewError.serializationFailed
        XCTAssertEqual(error.localizedMessage(in: .en), "Failed to serialize login request")
    }

    func testInvalidResponseMessageInPolish() {
        let error = LoginViewError.invalidResponse
        XCTAssertEqual(error.localizedMessage(in: .pl), "Nieprawidłowa odpowiedź serwera")
    }

    func testLoginFailedMessageInEnglish() {
        let error = LoginViewError.loginFailed
        XCTAssertEqual(error.localizedMessage(in: .en), "Login failed")
    }

    func testNetworkMessageSubstitutesUnderlyingDetail() {
        let error = LoginViewError.network("timeout after 30s")
        let result = error.localizedMessage(in: .en)
        XCTAssertEqual(result, "Network error: timeout after 30s")
    }

    func testNetworkMessageInPolish() {
        let error = LoginViewError.network("przekroczenie czasu")
        let result = error.localizedMessage(in: .pl)
        XCTAssertEqual(result, "Błąd sieci: przekroczenie czasu")
    }
}
