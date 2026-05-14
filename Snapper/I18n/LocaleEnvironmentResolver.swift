import SwiftUI

/// Pure mappings from ``AppLocale`` to the SwiftUI environment
/// values that the app root applies: ``\.locale`` (drives
/// ``Text(LocalizedStringKey)`` resolution + Foundation date
/// formatters) and ``\.layoutDirection`` (flips chrome to RTL
/// for Arabic / Hebrew / Persian country codes).
///
/// Extracted from ``SnapperApp`` so the mapping is unit-testable
/// without rendering the SwiftUI body. The pattern matches
/// ``MainTabView/routeDeepLink(...)`` which is unit-tested as a
/// pure function for the same reason (ViewInspector is not
/// available in this project).
enum LocaleEnvironmentResolver {

    /// Foundation ``Locale`` for the SwiftUI ``\.locale``
    /// environment. Delegates to ``AppLocale/nativeLocale`` —
    /// kept as a separate helper so the test surface is named
    /// after the environment slot it feeds.
    static func environmentLocale(for code: AppLocale) -> Locale {
        code.nativeLocale
    }

    /// SwiftUI ``LayoutDirection`` for the ``\.layoutDirection``
    /// environment. Returns ``.rightToLeft`` for the RTL country
    /// codes locked by ``AppLocale/isRTL`` (``.ae``, ``.il``,
    /// ``.ir``), ``.leftToRight`` otherwise.
    static func layoutDirection(for code: AppLocale) -> LayoutDirection {
        code.isRTL ? .rightToLeft : .leftToRight
    }
}
