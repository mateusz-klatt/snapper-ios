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

    @Binding var draft: String
    let allowReset: Bool
    let onSave: (URL) -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    @Environment(AppState.self) private var appState

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
            TextField(LocalizedStringKey("backend.url.placeholder"), text: $draft)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()

            if let preview = canonicalizedPreview {
                Text(Self.willSaveAsCaption(preview: preview, in: appState.locale.catalogLanguage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(Self.invalidURLMessage(in: appState.locale.catalogLanguage))
                    .font(.caption)
                    .foregroundColor(Color.lossRed)
            } else {
                Text(Self.helpMessage(in: appState.locale.catalogLanguage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button(LocalizedStringKey("backend.url.cancel")) { onCancel() }
                    .buttonStyle(.bordered)

                if allowReset {
                    Button(LocalizedStringKey("backend.url.resetToDefault")) { onReset() }
                        .buttonStyle(.bordered)
                }

                Spacer()

                Button(LocalizedStringKey("backend.url.save")) {
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

    /// "Will save as: <URL>" caption rendered against the requested
    /// catalog language. Static so the test path (which does not need
    /// runtime locale wiring) can call it without constructing an
    /// ``AppState`` instance.
    static func willSaveAsCaption(preview: String, in language: CatalogLanguage) -> String {
        let template = LocaleStrings.localized("backend.url.willSaveAs", in: language)
        return String(
            format: template,
            locale: Locale(identifier: "\(language.rawValue)"),
            preview
        )
    }

    /// User-facing copy explaining a failed canonicalization. Kept
    /// in sync with ``BackendURLStore.canonicalize`` rules; the
    /// Debug + Release variants are separate catalog keys so the
    /// Polish translation can tailor each.
    static func invalidURLMessage(in language: CatalogLanguage) -> String {
        #if DEBUG
        return LocaleStrings.localized("backend.url.invalidDebug", in: language)
        #else
        return LocaleStrings.localized("backend.url.invalidRelease", in: language)
        #endif
    }

    static func helpMessage(in language: CatalogLanguage) -> String {
        return LocaleStrings.localized("backend.url.help", in: language)
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

        private func previewSave(_: URL) {}
        private func previewReset() {}
        private func previewCancel() {}
    }

    static var previews: some View {
        Container()
            .environment(AppState.shared)
    }
}
