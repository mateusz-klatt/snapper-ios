import SwiftUI

/// Read-only venue cash balances and open positions with fail-closed truth labels.
struct AccountsView: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel: AccountsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.isLoading && viewModel.filteredAccounts.isEmpty {
                        ProgressView(LocalizedStringKey("accounts.loading"))
                    } else if AccountsViewModel.shouldShowLoadError(
                        filteredCount: viewModel.filteredAccounts.count,
                        loadError: viewModel.loadError,
                        isLoading: viewModel.isLoading
                    ) {
                        ContentUnavailableView(
                            LocalizedStringKey("accounts.unavailable.title"),
                            systemImage: "exclamationmark.triangle",
                            description: Text(LocalizedStringKey("accounts.unavailable.message"))
                        )
                        .overlay(alignment: .bottom) {
                            Button(LocalizedStringKey("common.retry")) {
                                Task { await viewModel.load() }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                    } else if viewModel.filteredAccounts.isEmpty {
                        ContentUnavailableView(
                            LocalizedStringKey("accounts.empty.title"),
                            systemImage: "building.columns",
                            description: Text(LocalizedStringKey("accounts.empty.message"))
                        )
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            accountList(viewModel: viewModel, now: context.date)
                        }
                    }
                } else {
                    ProgressView(LocalizedStringKey("accounts.loading"))
                }
            }
            .navigationTitle(LocalizedStringKey("accounts.page.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    WalletPicker()
                }
            }
        }
        .task(id: appState.selectedWalletPublicId) {
            if viewModel == nil {
                viewModel = AccountsViewModel(appState: appState)
            }
            await viewModel?.load()

            guard let viewModel else { return }
            viewModel.startPollingLiveUpdates()
            await withTaskCancellationHandler {
                try? await Task.sleep(nanoseconds: .max)
            } onCancel: {
                Task { @MainActor in
                    viewModel.stopPollingLiveUpdates()
                }
            }
        }
    }

    private func accountList(viewModel: AccountsViewModel, now: Date) -> some View {
        let accounts = viewModel.filteredAccounts
        let anyNonAuthoritative = Self.shouldShowTruthBanner(
            accounts.map { viewModel.truth(for: $0, at: now) }
        )

        return List {
            Text(LocalizedStringKey("accounts.page.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)

            if anyNonAuthoritative {
                AccountTruthBanner()
                    .listRowBackground(Color.clear)
            }

            ForEach(accounts, id: \.publicId) { account in
                AccountCard(
                    account: account,
                    truth: viewModel.truth(for: account, at: now)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgBase)
        .refreshable { await viewModel.load() }
    }

    static func shouldShowTruthBanner(_ truths: [AccountTruth]) -> Bool {
        return truths.contains { !$0.isAuthoritative }
    }
}

/// Page-level warning shown whenever at least one row is not authoritative.
struct AccountTruthBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey("accounts.banner.title"))
                    .font(.subheadline.weight(.semibold))
                Text(LocalizedStringKey("accounts.banner.message"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// Venue-account card with balance and open-position tables.
struct AccountCard: View {
    let account: PortfolioAccountState
    let truth: AccountTruth

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            balances
            positions
            metadata
        }
        .padding(16)
        .background(Color.bgSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.strokeSeparator, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(verbatim: account.exchange)
                        .font(.headline)
                    Text(verbatim: Self.modeLabel(account.mode, appState: appState))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                Text(verbatim: account.walletPublicId ?? noValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            AccountTruthBadge(status: truth.clientEffectiveStatus)
        }
    }

    private var balances: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle("accounts.section.balances")
            if let entries = account.balances, !entries.isEmpty {
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                        GridRow {
                            tableHeader("accounts.balance.currency")
                            tableHeader("accounts.balance.total")
                            tableHeader("accounts.balance.free")
                            tableHeader("accounts.balance.used")
                        }
                        ForEach(entries, id: \.currency) { entry in
                            GridRow {
                                Text(verbatim: entry.currency)
                                number(entry.total)
                                nullableNumber(entry.free)
                                nullableNumber(entry.used)
                            }
                            .font(.caption.monospaced())
                        }
                    }
                }
            } else {
                emptyRow("accounts.sectionEmpty.balances")
            }
            if let observedAt = account.balanceObservedAt {
                timestamp("accounts.meta.balancesObserved", date: observedAt)
            }
        }
    }

    private var positions: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle("accounts.section.positions")
            if let entries = account.openPositions, !entries.isEmpty {
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                        GridRow {
                            tableHeader("accounts.position.symbol")
                            tableHeader("accounts.position.side")
                            tableHeader("accounts.position.size")
                            tableHeader("accounts.position.entryPrice")
                            tableHeader("accounts.position.markPrice")
                            tableHeader("accounts.position.unrealizedPnl")
                            tableHeader("accounts.position.unrealizedFunding")
                        }
                        ForEach(entries, id: \.symbol) { entry in
                            GridRow {
                                Text(verbatim: entry.symbol)
                                Text(verbatim: Self.sideLabel(entry.side, appState: appState))
                                number(entry.size)
                                number(entry.entryPrice)
                                number(entry.markPrice)
                                pnl(entry.unrealizedPnl)
                                pnl(entry.unrealizedFunding)
                            }
                            .font(.caption.monospaced())
                        }
                    }
                }
            } else {
                emptyRow("accounts.sectionEmpty.positions")
            }
            if let observedAt = account.positionObservedAt {
                timestamp("accounts.meta.positionsObserved", date: observedAt)
            }
        }
    }

    @ViewBuilder
    private var metadata: some View {
        if let authoritativeUntil = account.authoritativeUntil {
            timestamp("accounts.meta.authoritativeUntil", date: authoritativeUntil)
        }
        if let error = account.error, !error.isEmpty {
            Text(verbatim: String(
                format: LocaleStrings.localized(
                    "accounts.meta.error",
                    in: appState.locale.catalogLanguage
                ),
                error
            ))
            .font(.caption)
            .foregroundStyle(Color.lossRed)
        }
    }

    private var noValue: String {
        return LocaleStrings.localized("accounts.noValue", in: appState.locale.catalogLanguage)
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    private func tableHeader(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func number(_ value: Double) -> some View {
        Text(verbatim: Self.formatNumber(value, locale: appState.locale))
    }

    private func nullableNumber(_ value: Double?) -> some View {
        Text(verbatim: value.map { Self.formatNumber($0, locale: appState.locale) } ?? noValue)
    }

    private func pnl(_ value: Double) -> some View {
        Text(verbatim: Self.formatPnL(value, locale: appState.locale))
            .foregroundStyle(Self.pnlColor(value, appState: appState))
    }

    private func emptyRow(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func timestamp(_ key: String, date: Date) -> some View {
        Text(verbatim: String(
            format: LocaleStrings.localized(key, in: appState.locale.catalogLanguage),
            Self.formatTimestamp(date, locale: appState.locale)
        ))
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    static func formatNumber(_ value: Double, locale: AppLocale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale.westernDigitsLocale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    static func formatPnL(_ value: Double, locale: AppLocale) -> String {
        let formatted = formatNumber(value, locale: locale)
        return value > 0 ? "+\(formatted)" : formatted
    }

    static func formatTimestamp(_ value: Date, locale: AppLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.westernDigitsLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: value)
    }

    static func modeLabel(_ mode: String?, appState: AppState) -> String {
        guard let mode else {
            return LocaleStrings.localized("accounts.noValue", in: appState.locale.catalogLanguage)
        }
        switch mode {
        case "live", "paper":
            return LocaleStrings.localized(
                "accounts.mode.\(mode)",
                in: appState.locale.catalogLanguage
            )
        default:
            return mode
        }
    }

    static func sideLabel(_ side: String, appState: AppState) -> String {
        switch side {
        case "buy", "sell":
            return LocaleStrings.localized(
                "accounts.side.\(side)",
                in: appState.locale.catalogLanguage
            )
        default:
            return side
        }
    }

    static func pnlColor(_ value: Double, appState: AppState) -> Color {
        if value > 0 { return Color.financialRising(for: appState) }
        if value < 0 { return Color.financialFalling(for: appState) }
        return .secondary
    }
}

/// Client-effective venue truth badge.
struct AccountTruthBadge: View {
    let status: String

    private var presentation: AccountTruthStatusPresentation {
        AccountTruthStatusPresentation.forStatus(status)
    }

    var body: some View {
        Text(LocalizedStringKey(presentation.labelKey))
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(foregroundColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(foregroundColor.opacity(0.4), lineWidth: 1)
            }
            .accessibilityLabel(LocalizedStringKey(presentation.tooltipKey))
    }

    private var foregroundColor: Color {
        switch presentation.tone {
        case .authoritative:
            return .profitGreen
        case .simulated:
            return .blue
        case .stale:
            return .orange
        case .corrupt:
            return .lossRed
        case .unsupported, .unknown:
            return .secondary
        }
    }
}

struct AccountsView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsView()
            .environment(AppState.shared)
    }
}
