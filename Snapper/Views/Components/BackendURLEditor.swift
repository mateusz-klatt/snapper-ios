import SwiftUI

/// Reusable editor for the runtime backend-URL override.
///
/// Used by both ``LoginView``'s "Advanced" disclosure (unauthenticated
/// first-run path) and ``SettingsView``'s "Change backend…" sheet
/// (authenticated path that triggers a sign-out). Validation is
/// delegated to ``BackendURLStore.canonicalize`` so the editor never
/// commits a URL the store would reject.
///
/// Owner responsibilities:
/// - The caller controls whether Save persists immediately (Login)
///   or routes through a sign-out coordinator (Settings) by passing
///   the appropriate ``onSave`` closure.
/// - The caller redraws the surrounding "Current: …" label after
///   the disclosure / sheet dismisses; the editor itself is
///   stateless beyond the typing draft.
struct BackendURLEditor: View {

    /// Placeholder URL surfaced to the user inside the input field.
    /// Not connected to anywhere — purely a visual hint about the
    /// expected origin shape (`https://host[:port]`).
    static let inputPlaceholder = "https://your-backend.example"

    @Binding var draft: String
    let allowReset: Bool
    let onSave: (URL) -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    init(
        draft: Binding<String>,
        allowReset: Bool = true,
        onSave: @escaping (URL) -> Void,
        onReset: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._draft = draft
        self.allowReset = allowReset
        self.onSave = onSave
        self.onReset = onReset
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(Self.inputPlaceholder, text: $draft)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()

            if let preview = canonicalizedPreview {
                Text("Will save as: \(preview)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(BackendURLEditor.invalidURLMessage)
                    .font(.caption)
                    .foregroundColor(Color.lossRed)
            } else {
                Text(BackendURLEditor.helpMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)

                if allowReset {
                    Button("Reset to default") { onReset() }
                        .buttonStyle(.bordered)
                }

                Spacer()

                Button("Save") {
                    if let url = canonicalizedURL {
                        onSave(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(canonicalizedURL == nil)
            }
        }
    }

    /// Canonicalized URL preview as a string, or `nil` when the
    /// current draft fails validation.
    var canonicalizedPreview: String? {
        return canonicalizedURL?.absoluteString
    }

    /// Canonicalized URL, or `nil` when the current draft fails
    /// validation. Exposed for tests.
    var canonicalizedURL: URL? {
        return BackendURLStore.canonicalize(draft)
    }

    /// User-facing copy explaining a failed canonicalization. Kept
    /// in sync with ``BackendURLStore.canonicalize`` rules.
    static var invalidURLMessage: String {
        #if DEBUG
        return "Use https:// (or http:// for localhost in Debug). Origin only — no path, query, or fragment."
        #else
        return "Use https://your-backend.example. Origin only — no path, query, or fragment. App Store builds reject http:// and self-signed certificates."
        #endif
    }

    static var helpMessage: String {
        return "Casual users can ignore this. Self-hosters set the URL of their own Snapper backend."
    }
}

struct BackendURLEditor_Previews: PreviewProvider {
    /// Container reads-and-renders the static layout only.
    ///
    /// All three callbacks are no-ops because the SwiftUI Preview
    /// never invokes the action paths. Naming each handler avoids
    /// inline empty closures so the no-comments rule and Sonar's
    /// empty-closure rule (``swift:S1186``) are both satisfied;
    /// production wiring lives in ``LoginView`` and ``SettingsView``.
    private struct Container: View {
        @State private var draft: String = ""

        var body: some View {
            BackendURLEditor(
                draft: $draft,
                onSave: previewSave,
                onReset: previewReset,
                onCancel: previewCancel
            )
            .padding()
        }

        private func previewSave(_ url: URL) {}
        private func previewReset() {}
        private func previewCancel() {}
    }

    static var previews: some View {
        Container()
    }
}
