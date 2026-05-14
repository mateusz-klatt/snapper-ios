import SwiftUI

/// Flag-grid locale picker that mirrors the web v3 LanguageSwitcher.
///
/// Trigger is a single emoji-flag button showing the currently-
/// selected locale. Tapping opens a popover with three rows of 15
/// flags (45 total). Selecting a flag commits the new locale to
/// ``AppState.locale`` (which persists to the ``"snapper-locale"``
/// UserDefaults key via the existing ``didSet``) and dismisses the
/// popover via the ``onSelect`` closure threaded down through
/// ``FlagRow`` / ``FlagButton``.
///
/// Reads ``AppState`` from the SwiftUI environment so callers can
/// drop ``LocaleSwitcher()`` anywhere under the app root's
/// ``.environment(AppState.shared)`` modifier without additional
/// plumbing. The trigger's accessibility label is resolved against
/// the current locale's catalog so VoiceOver announcements track
/// the picked language.
struct LocaleSwitcher: View {
    @Environment(AppState.self) private var appState
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Text(verbatim: appState.locale.flagEmoji).font(.title3)
        }
        .accessibilityLabel(
            LocaleStrings.localized(
                "common.localeSwitcher.triggerAccessibilityLabel",
                in: appState.locale.catalogLanguage
            )
        )
        .popover(isPresented: $isPresented) {
            VStack(spacing: 8) {
                FlagRow(codes: AppLocale.row1, onSelect: select)
                FlagRow(codes: AppLocale.row2, onSelect: select)
                FlagRow(codes: AppLocale.row3, onSelect: select)
            }
            .padding()
        }
    }

    private func select(_ code: AppLocale) {
        appState.locale = code
        isPresented = false
    }
}

private struct FlagRow: View {
    let codes: [AppLocale]
    let onSelect: (AppLocale) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(codes) { code in
                FlagButton(code: code, onSelect: onSelect)
            }
        }
    }
}

private struct FlagButton: View {
    let code: AppLocale
    let onSelect: (AppLocale) -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            onSelect(code)
        } label: {
            Text(verbatim: code.flagEmoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    LocaleSwitcherStyling.isSelected(code: code, current: appState.locale)
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear
                )
                .cornerRadius(8)
        }
        .accessibilityLabel(
            LocaleSwitcherLabels.accessibilityLabel(for: code, current: appState.locale)
        )
        .accessibilityAddTraits(
            LocaleSwitcherStyling.isSelected(code: code, current: appState.locale)
                ? .isSelected
                : []
        )
    }
}
