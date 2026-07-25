import SwiftUI

/// A pending reject awaiting confirmation. Rejecting vetoes a trade the
/// strategy already wants to place, so it is confirmed first; approving
/// fires directly (web parity).
private struct AiReviewRejectRequest: Identifiable {
    let reviewPublicId: String
    let instrument: String?

    var id: String { return reviewPublicId }
}

/// AI-review screen with two feeds behind one title.
///
/// A **delegate session** (`delegate_public_id` present + `read:signals`)
/// gets a segmented `Pending | Decisions`: the actionable inbox of
/// CONSULT reviews routed to this delegate, plus per-row approve /
/// reject, alongside the audit list. Every other session sees only the
/// read-only audit list of AI-delegate decisions from
/// `GET /api/ai-reviews` — no segment, unchanged behavior.
///
/// Pushed from ``HomeView`` (nested in its ``NavigationStack``) rather
/// than owning a tab, mirroring ``BacktestsView``. Neither feed is
/// client-side wallet-scoped: both are scoped server-side (the audit list
/// by operator membership, the inbox by delegate identity), so filtering
/// by the local wallet selection could only hide rows the user is
/// responsible for. Pull-to-refresh plus the live ai_review pulse keep
/// both fresh.
struct AiReviewsView: View {

    @Environment(AppState.self) private var appState
    @EnvironmentObject private var webSocketManager: WebSocketManager
    @State private var viewModel: AiReviewsViewModel?
    @State private var segment: AiReviewsSegment = .pending
    /// Per-review rationale drafts, held by the parent so a list reorder
    /// or a row recycle cannot silently drop what the user typed.
    @State private var rationales: [String: String] = [:]
    @State private var rejectRequest: AiReviewRejectRequest?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.showsPendingInbox {
                    VStack(spacing: 0) {
                        Picker(LocalizedStringKey("aiReviews.segment.label"), selection: $segment) {
                            ForEach(AiReviewsSegment.allCases) { value in
                                Text(LocalizedStringKey(value.titleKey)).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        switch segment {
                        case .pending:
                            pendingList(viewModel)
                        case .decisions:
                            decisionsContent(viewModel)
                        }
                    }
                } else {
                    decisionsContent(viewModel)
                }
            } else {
                ProgressView(LocalizedStringKey("common.loading"))
            }
        }
        .navigationTitle(LocalizedStringKey("aiReviews.navTitle"))
        .confirmationDialog(
            confirmRejectTitle(for: rejectRequest),
            isPresented: Binding(
                get: { rejectRequest != nil },
                set: { if !$0 { rejectRequest = nil } }
            ),
            titleVisibility: .visible,
            presenting: rejectRequest
        ) { request in
            Button(LocalizedStringKey("aiReviews.decision.reject"), role: .destructive) {
                submit(reviewPublicId: request.reviewPublicId, decision: .reject)
            }
            Button(LocalizedStringKey("aiReviews.decision.cancel"), role: .cancel) {
                rejectRequest = nil
            }
        } message: { _ in
            Text(LocalizedStringKey("aiReviews.decision.confirmReject.message"))
        }
        /// A confirmation the user leaves open outlives its row: a peer
        /// can resolve the review, or a reload can drop it, while the
        /// dialog sits on screen. Retract it as soon as the row leaves the
        /// inbox so the destructive button cannot act on something that is
        /// no longer there. ``submitDecision`` re-checks membership too —
        /// this only avoids showing an offer that is already void.
        .onChange(of: pendingReviewIds) { _, ids in
            if let request = rejectRequest, !ids.contains(request.reviewPublicId) {
                rejectRequest = nil
            }
        }
        /// Dismissal lives in the binding's setter, NOT in the button:
        /// SwiftUI flips ``isPresented`` for any button tap, so doing it
        /// in both places would pop TWO entries and swallow a queued
        /// failure the user never saw.
        .alert(
            LocalizedStringKey("common.error.submissionFailed"),
            isPresented: Binding(
                get: { viewModel?.currentSubmitAlert != nil },
                set: { presented in
                    guard !presented,
                          let viewModel,
                          let alert = viewModel.currentSubmitAlert else { return }
                    viewModel.dismissSubmitAlert(alert)
                }
            ),
            presenting: viewModel?.currentSubmitAlert
        ) { _ in
            Button(LocalizedStringKey("common.ok"), role: .cancel) { }
        } message: { alert in
            Text(verbatim: alert.message)
        }
        /// The appearance lifecycle — session open, initial load, live
        /// observation, teardown on disappear — lives in the ViewModel so
        /// its ordering is unit-tested. Installing the teardown here,
        /// after the initial `await`, is exactly the bug that let a view
        /// disappearing mid-load leave its session active.
        .task {
            if viewModel == nil {
                viewModel = AiReviewsViewModel()
            }
            await viewModel?.runSession(observing: webSocketManager)
        }
    }

    /// Ids currently in the inbox — the stale-confirmation trigger.
    private var pendingReviewIds: [String] {
        return viewModel?.pending.map(\.reviewPublicId) ?? []
    }

    /// The read-only audit list — loading placeholder, whole-screen error
    /// state, or the list itself. Unchanged from the pre-inbox screen; in
    /// delegate mode it is scoped to the `Decisions` segment so a failing
    /// audit fetch (a pure `aiDelegate` holds no `read:ai_reviews`) can
    /// never blank the inbox next to it.
    @ViewBuilder
    private func decisionsContent(_ viewModel: AiReviewsViewModel) -> some View {
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
    }

    /// The delegate inbox. The empty state and the load-error banner both
    /// live INSIDE the refreshable ``List`` so pull-to-refresh stays
    /// available in every state.
    private func pendingList(_ viewModel: AiReviewsViewModel) -> some View {
        List {
            if let pendingLoadError = viewModel.pendingLoadError {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey("common.error.loadFailed.title"))
                                .font(.subheadline.weight(.semibold))
                            Text(verbatim: pendingLoadError.localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if viewModel.pending.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("aiReviews.pending.empty.title"),
                    systemImage: "tray",
                    description: Text(LocalizedStringKey("aiReviews.pending.empty.message"))
                )
                .listRowBackground(Color.clear)
            } else {
                Section(LocalizedStringKey("aiReviews.pending.title")) {
                    ForEach(viewModel.pending, id: \.reviewPublicId) { item in
                        pendingRow(item, viewModel: viewModel)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgBase)
        .refreshable { await viewModel.load() }
    }

    private func pendingRow(
        _ item: PendingReviewSummaryItem,
        viewModel: AiReviewsViewModel
    ) -> some View {
        PendingReviewRow(
            item: item,
            showsControls: viewModel.canSubmitDecisions,
            isBusy: viewModel.isInFlight(item.reviewPublicId),
            isExpired: AiReviewsViewModel.isExpired(deadline: item.deadline, now: Date()),
            rationale: Binding(
                get: { rationales[item.reviewPublicId] ?? "" },
                set: { rationales[item.reviewPublicId] = $0 }
            ),
            onApprove: { submit(reviewPublicId: item.reviewPublicId, decision: .approve) },
            onReject: {
                rejectRequest = AiReviewRejectRequest(
                    reviewPublicId: item.reviewPublicId,
                    instrument: item.instrument
                )
            }
        )
    }

    /// Fire one decision and clear that review's rationale draft once the
    /// write is accepted, so a resolved row cannot leave stale text
    /// behind if the id ever reappears.
    private func submit(reviewPublicId: String, decision: AiReviewDecisionIntent) {
        guard let viewModel else { return }
        let rationale = rationales[reviewPublicId]
        Task {
            let accepted = await viewModel.submitDecision(
                reviewPublicId: reviewPublicId,
                decision: decision,
                rationale: rationale
            )
            if accepted {
                rationales[reviewPublicId] = nil
            }
        }
    }

    private func confirmRejectTitle(for request: AiReviewRejectRequest?) -> Text {
        guard let request else { return Text(verbatim: "") }
        let language = appState.locale.catalogLanguage
        let template = LocaleStrings.localized("aiReviews.decision.confirmReject.title", in: language)
        let subject = request.instrument ?? request.reviewPublicId
        return Text(
            verbatim: String(format: template, locale: Locale(identifier: language.rawValue), subject)
        )
    }
}

/// One pending-review row: instrument + status badge, the deadline, and
/// (for a caller holding `submit:ai_review_decision`) an optional
/// rationale field plus the approve / reject controls.
///
/// The controls are disabled while THIS row's write is in flight and for
/// a row whose deadline has visibly elapsed — the backend applies an
/// inline timeout to such a review and would answer 410, so offering the
/// buttons would only produce a guaranteed failure. The expiry check is
/// evaluated at render time; a row that expires while the screen sits
/// idle is caught by the next refresh or live pulse.
///
/// The web inbox also shows a thesis excerpt pulled out of
/// ``PendingReviewSummaryItem/signalEnvelope``. That is NOT renderable
/// here: the backend types `signal_envelope` as an opaque JSON object,
/// so the generated ``JsonObject`` is a content-free placeholder — it
/// decodes any object and stores nothing. Surfacing the thesis needs a
/// type-generator change, which is outside this screen.
private struct PendingReviewRow: View {
    let item: PendingReviewSummaryItem
    let showsControls: Bool
    let isBusy: Bool
    let isExpired: Bool
    @Binding var rationale: String
    let onApprove: () -> Void
    let onReject: () -> Void

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(verbatim: item.instrument ?? "—")
                    .font(.subheadline.weight(.medium))
                Spacer()
                statusBadge
            }

            HStack(spacing: 4) {
                Text(LocalizedStringKey("aiReviews.pending.field.deadline"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(verbatim: AiReviewsViewModel.formattedDeadline(item.deadline, locale: appState.locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isExpired {
                    Text(LocalizedStringKey("aiReviews.pending.expired"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.financialFalling(for: appState).opacity(0.15))
                        .foregroundStyle(Color.financialFalling(for: appState))
                        .clipShape(Capsule())
                }
            }

            if showsControls {
                controls
            }
        }
        .padding(.vertical, 4)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(
                LocalizedStringKey("aiReviews.pending.rationalePlaceholder"),
                text: $rationale
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .disabled(isBusy || isExpired)
            .accessibilityIdentifier("aiReviews.pending.rationale.\(item.reviewPublicId)")

            HStack(spacing: 8) {
                Button(action: onApprove) {
                    controlContent("aiReviews.decision.approve")
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .disabled(isBusy || isExpired)
                .accessibilityIdentifier("aiReviews.decision.approve.\(item.reviewPublicId)")

                Button(role: .destructive, action: onReject) {
                    controlContent("aiReviews.decision.reject")
                }
                .buttonStyle(.bordered)
                .disabled(isBusy || isExpired)
                .accessibilityIdentifier("aiReviews.decision.reject.\(item.reviewPublicId)")
            }
        }
        .padding(.top, 2)
    }

    private func controlContent(_ key: String) -> some View {
        HStack(spacing: 6) {
            if isBusy {
                ProgressView().controlSize(.mini)
            }
            Text(LocalizedStringKey(key))
                .font(.caption.weight(.medium))
        }
    }

    private var statusBadge: some View {
        return Text(verbatim: item.status)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
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
        let verdict = AiReviewsViewModel.verdict(decision: review.decision, status: review.status)
        let color = decisionColor(verdict)
        return Text(LocalizedStringKey(verdict.localizationKey))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    /// Only a real verdict earns a financial colour. The states nobody
    /// decided — timed out, superseded, still pending — stay neutral, and
    /// are told apart by their LABEL rather than by hue alone, which
    /// colour-blind users could not read.
    private func decisionColor(_ verdict: AiReviewDecision) -> Color {
        switch verdict {
        case .approved: return Color.financialRising(for: appState)
        case .rejected: return Color.financialFalling(for: appState)
        case .timedOut, .superseded, .pending: return .secondary
        }
    }
}

/// Tappable Home entry that pushes ``AiReviewsView`` — mirrors
/// ``HealthEntryCard``, plus a pending-count badge for delegate
/// sessions.
struct AiReviewsEntryCard: View {
    /// Rows waiting on this delegate. Home resolves it once per load for
    /// delegate sessions and passes ``0`` for everyone else, so the badge
    /// is inherently delegate-only.
    var pendingCount: Int = 0

    @Environment(AppState.self) private var appState

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

            if Self.showsBadge(pendingCount: pendingCount) {
                badge
            }

            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundColor(.textSecondary)
        }
        .padding(14)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var badge: some View {
        let language = appState.locale.catalogLanguage
        let template = LocaleStrings.localized("aiReviews.entry.pendingBadgeAccessibilityLabel", in: language)
        let label = String(format: template, locale: Locale(identifier: language.rawValue), pendingCount)
        return Text(verbatim: pendingCount.formatted(.number.locale(appState.locale.nativeLocale)))
            .font(.caption2.bold())
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor)
            .foregroundStyle(Color.white)
            .clipShape(Capsule())
            .accessibilityLabel(Text(verbatim: label))
    }

    /// Whether the entry card shows the pending badge. Pure so the
    /// predicate is unit-tested; the delegate gate lives upstream in
    /// ``HomeView``, which only ever supplies a non-zero count for a
    /// delegate session.
    static func showsBadge(pendingCount: Int) -> Bool {
        return pendingCount > 0
    }
}

struct AiReviewsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AiReviewsView()
                .environment(AppState.shared)
                .environmentObject(WebSocketManager.shared)
        }
    }
}
