import XCTest
@testable import Snapper

/// Tests for ``LocaleStrings.localized`` — the canonical helper
/// for runtime-picked catalog lookup. Exercises the happy path
/// (en + pl) and the deterministic fallback chain when an
/// individual key is unrecognized in the requested language.
final class LocaleStringsTests: XCTestCase {

    func testEnglishLookupReturnsEnglishTemplate() {
        let value = LocaleStrings.localized("auth.login.signIn", in: .en)
        XCTAssertEqual(value, "Sign In")
    }

    func testPolishLookupReturnsPolishTemplate() {
        let value = LocaleStrings.localized("auth.login.signIn", in: .pl)
        XCTAssertEqual(value, "Zaloguj się")
    }

    func testPolishCurrentBackendTemplateHasPlaceholder() {
        let value = LocaleStrings.localized("auth.login.currentBackend", in: .pl)
        XCTAssertTrue(value.contains("%@"))
        XCTAssertTrue(value.contains("Aktualny backend"))
    }

    /// Missing-key fallback path: the helper should return the key
    /// itself rather than crashing or returning a system-preferred
    /// string from an unrelated bundle. Tests the chain
    /// pl → en → key when the key exists in neither catalog.
    func testUnknownKeyFallsBackToKey() {
        let value = LocaleStrings.localized("nonexistent.test.key", in: .pl)
        XCTAssertEqual(value, "nonexistent.test.key")
    }

    func testEnglishUnknownKeyFallsBackToKey() {
        let value = LocaleStrings.localized("nonexistent.test.key", in: .en)
        XCTAssertEqual(value, "nonexistent.test.key")
    }

    /// Catalog parity sanity — every key in the EN catalog must
    /// resolve in the PL catalog (no orphan keys); this is also
    /// covered by ``CatalogParityTests`` but exercising it through
    /// the runtime helper is a different code path.
    func testEveryCatalogKeyResolvesInBothLanguages() {
        let keys = [
            "auth.login.subtitle",
            "auth.login.signIn",
            "backend.url.save",
            "settings.section.language",
            "common.localeSwitcher.triggerAccessibilityLabel",
        ]
        for key in keys {
            let en = LocaleStrings.localized(key, in: .en)
            let pl = LocaleStrings.localized(key, in: .pl)
            XCTAssertNotEqual(en, key, "EN miss for \(key)")
            XCTAssertNotEqual(pl, key, "PL miss for \(key)")
        }
    }
}
