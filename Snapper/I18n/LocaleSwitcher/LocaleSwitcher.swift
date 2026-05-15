import SwiftUI

/// Flag-grid locale picker that mirrors the web v3 LanguageSwitcher.
///
/// Trigger is a single emoji-flag button showing the currently-
/// selected locale. Tapping opens a popover with three rows of 15
/// flags (45 total). The popover content is horizontally scrollable
/// so the 3×15 layout stays intact on compact iPhone widths (15×44pt
/// per row exceeds any iPhone screen width); on iPad and larger the
/// full grid renders without scrolling.
///
/// Selecting a flag commits the new locale to ``AppState.locale``
/// (persisted under ``"snapper-locale"`` UserDefaults) and dismisses
/// the popover.
///
/// Keyboard navigation (iPad external keyboard, primary):
/// - Arrow keys move focus across the 3×15 grid; vertical movement
///   is column-aligned via ``LocaleSwitcherFocus/next(from:by:vertical:)``.
/// - Return / Space activate the focused ``Button`` (SwiftUI default).
/// - Escape dismisses the popover without committing.
struct LocaleSwitcher: View {
    @Environment(AppState.self) private var appState
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Text(verbatim: appState.locale.flagEmoji).font(.title3)
        }
        .accessibilityIdentifier("localeSwitcher.trigger")
        .accessibilityLabel(
            LocaleStrings.localized(
                "common.localeSwitcher.triggerAccessibilityLabel",
                in: appState.locale.catalogLanguage
            )
        )
        .popover(isPresented: $isPresented) {
            LocaleSwitcherPopoverContent(
                currentLocale: appState.locale,
                onSelect: select,
                onDismiss: dismissPopover
            )
        }
    }

    private func select(_ code: AppLocale) {
        appState.locale = code
        isPresented = false
    }

    private func dismissPopover() {
        isPresented = false
    }
}

private struct LocaleSwitcherPopoverContent: View {
    let currentLocale: AppLocale
    let onSelect: (AppLocale) -> Void
    let onDismiss: () -> Void

    @FocusState private var focusedCode: AppLocale?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 8) {
                FlagRow(
                    codes: AppLocale.row1,
                    currentLocale: currentLocale,
                    onSelect: onSelect,
                    focused: $focusedCode
                )
                FlagRow(
                    codes: AppLocale.row2,
                    currentLocale: currentLocale,
                    onSelect: onSelect,
                    focused: $focusedCode
                )
                FlagRow(
                    codes: AppLocale.row3,
                    currentLocale: currentLocale,
                    onSelect: onSelect,
                    focused: $focusedCode
                )
            }
            .padding()
        }
        .onAppear { focusedCode = currentLocale }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.leftArrow) { moveFocus(by: -1, vertical: false) }
        .onKeyPress(.rightArrow) { moveFocus(by: 1, vertical: false) }
        .onKeyPress(.upArrow) { moveFocus(by: -1, vertical: true) }
        .onKeyPress(.downArrow) { moveFocus(by: 1, vertical: true) }
    }

    private func moveFocus(by delta: Int, vertical: Bool) -> KeyPress.Result {
        guard let current = focusedCode else { return .ignored }
        if let next = LocaleSwitcherFocus.next(from: current, by: delta, vertical: vertical) {
            focusedCode = next
            return .handled
        }
        return .ignored
    }
}

private struct FlagRow: View {
    let codes: [AppLocale]
    let currentLocale: AppLocale
    let onSelect: (AppLocale) -> Void
    @FocusState.Binding var focused: AppLocale?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(codes) { code in
                FlagButton(
                    code: code,
                    currentLocale: currentLocale,
                    onSelect: onSelect
                )
                .focused($focused, equals: code)
            }
        }
    }
}

private struct FlagButton: View {
    let code: AppLocale
    let currentLocale: AppLocale
    let onSelect: (AppLocale) -> Void

    var body: some View {
        Button {
            onSelect(code)
        } label: {
            Text(verbatim: code.flagEmoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    LocaleSwitcherStyling.isSelected(code: code, current: currentLocale)
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear
                )
                .cornerRadius(8)
        }
        .accessibilityIdentifier("localeSwitcher.flag.\(code.rawValue)")
        .accessibilityLabel(
            LocaleSwitcherLabels.accessibilityLabel(for: code, current: currentLocale)
        )
        .accessibilityAddTraits(
            LocaleSwitcherStyling.isSelected(code: code, current: currentLocale)
                ? .isSelected
                : []
        )
    }
}
