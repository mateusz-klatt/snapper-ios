import SwiftUI

/// Native P&L timeline surface hosted as the second segment of
/// ``PositionsView`` (``GET /api/portfolio/pnl/series``).
///
/// Read-only v1: window / granularity / valuation-currency controls, a
/// hand-rolled three-series line chart, an incompleteness summary, and
/// the latest point's attribution + per-instrument contribution
/// tables. No decision markers, no interaction, no live telemetry. The
/// wallet selection is inherited from the ``WalletPicker`` in the
/// shared ``PositionsView`` toolbar.
///
/// Withheld (``nil``) monetary values are never rendered as zero: the
/// chart shows gaps, the attribution table shows "Withheld", and the
/// contribution table shows "—". A displayed zero is a proven zero.
struct PnlTimelineView: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel: PnlTimelineViewModel?

    var body: some View {
        Group {
            if let viewModel {
                PnlTimelineContent(viewModel: viewModel)
            } else {
                ProgressView(LocalizedStringKey("positions.timeline.loading"))
                    .frame(maxWidth: .infinity, minHeight: 360)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = PnlTimelineViewModel(appState: appState)
            }
        }
    }
}

/// Typed, ``Hashable`` load key. The load ``task`` re-runs exactly once
/// per distinct (wallet, window, granularity, valuation currency)
/// combination, so there is one fetch per appearance and one per
/// control change — and never a first-appearance double fetch, because
/// the keyed task is attached to the child that only exists once the
/// ViewModel has been created.
struct PnlTimelineLoadKey: Hashable {
    let wallet: String?
    let window: PnlTimelineWindow
    let granularity: PnlTimelineGranularity
    let valuationCcy: String
}

/// Rendered surface once the ViewModel exists. Split from
/// ``PnlTimelineView`` so the control pickers can bind through
/// ``@Bindable`` (whose ``didSet`` drives re-anchoring / coarsening)
/// without constructing a ``@MainActor`` ViewModel in a ``@State``
/// default initializer.
private struct PnlTimelineContent: View {

    @Bindable var viewModel: PnlTimelineViewModel
    @Environment(AppState.self) private var appState

    private var loadKey: PnlTimelineLoadKey {
        return PnlTimelineLoadKey(
            wallet: appState.selectedWalletPublicId,
            window: viewModel.window,
            granularity: viewModel.granularity,
            valuationCcy: viewModel.valuationCcy
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controls
                content
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgBase)
        .refreshable { await viewModel.load() }
        .task(id: loadKey) { await viewModel.load() }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker(LocalizedStringKey("positions.timeline.controls.window"), selection: $viewModel.window) {
                ForEach(PnlTimelineWindow.allCases) { window in
                    Text(LocalizedStringKey(window.titleKey)).tag(window)
                }
            }
            .pickerStyle(.menu)
            Picker(LocalizedStringKey("positions.timeline.controls.granularity"), selection: $viewModel.granularity) {
                ForEach(PnlTimelineGranularity.allCases) { granularity in
                    Text(verbatim: granularity.wireValue).tag(granularity)
                }
            }
            .pickerStyle(.menu)
            Picker(LocalizedStringKey("positions.timeline.controls.valuationCurrency"), selection: $viewModel.valuationCcy) {
                ForEach(PnlTimelineViewModel.valuationCurrencies, id: \.self) { code in
                    Text(verbatim: code).tag(code)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var content: some View {
        if appState.selectedWalletPublicId == nil {
            stateView(
                titleKey: "positions.timeline.noWallet.title",
                messageKey: "positions.timeline.noWallet.message",
                systemImage: "wallet.bifold"
            )
        } else if let data = viewModel.freshData {
            loadedContent(data)
        } else if PnlTimelineViewModel.shouldShowLoadError(
            hasData: false,
            loadError: viewModel.currentError,
            isLoading: viewModel.isLoading
        ), let error = viewModel.currentError {
            errorView(error)
        } else {
            ProgressView(LocalizedStringKey("positions.timeline.loading"))
                .frame(maxWidth: .infinity, minHeight: 360)
        }
    }

    private func loadedContent(_ data: PnlSeriesData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let error = viewModel.currentError {
                inlineErrorBanner(error)
            }
            loadedBody(data)
        }
    }

    /// The empty-vs-populated split. The inline refresh-error banner is
    /// rendered by ``loadedContent(_:)`` OUTSIDE this split so a
    /// same-parameters refresh failure surfaces even when the cached
    /// response itself has zero points.
    @ViewBuilder
    private func loadedBody(_ data: PnlSeriesData) -> some View {
        if data.points.isEmpty {
            stateView(
                titleKey: "positions.timeline.empty.title",
                messageKey: "positions.timeline.empty.message",
                systemImage: "chart.xyaxis.line"
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.incompleteCount > 0 {
                    PnlIncompletenessSection(
                        groups: viewModel.incompletenessGroups,
                        incompleteCount: viewModel.incompleteCount
                    )
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey("positions.timeline.chart.title"))
                        .font(.headline)
                    PnlLineChartView(points: data.points, valuationCcy: data.valuationCcy)
                }
                .padding()
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                if let latest = viewModel.latestPoint {
                    PnlAttributionSection(attribution: latest.attribution, valuationCcy: data.valuationCcy)
                    PnlContributionSection(contributions: latest.perInstrument, valuationCcy: data.valuationCcy)
                }
            }
        }
    }

    /// Inline banner surfaced OVER live data when a same-parameters
    /// refresh fails — the actionable server detail (e.g. a work-budget
    /// 400) is shown without discarding the cached series.
    private func inlineErrorBanner(_ error: APIError) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color.lossRed)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("positions.timeline.error.title"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                errorDescription(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(LocalizedStringKey("common.retry")) {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.lossRed.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorView(_ error: APIError) -> some View {
        ContentUnavailableView {
            Label(LocalizedStringKey("positions.timeline.error.title"), systemImage: "exclamationmark.triangle")
        } description: {
            errorDescription(error)
        } actions: {
            Button(LocalizedStringKey("common.retry")) {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    @ViewBuilder
    private func errorDescription(_ error: APIError) -> some View {
        if case .serverError(let detail) = error {
            Text(verbatim: detail)
        } else {
            Text(LocalizedStringKey("positions.timeline.error.message"))
        }
    }

    private func stateView(titleKey: String, messageKey: String, systemImage: String) -> some View {
        ContentUnavailableView(
            LocalizedStringKey(titleKey),
            systemImage: systemImage,
            description: Text(LocalizedStringKey(messageKey))
        )
        .frame(maxWidth: .infinity, minHeight: 360)
    }
}

/// Direction-aware color for a P&L value: rising for positive, falling
/// for negative, secondary for a proven zero or a withheld ``nil``.
@MainActor
private func pnlValueColor(_ value: Double?, appState: AppState) -> Color {
    guard let value, value != 0 else { return .secondary }
    return value > 0 ? Color.financialRising(for: appState) : Color.financialFalling(for: appState)
}

/// Section header: localized title plus a verbatim valuation-currency
/// badge (the response's echoed currency, the display source of truth).
private struct PnlSectionHeader: View {
    let titleKey: String
    let valuationCcy: String

    var body: some View {
        HStack(spacing: 8) {
            Text(LocalizedStringKey(titleKey))
                .font(.headline)
            Text(verbatim: valuationCcy)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

/// Withholding summary — shown only when at least one point is
/// incomplete. Groups reasons across the loaded window (ported from
/// the web ``IncompletenessSummary``).
private struct PnlIncompletenessSection: View {
    let groups: [PnlIncompletenessGroup]
    let incompleteCount: Int

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("positions.timeline.incompleteness.title"))
                        .font(.headline)
                    Text(LocalizedStringKey("positions.timeline.incompleteness.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(verbatim: String(
                    format: LocaleStrings.localized("positions.timeline.incompleteBadge", in: appState.locale.catalogLanguage),
                    locale: appState.locale.westernDigitsLocale,
                    incompleteCount
                ))
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }
            ForEach(groups) { group in
                PnlIncompletenessRow(group: group)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// One grouped withholding reason row: reason label, tier chip, scope
/// label, optional trigger instrument, and affected-point count.
private struct PnlIncompletenessRow: View {
    let group: PnlIncompletenessGroup

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey(reasonKey))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    tierChip
                }
                HStack(spacing: 12) {
                    Text(LocalizedStringKey(scopeKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let triggerText {
                        Text(verbatim: triggerText)
                            .font(.caption)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text(verbatim: String(
                format: LocaleStrings.localized("positions.timeline.incompleteness.affectedPoints", in: appState.locale.catalogLanguage),
                locale: appState.locale.westernDigitsLocale,
                group.affectedPointCount
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var reasonKey: String {
        return "positions.timeline.incompleteness.reasons.\(group.reason.reason.rawValue)"
    }

    private var scopeKey: String {
        return group.reason.withholdingScope == .global
            ? "positions.timeline.incompleteness.scope.global"
            : "positions.timeline.incompleteness.scope.instrument"
    }

    private var tierChip: some View {
        let isMarkIncomplete = group.reason.withholdingTier == .markIncomplete
        let key = isMarkIncomplete
            ? "positions.timeline.incompleteness.tier.mark_incomplete"
            : "positions.timeline.incompleteness.tier.untrusted"
        let tint = isMarkIncomplete ? Color.orange : Color.lossRed
        return Text(LocalizedStringKey(key))
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private var triggerText: String? {
        guard let triggerId = group.reason.triggerInstrumentPublicId else { return nil }
        let instrument = group.triggerContribution.map { PnlTimelineViewModel.instrumentIdentity($0) } ?? triggerId
        return String(
            format: LocaleStrings.localized("positions.timeline.incompleteness.triggerInstrument", in: appState.locale.catalogLanguage),
            locale: appState.locale.westernDigitsLocale,
            instrument
        )
    }
}

/// Latest-point origin/strategy attribution. Rows are ordered
/// manual → plan → system → unattributed. Withheld values render as
/// "Withheld" (proven-zero vs withheld is a core product semantic).
private struct PnlAttributionSection: View {
    let attribution: [PnlAttributionContributionData]
    let valuationCcy: String

    @Environment(AppState.self) private var appState

    private var sorted: [PnlAttributionContributionData] {
        return attribution.sorted { Self.originRank($0.origin) < Self.originRank($1.origin) }
    }

    private static func originRank(_ origin: PnlAttributionOrigin) -> Int {
        switch origin {
        case .manual: return 0
        case .plan: return 1
        case .system: return 2
        case .unattributed: return 3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PnlSectionHeader(titleKey: "positions.timeline.attribution.title", valuationCcy: valuationCcy)
            Text(LocalizedStringKey("positions.timeline.attribution.valueSemantics"))
                .font(.caption)
                .foregroundStyle(.secondary)
            if sorted.isEmpty {
                Text(LocalizedStringKey("positions.timeline.attribution.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                /// These tables are WIDER than an iPhone: the last
                /// column (fees on attribution, net on contributions)
                /// falls off the right edge on a 6.3" screen. They have
                /// always scrolled, but with the indicator suppressed
                /// there was nothing telling the reader a value was cut
                /// off rather than malformed. Indicators are shown, and
                /// pinned visible so the affordance survives the idle
                /// state a screenshot captures — matching the wide
                /// tables in ``AccountsView``.
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            headerCell("positions.timeline.attribution.origin")
                            headerCell("positions.timeline.contributions.realized")
                            headerCell("positions.timeline.contributions.fees")
                            headerCell("positions.timeline.contributions.accrual")
                            headerCell("positions.timeline.contributions.unrealized")
                        }
                        ForEach(Array(sorted.enumerated()), id: \.offset) { _, row in
                            GridRow {
                                originCell(row)
                                valueCell(row.realizedPnl)
                                valueCell(row.feePnl)
                                valueCell(row.accrualPnl)
                                valueCell(row.unrealizedPnl)
                            }
                        }
                    }
                }
                .scrollIndicators(.visible)
            }
        }
        .padding()
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func headerCell(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func originCell(_ row: PnlAttributionContributionData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(Self.originKey(row.origin)))
                .font(.subheadline)
                .fontWeight(.medium)
            if let strategy = row.strategyName {
                Text(verbatim: strategy)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(LocalizedStringKey("positions.timeline.attribution.noStrategy"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func valueCell(_ value: Double?) -> some View {
        if let value {
            Text(verbatim: value.formattedSignedPnl(in: appState.locale))
                .font(.caption.monospacedDigit())
                .foregroundStyle(pnlValueColor(value, appState: appState))
        } else {
            Text(LocalizedStringKey("positions.timeline.attribution.withheld"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private static func originKey(_ origin: PnlAttributionOrigin) -> String {
        switch origin {
        case .manual: return "positions.timeline.attribution.origins.manual"
        case .plan: return "positions.timeline.attribution.origins.plan"
        case .system: return "positions.timeline.attribution.origins.system"
        case .unattributed: return "positions.timeline.attribution.origins.unattributed"
        }
    }
}

/// Latest-point per-instrument contributions with a client-computed
/// Net column (sum of the four fields only when all are present). A
/// withheld value renders as "—" (verbatim), never zero.
private struct PnlContributionSection: View {
    let contributions: [PnlInstrumentContributionData]
    let valuationCcy: String

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PnlSectionHeader(titleKey: "positions.timeline.contributions.title", valuationCcy: valuationCcy)
            if contributions.isEmpty {
                Text(LocalizedStringKey("positions.timeline.contributions.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                /// These tables are WIDER than an iPhone: the last
                /// column (fees on attribution, net on contributions)
                /// falls off the right edge on a 6.3" screen. They have
                /// always scrolled, but with the indicator suppressed
                /// there was nothing telling the reader a value was cut
                /// off rather than malformed. Indicators are shown, and
                /// pinned visible so the affordance survives the idle
                /// state a screenshot captures — matching the wide
                /// tables in ``AccountsView``.
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            headerCell("positions.timeline.contributions.instrument")
                            headerCell("positions.timeline.contributions.realized")
                            headerCell("positions.timeline.contributions.fees")
                            headerCell("positions.timeline.contributions.accrual")
                            headerCell("positions.timeline.contributions.unrealized")
                            headerCell("positions.timeline.contributions.net")
                        }
                        ForEach(Array(contributions.enumerated()), id: \.offset) { _, row in
                            GridRow {
                                Text(verbatim: PnlTimelineViewModel.instrumentIdentity(row))
                                    .font(.caption.monospaced())
                                valueCell(row.realizedPnl)
                                valueCell(row.feePnl)
                                valueCell(row.accrualPnl)
                                valueCell(row.unrealizedPnl)
                                valueCell(PnlTimelineViewModel.contributionNet(row))
                            }
                        }
                    }
                }
                .scrollIndicators(.visible)
            }
        }
        .padding()
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func headerCell(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func valueCell(_ value: Double?) -> some View {
        if let value {
            Text(verbatim: value.formattedSignedPnl(in: appState.locale))
                .font(.caption.monospacedDigit())
                .foregroundStyle(pnlValueColor(value, appState: appState))
        } else {
            Text(verbatim: "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
