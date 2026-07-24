import SwiftUI

/// Hand-rolled P&L line chart rendered with SwiftUI ``Canvas`` +
/// ``Path`` — three series (net / realized / unrealized cumulative
/// P&L) drawn as distinct-color lines with a shared Y domain.
///
/// Swift Charts is deliberately avoided: iOS 26.2 ships a Charts
/// regression that silently ignores ``.foregroundStyle()`` for
/// semantic ``.red`` / ``.green`` colors on marks (see
/// ``CandlestickChartView``). The Y-axis nice-number math is
/// ``NiceAxis`` and the pure geometry is ``PnlChartGeometry`` (both
/// unit-tested).
///
/// The three line colors encode SERIES IDENTITY, not market direction,
/// so they intentionally do NOT use
/// ``Color/financialRising(for:)`` / ``financialFalling(for:)``.
/// Withheld (``nil``) values render as GAPS: each series is split into
/// contiguous non-nil runs FIRST and decimated only WITHIN each run
/// (``PnlChartGeometry/renderRuns(values:maxSamples:)``), so a withheld
/// interval is never joined into a continuous line and each run's
/// endpoints always survive.
///
/// The render model (per-series runs + shared domain) is built ONCE per
/// ``body`` evaluation and reused by both the canvas and the legend;
/// ``body`` re-evaluates only when the data or environment changes, so
/// this is effectively one build per data change.
struct PnlLineChartView: View {
    let points: [PnlTimelinePointData]
    /// Currency the series is expressed in — the RESPONSE's
    /// ``valuation_ccy`` echo, rendered verbatim in the legend.
    let valuationCcy: String

    @Environment(AppState.self) private var appState
    @Environment(\.layoutDirection) private var layoutDirection

    private static let netColor = Color.accentColor
    private static let realizedColor = Color.orange
    private static let unrealizedColor = Color.teal

    private static let chartHeight: CGFloat = 300
    private static let xAxisLabelHeight: CGFloat = 20
    private static let yAxisLabelWidth: CGFloat = 64
    private static let lineWidth: CGFloat = 2
    private static let gridLineWidth: CGFloat = 0.5
    private static let dotRadius: CGFloat = 1.5
    private static let yAxisTickCount: Int = 5
    private static let xAxisTickCount: Int = 4
    private static let intradayThreshold: TimeInterval = 2 * 24 * 60 * 60

    /// One series, preprocessed once: its aligned values, its color /
    /// legend key, and its gap-preserving decimated runs (original
    /// point indices).
    private struct SeriesRender {
        let values: [Double?]
        let color: Color
        let nameKey: String
        let runs: [[Int]]
    }

    private struct RenderModel {
        let series: [SeriesRender]
        let domain: NiceAxis
    }

    /// Build the full render model in a single pass: extract the three
    /// value arrays once, derive the shared nice-number domain from all
    /// non-nil values, then compute each series' decimated runs.
    private func makeRenderModel() -> RenderModel {
        let specs: [(values: [Double?], color: Color, nameKey: String)] = [
            (points.map(\.netPnl), Self.netColor, "positions.timeline.chart.net"),
            (points.map(\.realizedPnl), Self.realizedColor, "positions.timeline.chart.realized"),
            (points.map(\.unrealizedPnl), Self.unrealizedColor, "positions.timeline.chart.unrealized"),
        ]
        var low: Double?
        var high: Double?
        for spec in specs {
            for value in spec.values {
                guard let value else { continue }
                low = low.map { Swift.min($0, value) } ?? value
                high = high.map { Swift.max($0, value) } ?? value
            }
        }
        let domain: NiceAxis
        if let low, let high {
            domain = niceAxis(min: low, max: high, tickCount: Self.yAxisTickCount)
        } else {
            domain = NiceAxis(lowerBound: -1, upperBound: 1, step: 1)
        }
        let series = specs.map { spec in
            SeriesRender(
                values: spec.values,
                color: spec.color,
                nameKey: spec.nameKey,
                runs: PnlChartGeometry.renderRuns(
                    values: spec.values,
                    maxSamples: PnlChartGeometry.defaultMaxSamples
                )
            )
        }
        return RenderModel(series: series, domain: domain)
    }

    private static func yTicks(in domain: NiceAxis) -> [Double] {
        var ticks: [Double] = []
        var value = domain.lowerBound
        while value <= domain.upperBound + domain.step * 0.001 {
            ticks.append(value)
            value += domain.step
        }
        return ticks
    }

    private static func xTickIndices(count: Int) -> [Int] {
        guard count > xAxisTickCount else { return Array(0..<count) }
        return [0, count / 3, (2 * count) / 3, count - 1]
    }

    private var yAxisOnLeading: Bool {
        ChartRTLBehavior.yAxisEdge(
            locale: appState.locale,
            environmentLayout: layoutDirection
        ) == .leading
    }

    private var xAxisFormat: Date.FormatStyle {
        let westernLocale = appState.locale.westernDigitsLocale
        let span: TimeInterval
        if let first = points.first?.pointTime, let last = points.last?.pointTime {
            span = last.timeIntervalSince(first)
        } else {
            span = 0
        }
        if span <= Self.intradayThreshold {
            return .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(westernLocale)
        }
        return .dateTime
            .month(.abbreviated)
            .day()
            .locale(westernLocale)
    }

    var body: some View {
        let model = makeRenderModel()
        return VStack(alignment: .leading, spacing: 12) {
            canvas(model)
                .frame(height: Self.chartHeight)
            legend(model.series)
        }
    }

    private func canvas(_ model: RenderModel) -> some View {
        let domain = model.domain
        let yTicks = Self.yTicks(in: domain)
        let xTickIndices = Self.xTickIndices(count: points.count)
        let onLeading = yAxisOnLeading
        let yFormat = FloatingPointFormatStyle<Double>.number.locale(appState.locale.westernDigitsLocale)
        let xFormat = xAxisFormat
        let series = model.series

        return Canvas { ctx, size in
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
            let xAxisMidY = size.height - Self.xAxisLabelHeight / 2

            for tickValue in yTicks {
                let y = PnlChartGeometry.pixelY(
                    value: tickValue,
                    domain: domain,
                    plotMinY: plotRect.minY,
                    plotMaxY: plotRect.maxY
                )
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: plotRect.minX, y: y))
                gridPath.addLine(to: CGPoint(x: plotRect.maxX, y: y))
                ctx.stroke(gridPath, with: .color(Color.chartGrid), lineWidth: Self.gridLineWidth)
            }

            var plotCtx = ctx
            plotCtx.clip(to: Path(plotRect))
            for line in series {
                drawSeries(line, domain: domain, plotRect: plotRect, context: &plotCtx)
            }

            for tickValue in yTicks {
                let y = PnlChartGeometry.pixelY(
                    value: tickValue,
                    domain: domain,
                    plotMinY: plotRect.minY,
                    plotMaxY: plotRect.maxY
                )
                let label = Text(verbatim: tickValue.formatted(yFormat))
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
                let labelX = onLeading ? yAxisRect.maxX - 4 : yAxisRect.minX + 4
                let anchor: UnitPoint = onLeading ? .trailing : .leading
                ctx.draw(label, at: CGPoint(x: labelX, y: y), anchor: anchor)
            }

            for index in xTickIndices where index < points.count {
                let centerX = PnlChartGeometry.pixelX(
                    index: index,
                    count: points.count,
                    plotMinX: plotRect.minX,
                    plotWidth: plotRect.width
                )
                let label = Text(verbatim: points[index].pointTime.formatted(xFormat))
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
                ctx.draw(label, at: CGPoint(x: centerX, y: xAxisMidY), anchor: .center)
            }
        }
    }

    private func drawSeries(
        _ series: SeriesRender,
        domain: NiceAxis,
        plotRect: CGRect,
        context: inout GraphicsContext
    ) {
        for run in series.runs {
            if run.count == 1 {
                guard let value = series.values[run[0]] else { continue }
                let point = pixelPoint(index: run[0], value: value, domain: domain, plotRect: plotRect)
                let dot = Path(ellipseIn: CGRect(
                    x: point.x - Self.dotRadius,
                    y: point.y - Self.dotRadius,
                    width: Self.dotRadius * 2,
                    height: Self.dotRadius * 2
                ))
                context.fill(dot, with: .color(series.color))
                continue
            }
            var path = Path()
            var started = false
            for index in run {
                guard let value = series.values[index] else { continue }
                let point = pixelPoint(index: index, value: value, domain: domain, plotRect: plotRect)
                if started {
                    path.addLine(to: point)
                } else {
                    path.move(to: point)
                    started = true
                }
            }
            context.stroke(path, with: .color(series.color), lineWidth: Self.lineWidth)
        }
    }

    private func pixelPoint(
        index: Int,
        value: Double,
        domain: NiceAxis,
        plotRect: CGRect
    ) -> CGPoint {
        let x = PnlChartGeometry.pixelX(
            index: index,
            count: points.count,
            plotMinX: plotRect.minX,
            plotWidth: plotRect.width
        )
        let y = PnlChartGeometry.pixelY(
            value: value,
            domain: domain,
            plotMinY: plotRect.minY,
            plotMaxY: plotRect.maxY
        )
        return CGPoint(x: x, y: y)
    }

    private func legend(_ series: [SeriesRender]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                ForEach(series.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(series[index].color)
                            .frame(width: 14, height: 4)
                        Text(LocalizedStringKey(series[index].nameKey))
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            Text(verbatim: String(
                format: LocaleStrings.localized(
                    "positions.timeline.chart.valuationCurrency",
                    in: appState.locale.catalogLanguage
                ),
                locale: appState.locale.westernDigitsLocale,
                valuationCcy
            ))
            .font(.caption2)
            .foregroundStyle(Color.textSecondary)
        }
    }
}
