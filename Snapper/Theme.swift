import SwiftUI

extension Color {
    /// SEVERITY semantics — success / positive outcome. Stays green
    /// regardless of financial color convention. Use for "filled
    /// order" status, success toasts, healthy state indicators.
    static let profitGreen = Color.green

    /// SEVERITY semantics — error / negative outcome. Stays red
    /// regardless of financial color convention. Use for "rejected
    /// order" status, error toasts, unhealthy state, destructive
    /// actions.
    static let lossRed = Color.red

    /// FINANCIAL DIRECTION — "up" / "rising" / "buy" / "gain".
    ///
    /// Resolves through ``AppState.financialColorPreference`` and the
    /// active ``locale``: defaults to green for Western users, red
    /// for cn/hk/jp/kr users on the ``.auto`` preference, and honors
    /// an explicit Settings choice. Use ONLY for market-direction
    /// surfaces (BUY side, P&L numbers, candle up colors,
    /// backtest delta positive). Severity / state / success UI
    /// should keep ``profitGreen`` / ``lossRed``.
    @MainActor
    static func financialRising(for appState: AppState) -> Color {
        let effective = resolveFinancialColorConvention(
            preference: appState.financialColorPreference,
            locale: appState.locale
        )
        return effective == .risingRed ? .lossRed : .profitGreen
    }

    /// FINANCIAL DIRECTION — "down" / "falling" / "sell" / "loss".
    /// Inverse of ``financialRising(for:)``; same fallback chain.
    @MainActor
    static func financialFalling(for appState: AppState) -> Color {
        let effective = resolveFinancialColorConvention(
            preference: appState.financialColorPreference,
            locale: appState.locale
        )
        return effective == .risingRed ? .profitGreen : .lossRed
    }
}
