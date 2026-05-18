import SwiftUI

/// 2x2 grid of KPI cards: last price, 24h %Δ, 24h high, 24h low.
/// Each card uses ``MarketMetricCard`` for consistent styling.
struct MarketMetricGrid: View {
    let metrics: MarketMetrics

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        LazyVGrid(columns: columns, spacing: 12) {
            MarketMetricCard(
                label: "market.data.metric.lastPrice",
                value: formatPrice(metrics.lastPrice),
                delta: nil
            )
            MarketMetricCard(
                label: "market.data.metric.change24h",
                value: formatPercent(metrics.changePct24h),
                delta: metrics.changePct24h
            )
            MarketMetricCard(
                label: "market.data.metric.high",
                value: formatPrice(metrics.high24h),
                delta: nil
            )
            MarketMetricCard(
                label: "market.data.metric.low",
                value: formatPrice(metrics.low24h),
                delta: nil
            )
        }
    }

    private func formatPrice(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return Self.priceFormatter.string(from: value as NSDecimalNumber) ?? "—"
    }

    private func formatPercent(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        let sign = value >= 0 ? "+" : ""
        let body = Self.percentFormatter.string(from: value as NSDecimalNumber) ?? "—"
        return "\(sign)\(body)%"
    }

    /// Cached formatters reused across every metric refresh. The
    /// chart re-renders on each WS frame (subject to the
    /// 200 ms leading-edge throttle); re-allocating
    /// ``NumberFormatter`` per call would dominate the render path
    /// during an active stream.
    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 6
        f.numberStyle = .decimal
        return f
    }()

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.numberStyle = .decimal
        return f
    }()
}

/// Reusable KPI tile. The optional ``delta`` controls the value's
/// color tint via ``Color.financialRising(for:)`` /
/// ``Color.financialFalling(for:)`` so the 24h %Δ value flips
/// red/green under East-Asian convention (cn/hk/jp/kr or explicit
/// rising-red setting). Neutral when ``nil``.
struct MarketMetricCard: View {
    let label: String
    let value: String
    let delta: Decimal?

    @Environment(AppState.self) private var appState

    private var valueColor: Color {
        guard let delta else { return .textPrimary }
        return delta >= 0 ? .financialRising(for: appState) : .financialFalling(for: appState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundColor(.textSecondary)
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Status row below the chart. Surfaces:
/// - "Delayed data" pill when ``isDelayed == true`` on the
///   latest ``TickData`` frame.
/// - Loading / error indicators driven by the VM.
/// - "Live" badge when ``isReady`` is true and no error is
///   present.
struct MarketStatusRow: View {
    let isDelayed: Bool
    let isReady: Bool
    let isLoading: Bool
    let loadError: APIError?

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView().controlSize(.small)
                Text(LocalizedStringKey("common.loading"))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            } else if let loadError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.brandRed)
                Text(loadError.errorDescription ?? "Failed to load")
                    .font(.caption)
                    .foregroundColor(.brandRed)
                    .lineLimit(2)
            } else if isReady {
                Circle()
                    .fill(Color.brandGreen)
                    .frame(width: 8, height: 8)
                Text(LocalizedStringKey("market.data.status.live"))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if isDelayed {
                Text(LocalizedStringKey("market.data.status.delayed"))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.brandRed.opacity(0.15))
                    .foregroundColor(.brandRed)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
