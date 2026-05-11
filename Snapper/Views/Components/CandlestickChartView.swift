import Charts
import SwiftUI

/// Candlestick chart rendered with Apple's Swift Charts. Wick is
/// a ``RuleMark(yStart: low, yEnd: high)``; body is a
/// ``RectangleMark(yStart: min(open, close), yEnd: max(open,
/// close))``. Body fill: BrandGreen when ``close >= open``,
/// BrandRed otherwise. Grid color reads the asset-catalog
/// ``ChartGrid`` token (already defined in the project's
/// ``Assets.xcassets`` anticipating this work).
///
/// Decimal candle values cross the Charts boundary via
/// ``NSDecimalNumber.doubleValue`` — confined to this view so the
/// VM-side storage stays precision-clean.
struct CandlestickChartView: View {
    let candles: [MarketCandle]

    var body: some View {
        if candles.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.largeTitle)
                    .foregroundColor(.textSecondary)
                Text("No candles yet")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            chart
        }
    }

    /// Compute a tight Y-axis range from the actual candle highs
    /// and lows, padded by 1.5% on each side so the body+wick of
    /// extreme candles sit comfortably inside the chart frame.
    /// Without this, Swift Charts auto-scales from 0 which makes
    /// crypto-priced candles compress to a thin band.
    private var yAxisDomain: ClosedRange<Double> {
        let highs = candles.map { ($0.high as NSDecimalNumber).doubleValue }
        let lows = candles.map { ($0.low as NSDecimalNumber).doubleValue }
        guard let high = highs.max(), let low = lows.min(), high > low else {
            return 0 ... 1
        }
        let span = high - low
        let pad = max(span * 0.015, 0.0001)
        return (low - pad) ... (high + pad)
    }

    @ViewBuilder
    private var chart: some View {
        Chart(candles) { candle in
            let openD = (candle.open as NSDecimalNumber).doubleValue
            let highD = (candle.high as NSDecimalNumber).doubleValue
            let lowD = (candle.low as NSDecimalNumber).doubleValue
            let closeD = (candle.close as NSDecimalNumber).doubleValue
            let isUp = closeD >= openD
            let bodyColor: Color = isUp ? .brandGreen : .brandRed

            RuleMark(
                x: .value("Time", candle.openAt),
                yStart: .value("Low", lowD),
                yEnd: .value("High", highD)
            )
            .foregroundStyle(bodyColor.opacity(0.7))
            .lineStyle(StrokeStyle(lineWidth: 1.5))

            RectangleMark(
                x: .value("Time", candle.openAt),
                yStart: .value("Open or close", min(openD, closeD)),
                yEnd: .value("Open or close", max(openD, closeD)),
                width: .fixed(5)
            )
            .foregroundStyle(bodyColor)
            .cornerRadius(1)
        }
        .chartYScale(domain: yAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.chartGrid)
                AxisValueLabel(format: .dateTime.hour().minute(), centered: false)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(Color.chartGrid)
                AxisValueLabel().foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
}
