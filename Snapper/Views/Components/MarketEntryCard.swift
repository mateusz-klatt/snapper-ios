import SwiftUI

/// Tap-target shown on ``HomeView`` for users with
/// ``Permission.READ_MARKET_DATA``. Visual style matches the
/// existing Home cards (BGSurface fill, 12pt corner radius).
/// The "uptrend" affordance icon is tinted via
/// ``Color.financialRising(for:)`` so its rising-cue color flips
/// under East-Asian convention rather than always reading as
/// Western "green = up".
struct MarketEntryCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let risingColor = Color.financialRising(for: appState)
        HStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundColor(risingColor)
                .frame(width: 44, height: 44)
                .background(risingColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("market.data.navTitle"))
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(LocalizedStringKey("market.entry.subtitle"))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundColor(.textSecondary)
        }
        .padding(14)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
