import Foundation

/// Pure styling decisions for ``LocaleSwitcher`` flag buttons.
/// Extracted so the selection-background flag is unit-testable
/// without rendering SwiftUI bodies (the repo pattern from
/// ``MainTabView/routeDeepLink(...)``).
enum LocaleSwitcherStyling {

    /// Whether a flag button should render the selected-state
    /// background tint. Currently a plain identity check; kept as a
    /// helper so future selection-state logic (e.g. recent history,
    /// regional grouping) has a single seam.
    static func isSelected(code: AppLocale, current: AppLocale) -> Bool {
        code == current
    }
}
