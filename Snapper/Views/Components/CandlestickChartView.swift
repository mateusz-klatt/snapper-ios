import SwiftUI

/// Candlestick chart rendered with SwiftUI primitives
/// (``Canvas`` + ``Path``). Wick is a ``Path`` line stroke from
/// ``low`` to ``high``; body is a filled rounded ``Path`` from
/// ``min(open, close)`` to ``max(open, close)``. Body fill is
/// resolved at the view's body via
/// ``Color.financialRising(for: appState)`` /
/// ``Color.financialFalling(for: appState)`` so the rising/falling
/// convention follows the user's
/// ``FinancialColorPreference`` and locale.
///
/// We render the axes ourselves rather than using Apple's Swift
/// Charts (``Chart`` + ``RectangleMark`` + ``RuleMark``) because
/// iOS 26.2 ships a Charts regression that silently ignores
/// ``.foregroundStyle()`` for ``.red`` / ``.green`` semantic
/// colors on those marks, breaking the CN/HK/JP/KR
/// ``rising-red`` convention. The math is unit-tested in
/// ``NiceAxisTests`` and ``CandlestickGeometryTests``; the visual
/// rendering is verified by ``testCaptureChartColorVerification``.
/// See [[plan_2026_05_24_ios_v202_candlestick_primitive_rewrite]].
///
/// Decimal candle values cross the ``Double`` boundary via
/// ``NSDecimalNumber.doubleValue`` — confined to this view so the
/// VM-side storage stays precision-clean.
struct CandlestickChartView: View {
    let candles: [MarketCandle]
    /// Drives the X-axis label format. Hourly / daily candles
    /// labelled as ``HH:mm`` collapse to repeated ``00:00`` rows;
    /// the switch keeps the axis legible across the supported set.
    var timeframe: MarketTimeframe = .oneHour

    @Environment(AppState.self) private var appState
    @Environment(\.layoutDirection) private var layoutDirection

    private static let xAxisLabelHeight: CGFloat = 20
    private static let yAxisLabelWidth: CGFloat = 56
    private static let maxBodyWidth: CGFloat = 5
    private static let minBodyWidth: CGFloat = 1
    private static let bodySlotFraction: CGFloat = 0.7
    private static let bodyCornerRadius: CGFloat = 1
    private static let wickLineWidth: CGFloat = 1.5
    private static let gridLineWidth: CGFloat = 0.5
    private static let yAxisTickCount: Int = 5
    private static let xAxisTickCount: Int = 4

    /// Per-candle body width, computed from the candle slot width
    /// (``plotWidth / count``). Capped at ``maxBodyWidth`` (5pt)
    /// for sparse charts and floored at ``minBodyWidth`` (1pt)
    /// for very dense charts so bodies stay visible without
    /// overlapping their neighbors.
    private static func candleBodyWidth(plotWidth: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return maxBodyWidth }
        let slot = plotWidth / CGFloat(count)
        return min(max(slot * bodySlotFraction, minBodyWidth), maxBodyWidth)
    }

    var body: some View {
        if candles.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.largeTitle)
                    .foregroundColor(.textSecondary)
                Text(LocalizedStringKey("market.data.chart.emptyState"))
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            chart
        }
    }

    /// Pick a Date.FormatStyle appropriate to the chart's
    /// timeframe so X-axis labels stay legible. Intraday
    /// timeframes show ``HH:mm``; daily candles show ``MMM d``.
    ///
    /// Hour formatting forces 24-hour clock via
    /// ``.twoDigits(amPM: .omitted)`` regardless of locale —
    /// trading data uses 24h universally and the locale-default
    /// 12h fallback truncated the rightmost tick.
    ///
    /// The format style is pinned to ``AppLocale.westernDigitsLocale``
    /// so the X-axis renders Latin digits in ``ae``/``ir``/``in``
    /// rather than the locale's native digit set.
    private var xAxisFormat: Date.FormatStyle {
        let westernLocale = appState.locale.westernDigitsLocale
        switch timeframe {
        case .oneMinute, .fiveMinutes, .fifteenMinutes, .oneHour:
            return .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(westernLocale)
        case .fourHours:
            return .dateTime
                .month(.abbreviated)
                .day()
                .hour(.twoDigits(amPM: .omitted))
                .locale(westernLocale)
        case .oneDay:
            return .dateTime
                .month(.abbreviated)
                .day()
                .locale(westernLocale)
        }
    }

    /// Number format for the Y-axis price labels — pinned to
    /// ``AppLocale.westernDigitsLocale`` so the price ticks render
    /// Latin digits regardless of the locale's native digit set.
    private var yAxisFormat: FloatingPointFormatStyle<Double> {
        .number.locale(appState.locale.westernDigitsLocale)
    }

    /// ``true`` when the Y-axis labels should sit on the leading
    /// edge of the chart frame (RTL locales like ``ae`` / ``il``
    /// / ``ir``), ``false`` for the trailing edge (Western
    /// default). Honors both ``AppLocale.isRTL`` and the SwiftUI
    /// ``\.layoutDirection`` env.
    private var yAxisOnLeading: Bool {
        ChartRTLBehavior.yAxisEdge(
            locale: appState.locale,
            environmentLayout: layoutDirection
        ) == .leading
    }

    /// Y-axis domain computed by the Heckbert nice-number
    /// algorithm so tick labels land on round prices
    /// (e.g. ``76510, 76520, …, 76550``) rather than the raw
    /// data endpoints. Falls back to ``0...1`` when the candle
    /// set is empty — though the caller short-circuits the
    /// empty case before reaching here.
    private var niceDomain: NiceAxis {
        let highs = candles.map { ($0.high as NSDecimalNumber).doubleValue }
        let lows = candles.map { ($0.low as NSDecimalNumber).doubleValue }
        guard let high = highs.max(), let low = lows.min() else {
            return NiceAxis(lowerBound: 0, upperBound: 1, step: 1)
        }
        return niceAxis(min: low, max: high, tickCount: Self.yAxisTickCount)
    }

    /// Tick prices for the Y-axis, evaluated at every ``step``
    /// from ``lowerBound`` to ``upperBound``. Slack of
    /// ``step * 0.001`` on the upper bound absorbs floating-point
    /// drift so the top tick reliably appears.
    private static func yTicks(in domain: NiceAxis) -> [Double] {
        var ticks: [Double] = []
        var price = domain.lowerBound
        while price <= domain.upperBound + domain.step * 0.001 {
            ticks.append(price)
            price += domain.step
        }
        return ticks
    }

    /// Indices of the candles that get an X-axis label. When
    /// fewer than ``xAxisTickCount`` candles exist, every
    /// candle gets its own label; otherwise four labels are
    /// distributed evenly at ``0``, ``n/3``, ``2n/3`` and
    /// ``n - 1``.
    private static func xTickIndices(candleCount n: Int) -> [Int] {
        guard n > xAxisTickCount else { return Array(0..<n) }
        return [0, n / 3, (2 * n) / 3, n - 1]
    }

    @ViewBuilder
    private var chart: some View {
        let risingColor = Color.financialRising(for: appState)
        let fallingColor = Color.financialFalling(for: appState)
        let domain = niceDomain
        let yTicks = Self.yTicks(in: domain)
        let xTickIndices = Self.xTickIndices(candleCount: candles.count)
        let onLeading = yAxisOnLeading
        let yFormat = yAxisFormat
        let xFormat = xAxisFormat

        Canvas { ctx, size in
            let plotWidth = size.width - Self.yAxisLabelWidth
            let plotHeight = size.height - Self.xAxisLabelHeight
            guard plotWidth > 0, plotHeight > 0 else { return }
            let plotRect = CGRect(
                x: onLeading ? Self.yAxisLabelWidth : 0,
                y: 0,
                width: plotWidth,
                height: plotHeight
            )
            let yAxisRect = CGRect(
                x: onLeading ? 0 : size.width - Self.yAxisLabelWidth,
                y: 0,
                width: Self.yAxisLabelWidth,
                height: plotHeight
            )
            let xAxisRect = CGRect(
                x: 0,
                y: size.height - Self.xAxisLabelHeight,
                width: size.width,
                height: Self.xAxisLabelHeight
            )

            let bodyWidth = Self.candleBodyWidth(
                plotWidth: plotRect.width,
                count: candles.count
            )

            var plotCtx = ctx
            plotCtx.clip(to: Path(plotRect))

            for tickPrice in yTicks {
                let y = CandlestickGeometry.pixelY(
                    price: tickPrice,
                    domain: domain,
                    plotMinY: plotRect.minY,
                    plotMaxY: plotRect.maxY
                )
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: plotRect.minX, y: y))
                gridPath.addLine(to: CGPoint(x: plotRect.maxX, y: y))
                plotCtx.stroke(
                    gridPath,
                    with: .color(Color.chartGrid),
                    lineWidth: Self.gridLineWidth
                )
            }

            for (index, candle) in candles.enumerated() {
                let open = (candle.open as NSDecimalNumber).doubleValue
                let close = (candle.close as NSDecimalNumber).doubleValue
                let high = (candle.high as NSDecimalNumber).doubleValue
                let low = (candle.low as NSDecimalNumber).doubleValue
                let isUp = close >= open
                let bodyColor = isUp ? risingColor : fallingColor

                let (wickTop, wickBottom) = CandlestickGeometry.candleWickEndpoints(
                    index: index,
                    count: candles.count,
                    high: high,
                    low: low,
                    domain: domain,
                    plotRect: plotRect
                )
                var wickPath = Path()
                wickPath.move(to: wickTop)
                wickPath.addLine(to: wickBottom)
                plotCtx.stroke(
                    wickPath,
                    with: .color(bodyColor.opacity(0.7)),
                    lineWidth: Self.wickLineWidth
                )

                let bodyRect = CandlestickGeometry.candleBodyRect(
                    index: index,
                    count: candles.count,
                    open: open,
                    close: close,
                    domain: domain,
                    plotRect: plotRect,
                    bodyWidth: bodyWidth
                )
                let bodyPath = Path(
                    roundedRect: bodyRect,
                    cornerRadius: Self.bodyCornerRadius
                )
                plotCtx.fill(bodyPath, with: .color(bodyColor))
            }

            for tickPrice in yTicks {
                let y = CandlestickGeometry.pixelY(
                    price: tickPrice,
                    domain: domain,
                    plotMinY: plotRect.minY,
                    plotMaxY: plotRect.maxY
                )
                let label = Text(tickPrice.formatted(yFormat))
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
                let labelX = onLeading
                    ? yAxisRect.maxX - 4
                    : yAxisRect.minX + 4
                let anchor: UnitPoint = onLeading ? .trailing : .leading
                ctx.draw(
                    label,
                    at: CGPoint(x: labelX, y: y),
                    anchor: anchor
                )
            }

            for index in xTickIndices where index < candles.count {
                let centerX = CandlestickGeometry.pixelX(
                    index: index,
                    count: candles.count,
                    plotWidth: plotRect.width,
                    plotMinX: plotRect.minX
                )
                let candle = candles[index]
                let label = Text(candle.openAt.formatted(xFormat))
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
                ctx.draw(
                    label,
                    at: CGPoint(x: centerX, y: xAxisRect.midY),
                    anchor: .center
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
}
