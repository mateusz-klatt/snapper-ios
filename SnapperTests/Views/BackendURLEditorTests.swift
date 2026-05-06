import XCTest
import SwiftUI
@testable import Snapper

/// Tests for ``BackendURLEditor`` — the view's pure helper logic
/// (canonicalize preview reactivity, save-button enable/disable per
/// validity). Body rendering is exercised via ``BackendURLEditor_Previews``
/// at compile time but not asserted here.
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

    func testInvalidURLMessageMatchesBuildPolicy() {
        let message = BackendURLEditor.invalidURLMessage
        XCTAssertFalse(message.isEmpty)
        #if DEBUG
        XCTAssertTrue(message.contains("https://"))
        #else
        XCTAssertTrue(message.contains("https://"))
        XCTAssertTrue(message.contains("App Store"))
        #endif
    }

    func testHelpMessageIsNonEmpty() {
        XCTAssertFalse(BackendURLEditor.helpMessage.isEmpty)
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
