import SwiftUI

/// Read-only list of AI delegates from `GET /api/ai-delegates` — the
/// "AI Integration" surface (service accounts that grant an external AI
/// agent MCP access to trade under caps). Pushed from ``HomeView``
/// (nested in its ``NavigationStack``) rather than owning a tab,
/// mirroring ``AdminView``. Not wallet-scoped (see
/// ``AiIntegrationViewModel``); pull-to-refresh only. The web's create
/// ("mint" a token) / update-caps / revoke actions are out of scope for
/// this first cut.
struct AiIntegrationView: View {

    @State private var viewModel: AiIntegrationViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.delegates.isEmpty {
                    ProgressView(LocalizedStringKey("common.loading"))
                } else if AiIntegrationViewModel.shouldShowLoadError(
                    count: viewModel.delegates.count,
                    loadError: viewModel.loadError,
                    isLoading: viewModel.isLoading
                ), let loadError = viewModel.loadError {
                    ContentUnavailableView(
                        LocalizedStringKey("common.error.loadFailed.title"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(verbatim: loadError.localizedDescription)
                    )
                    .overlay(alignment: .bottom) {
                        Button(LocalizedStringKey("common.retry")) {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                } else {
                    List {
                        if viewModel.delegates.isEmpty {
                            ContentUnavailableView(
                                LocalizedStringKey("aiIntegration.empty.title"),
                                systemImage: "sparkles",
                                description: Text(LocalizedStringKey("aiIntegration.empty.message"))
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(viewModel.sortedDelegates, id: \.publicId) { delegate in
                                DelegateRow(delegate: delegate)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.bgBase)
                    .refreshable { await viewModel.load() }
                }
            } else {
                ProgressView(LocalizedStringKey("common.loading"))
            }
        }
        .navigationTitle(LocalizedStringKey("aiIntegration.navTitle"))
        .task {
            if viewModel == nil {
                viewModel = AiIntegrationViewModel()
            }
            await viewModel?.load()
        }
    }
}

/// One delegate row: label + status badge, the username, the creation
/// date, and the two headline trading caps.
private struct DelegateRow: View {
    let delegate: DelegateRead

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: delegate.label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                statusBadge
            }
            Text(verbatim: delegate.username)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                metric(labelKey: "aiIntegration.field.maxOpenOrders", value: maxOpenOrdersText)
                metric(labelKey: "aiIntegration.field.maxDailyUsd", value: maxDailyUsdText)
                Spacer()
            }
            HStack(spacing: 4) {
                Text(LocalizedStringKey("admin.field.created"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(verbatim: delegate.createdAt.formatted(
                    Date.FormatStyle(date: .abbreviated, time: .omitted)
                        .locale(appState.locale.nativeLocale)
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        let color = delegate.isActive ? Color.financialRising(for: appState) : Color.secondary
        return Text(LocalizedStringKey(AiIntegrationViewModel.statusLabelKey(isActive: delegate.isActive)))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var capDefaultText: String {
        return LocaleStrings.localized("aiIntegration.caps.default", in: appState.locale.catalogLanguage)
    }

    private var maxOpenOrdersText: String {
        return AiIntegrationViewModel.capValueText(delegate.caps.maxOpenOrders, defaultLabel: capDefaultText)
    }

    private var maxDailyUsdText: String {
        return AiIntegrationViewModel.capCurrencyText(
            delegate.caps.maxDailyNotionalUsd,
            locale: appState.locale,
            defaultLabel: capDefaultText
        )
    }

    private func metric(labelKey: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(LocalizedStringKey(labelKey))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.caption2.monospacedDigit())
        }
    }
}

/// Tappable Home entry that pushes ``AiIntegrationView`` — mirrors
/// ``HealthEntryCard``.
struct AiIntegrationEntryCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("aiIntegration.navTitle"))
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(LocalizedStringKey("aiIntegration.entry.subtitle"))
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

struct AiIntegrationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AiIntegrationView()
                .environment(AppState.shared)
        }
    }
}
