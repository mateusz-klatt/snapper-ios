import SwiftUI
import XCTest
@testable import Snapper

/// Tests for the ``Color.financialRising(for:)`` /
/// ``financialFalling(for:)`` helpers in ``Theme.swift``.
@MainActor
final class ThemeFinancialColorTests: XCTestCase {

    /// `UserDefaults` instance scoped to this test class so writes from
    /// `AppState.didSet` observers don't leak across runs.
    private var ud: UserDefaults!

    override func setUp() {
        super.setUp()
        ud = UserDefaults(suiteName: "ThemeFinancialColorTests-\(UUID().uuidString)")!
    }

    override func tearDown() {
        ud = nil
        super.tearDown()
    }

    private func makeAppState(
        locale: AppLocale,
        preference: FinancialColorPreference
    ) -> AppState {
        let state = AppState(userDefaults: ud, preferredLanguagesProvider: { ["en"] })
        state.locale = locale
        state.financialColorPreference = preference
        return state
    }

    func testRisingReturnsProfitGreenForWesternDefault() {
        let state = makeAppState(locale: .us, preference: .auto)
        XCTAssertEqual(Color.financialRising(for: state), .profitGreen)
    }

    func testFallingReturnsLossRedForWesternDefault() {
        let state = makeAppState(locale: .us, preference: .auto)
        XCTAssertEqual(Color.financialFalling(for: state), .lossRed)
    }

    func testRisingFlipsToLossRedForChineseLocaleAutoPreference() {
        let state = makeAppState(locale: .cn, preference: .auto)
        XCTAssertEqual(Color.financialRising(for: state), .lossRed)
    }

    func testFallingFlipsToProfitGreenForChineseLocaleAutoPreference() {
        let state = makeAppState(locale: .cn, preference: .auto)
        XCTAssertEqual(Color.financialFalling(for: state), .profitGreen)
    }

    func testRisingFlipsWhenExplicitlySetToRisingRedEvenOnWesternLocale() {
        let state = makeAppState(locale: .us, preference: .risingRed)
        XCTAssertEqual(Color.financialRising(for: state), .lossRed)
        XCTAssertEqual(Color.financialFalling(for: state), .profitGreen)
    }

    func testExplicitRisingGreenOverridesAsianLocaleAuto() {
        let state = makeAppState(locale: .cn, preference: .risingGreen)
        XCTAssertEqual(Color.financialRising(for: state), .profitGreen)
        XCTAssertEqual(Color.financialFalling(for: state), .lossRed)
    }
}
