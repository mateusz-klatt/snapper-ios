import SwiftUI

/// Read-only audit list of AI-delegate decisions from
/// `GET /api/ai-reviews`. Pushed from ``HomeView`` (nested in its
/// ``NavigationStack``) rather than owning a tab, mirroring
/// ``BacktestsView``. Not client-side wallet-scoped (see
/// ``AiReviewsViewModel``); pull-to-refresh only. The delegate
/// approve / reject controls and the live activity WebSocket are out of
/// scope for this first cut.
struct AiReviewsView: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel: AiReviewsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.reviews.isEmpty {
                    ProgressView(LocalizedStringKey("common.loading"))
                } else if AiReviewsViewModel.shouldShowLoadError(
                    count: viewModel.reviews.count,
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
                        if viewModel.reviews.isEmpty {
                            ContentUnavailableView(
                                LocalizedStringKey("aiReviews.empty.title"),
                                systemImage: "brain",
                                description: Text(LocalizedStringKey("aiReviews.empty.message"))
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(viewModel.reviews, id: \.reviewPublicId) { review in
                                AiReviewRow(review: review)
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
        .navigationTitle(LocalizedStringKey("aiReviews.navTitle"))
        .task {
            if viewModel == nil {
                viewModel = AiReviewsViewModel()
            }
            await viewModel?.load()
        }
    }
}

/// One AI-review row: decision badge + decided-at, the rationale text,
/// and the reviewed instrument reference.
private struct AiReviewRow: View {
    let review: AdminAiReviewItem

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                decisionBadge
                Spacer()
                if let resolvedAt = review.resolvedAt {
                    Text(LocalizedStringKey("aiReviews.field.decidedAt"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(verbatim: resolvedAt.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened)
                            .locale(appState.locale.nativeLocale)
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if let rationale = review.rationale, !rationale.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("aiReviews.field.rationale"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(verbatim: rationale)
                        .font(.caption)
                        .lineLimit(3)
                }
            }

            HStack(spacing: 4) {
                Text(LocalizedStringKey("aiReviews.field.instrument"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(verbatim: String(review.instrumentPublicId.prefix(12)))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var decisionBadge: some View {
        let verdict = AiReviewsViewModel.decision(for: review.decision)
        let color = decisionColor(verdict)
        return Text(LocalizedStringKey(verdict.localizationKey))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func decisionColor(_ verdict: AiReviewDecision) -> Color {
        switch verdict {
        case .approved: return Color.financialRising(for: appState)
        case .rejected: return Color.financialFalling(for: appState)
        case .pending: return .secondary
        }
    }
}

/// Tappable Home entry that pushes ``AiReviewsView`` — mirrors
/// ``HealthEntryCard``.
struct AiReviewsEntryCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("aiReviews.navTitle"))
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(LocalizedStringKey("aiReviews.entry.subtitle"))
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

struct AiReviewsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AiReviewsView()
                .environment(AppState.shared)
        }
    }
}
