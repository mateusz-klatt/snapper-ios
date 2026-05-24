import SwiftUI

/// Flag-and-name locale picker that supersedes the previous
/// 3-rows-of-15 layout. Trigger is a chip showing the selected
/// country's flag, its autonym country name, and a chevron;
/// tapping opens a popover with a 15-row × 3-column vertically
/// scrollable grid. Each cell renders the flag and the
/// country's native name (``AppLocale/nativeCountryName``) so
/// users can disambiguate between flags whose regional-indicator
/// glyphs they do not recognise.
///
/// The transposed grid (15 rows × 3 cols) replaces the
/// 3-rows-of-15 layout because the previous content had to be
/// horizontally scrolled on every iPhone width — the right-most
/// columns were hidden behind a scroll affordance most users did
/// not discover. The transposed orientation fits any iPhone
/// portrait width without scrolling and pages vertically on the
/// smallest screens.
///
/// Selecting a row commits the new locale to ``AppState.locale``
/// (persisted under ``"snapper-locale"`` UserDefaults) and
/// dismisses the popover.
///
/// Keyboard navigation (iPad external keyboard, primary):
/// - Arrow keys move focus across the 15×3 grid via
///   ``LocaleSwitcherFocus/next(from:by:vertical:)``.
/// - Return / Space activate the focused ``Button`` (SwiftUI default).
/// - Escape dismisses the popover without committing.
struct LocaleSwitcher: View {
    @Environment(AppState.self) private var appState
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: appState.locale.flagEmoji)
                    .font(.title3)
                Text(verbatim: appState.locale.nativeCountryName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.bgSurface)
            )
        }
        .buttonStyle(.plain)
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(0..<LocaleSwitcherFocus.rowCount, id: \.self) { rowIdx in
                    LocaleRow(
                        codes: LocaleSwitcherFocus.rows[rowIdx],
                        currentLocale: currentLocale,
                        onSelect: onSelect,
                        focused: $focusedCode
                    )
                }
            }
            .padding(12)
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, minHeight: 360, idealHeight: 520)
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

private struct LocaleRow: View {
    let codes: [AppLocale]
    let currentLocale: AppLocale
    let onSelect: (AppLocale) -> Void
    @FocusState.Binding var focused: AppLocale?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(codes) { code in
                LocaleCell(
                    code: code,
                    currentLocale: currentLocale,
                    onSelect: onSelect
                )
                .focused($focused, equals: code)
            }
        }
    }
}

private struct LocaleCell: View {
    let code: AppLocale
    let currentLocale: AppLocale
    let onSelect: (AppLocale) -> Void

    var body: some View {
        Button {
            onSelect(code)
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: code.flagEmoji)
                    .font(.title3)
                Text(verbatim: code.nativeCountryName)
                    .font(.footnote)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LocaleSwitcherStyling.isSelected(code: code, current: currentLocale)
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
