import XCTest
import SwiftUI
@testable import Snapper

/// Pure-function tests for ``LocaleEnvironmentResolver``. These
/// cover the mapping that ``SnapperApp`` applies at the root
/// ``WindowGroup``; the rendered body is exercised by manual
/// Simulator smoke (per the repo pattern documented in
/// ``MainTabView.routeDeepLink(...)``).
final class LocaleEnvironmentResolverTests: XCTestCase {

    func testEnvironmentLocaleForIEisEnIE() {
        XCTAssertEqual(
            LocaleEnvironmentResolver.environmentLocale(for: .ie).identifier,
            "en-IE"
        )
    }

    func testEnvironmentLocaleForPLisPlPL() {
        XCTAssertEqual(
            LocaleEnvironmentResolver.environmentLocale(for: .pl).identifier,
            "pl-PL"
        )
    }

    func testEnvironmentLocaleForDEisDeDE() {
        XCTAssertEqual(
            LocaleEnvironmentResolver.environmentLocale(for: .de).identifier,
            "de-DE"
        )
    }

    func testEnvironmentLocaleForIcelandIsIsIS() {
        XCTAssertEqual(
            LocaleEnvironmentResolver.environmentLocale(for: .iceland).identifier,
            "is-IS"
        )
    }

    func testEnvironmentLocaleForIndiaIsEnIN() {
        XCTAssertEqual(
            LocaleEnvironmentResolver.environmentLocale(for: .india).identifier,
            "en-IN"
        )
    }

    func testLayoutDirectionForAEisRTL() {
        XCTAssertEqual(LocaleEnvironmentResolver.layoutDirection(for: .ae), .rightToLeft)
    }

    func testLayoutDirectionForILisRTL() {
        XCTAssertEqual(LocaleEnvironmentResolver.layoutDirection(for: .il), .rightToLeft)
    }

    func testLayoutDirectionForIRisRTL() {
        XCTAssertEqual(LocaleEnvironmentResolver.layoutDirection(for: .ir), .rightToLeft)
    }

    func testLayoutDirectionForUSisLTR() {
        XCTAssertEqual(LocaleEnvironmentResolver.layoutDirection(for: .us), .leftToRight)
    }

    func testLayoutDirectionForPLisLTR() {
        XCTAssertEqual(LocaleEnvironmentResolver.layoutDirection(for: .pl), .leftToRight)
    }

    func testLayoutDirectionForIEisLTR() {
        XCTAssertEqual(LocaleEnvironmentResolver.layoutDirection(for: .ie), .leftToRight)
    }

    func testEveryNonRTLCodeMapsToLTR() {
        for code in AppLocale.allCases where !code.isRTL {
            XCTAssertEqual(
                LocaleEnvironmentResolver.layoutDirection(for: code),
                .leftToRight,
                "Expected \(code.rawValue) → .leftToRight"
            )
        }
    }
}
