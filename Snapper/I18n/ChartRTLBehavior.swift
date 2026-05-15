import SwiftUI

/// Compute chart axis-orientation behavior for the candlestick chart.
///
/// Returns the trailing edge for LTR locales and the leading edge for
/// RTL locales. Used by ``CandlestickChartView`` to mirror chart
/// chronology when the layout direction is RTL.
///
/// The locked RTL country set is ``{.ae, .il, .ir}``. The current
/// catalog language is always ``.en`` for those countries (since none
/// of them map to a Polish translation), so this helper exists
/// primarily for future RTL languages (Arabic / Hebrew / Persian)
/// while the env-level ``LayoutDirection.rightToLeft`` is honored today
/// for accessibility / RTL-test purposes.
enum ChartRTLBehavior {

    /// True when EITHER the locale's country is in the RTL set OR the
    /// SwiftUI environment layout direction signals RTL.
    static func isRTL(locale: AppLocale, environmentLayout: LayoutDirection) -> Bool {
        if locale.isRTL { return true }
        if environmentLayout == .rightToLeft { return true }
        return false
    }

    /// Edge alignment for the y-axis: leading for RTL, trailing for LTR.
    static func yAxisEdge(locale: AppLocale, environmentLayout: LayoutDirection) -> Edge {
        return isRTL(locale: locale, environmentLayout: environmentLayout) ? .leading : .trailing
    }
}
