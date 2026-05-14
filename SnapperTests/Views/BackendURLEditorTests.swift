import XCTest
import SwiftUI
@testable import Snapper

/// Tests for ``BackendURLEditor`` — the view's pure helper logic
/// (canonicalize preview reactivity, save-button enable/disable per
/// validity). Body rendering is exercised via ``BackendURLEditor_Previews``
/// at compile time but not asserted here.
///
/// The previously-static ``invalidURLMessage`` and ``helpMessage``
/// are now catalog-driven instance vars (read via ``LocaleStrings``);
/// catalog presence + EN/PL parity is covered by ``CatalogParityTests``.
final class BackendURLEditorTests: XCTestCase {

    func testCanonicalizedURLIsNilForEmptyDraft() {
        let editor = makeEditor(draft: "")
        XCTAssertNil(editor.canonicalizedURL)
        XCTAssertNil(editor.canonicalizedPreview)
    }

    func testCanonicalizedURLIsNilForInvalidDraft() {
        let editor = makeEditor(draft: "not a url")
        XCTAssertNil(editor.canonicalizedURL)
    }

    func testCanonicalizedURLReturnsCanonicalForValidHTTPSDraft() {
        let editor = makeEditor(draft: "HTTPS://API.EXAMPLE.COM/")
        XCTAssertEqual(editor.canonicalizedURL?.absoluteString, "https://api.example.com")
    }

    func testCanonicalizedPreviewMatchesCanonicalString() {
        let editor = makeEditor(draft: "https://api.example.com/")
        XCTAssertEqual(editor.canonicalizedPreview, "https://api.example.com")
    }

    func testInvalidDraftWithPathHasNoCanonicalForm() {
        let editor = makeEditor(draft: "https://api.example.com/api/v1")
        XCTAssertNil(editor.canonicalizedURL)
    }

    func testEnglishInvalidURLMessageMatchesBuildPolicy() {
        let message = BackendURLEditor.invalidURLMessage(in: .en)
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("https://"))
    }

    func testEnglishHelpMessageIsNonEmpty() {
        XCTAssertFalse(BackendURLEditor.helpMessage(in: .en).isEmpty)
    }

    func testPolishHelpMessageDiffersFromEnglish() {
        let pl = BackendURLEditor.helpMessage(in: .pl)
        XCTAssertFalse(pl.isEmpty)
        XCTAssertNotEqual(pl, BackendURLEditor.helpMessage(in: .en))
    }

    func testWillSaveAsCaptionFillsPreview() {
        let caption = BackendURLEditor.willSaveAsCaption(
            preview: "https://api.example.com",
            in: .en
        )
        XCTAssertTrue(caption.contains("https://api.example.com"))
        XCTAssertTrue(caption.contains("Will save as"))
    }

    /// Build an editor with a frozen draft binding for pure-helper tests.
    ///
    /// The setter is intentionally a no-op — the tests treat the draft
    /// as static input and only exercise canonicalization helpers, not
    /// the Save/Reset/Cancel callbacks.
    private func makeEditor(draft: String) -> BackendURLEditor {
        let binding = Binding<String>(
            get: { draft },
            set: Self.discardDraftMutation
        )
        return BackendURLEditor(
            draft: binding,
            onSave: Self.discardSavedURL,
            onReset: Self.discardReset,
            onCancel: Self.discardCancel
        )
    }

    private static func discardDraftMutation(_: String) {}
    private static func discardSavedURL(_: URL) {}
    private static func discardReset() {}
    private static func discardCancel() {}
}
