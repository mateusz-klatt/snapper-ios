import SwiftUI
import os

/// Alerts tab — renders the user's recent alert history.
///
/// On appear, fetches `/api/alerts` via ``APIClient.fetchAlertHistory()``
/// and populates an in-memory list. Pull-to-refresh re-fetches. Tap
/// on a row surfaces an inline detail sheet with the raw
/// ``payload`` JSON (debugging aid; alerts have minimal
/// user-relevant metadata beyond title / body / timestamp).
///
/// Empty state: the "no alerts" ``ContentUnavailableView`` renders as
/// a clear-backed row INSIDE the refreshable ``List`` (not as a bare
/// standalone view), so an initial empty response can be pulled to
/// refresh in place without re-navigating. The loading and error
/// branches remain outside the list, unchanged.
///
/// Deep-link integration: when a notification is tapped,
/// ``AppDelegate.userNotificationCenter(_:didReceive:)`` routes the
/// tap into ``NavigationCoordinator.pendingAlertPublicId``. This
/// view observes that field and — when the pending id is already
/// among the loaded rows — scrolls to it via ``ScrollViewReader`` and
/// clears the pending id. If the id is NOT in the list (alert arrived
/// while the tab was unmounted, or while the empty-state row is
/// showing), the view fetches and RETAINS the pending id; it does NOT
/// scroll or clear on the fetch itself, because during a fetch the
/// loading branch replaces the ``List`` with a ``ProgressView``
/// (unmounting the row anchors) and a scroll issued right after
/// ``load()`` can run before SwiftUI commits the new rows. Instead the
/// scroll is driven off ``pendingAnchorRendered`` flipping true — the
/// moment the anchor row is actually part of the rendered ``List`` —
/// at which point the view scrolls and clears.
///
/// Retention rule: a pending id whose anchor never renders (fetch
/// failed, or the alert genuinely absent) is retained, not cleared. It
/// resolves on the next successful refresh that includes the anchor
/// (pull-to-refresh, or tab re-entry re-running ``load()`` via the
/// id-keyed ``.task``), is superseded when a newer deep link overwrites
/// ``pendingAlertPublicId``, or is cleared by ``MainTabView``. This
/// deliberately trades a lingering pending id for never silently
/// dropping a scroll target. Because the empty ``List`` and the
/// populated ``List`` share the same ``ScrollViewReader`` scope, the
/// post-fetch scroll resolves the anchor in the same scroll container
/// the empty state occupied.
struct AlertsView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(AppState.self) private var appState

    @State private var alerts: [AlertEventInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAlert: AlertEventInfo?

    private let logger = AppLogger.make(category: "AlertsView")

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Group {
                    if isLoading && alerts.isEmpty {
                        ProgressView(LocalizedStringKey("alerts.loading"))
                    } else if let message = errorMessage, alerts.isEmpty {
                        VStack(spacing: 12) {
                            Text(LocalizedStringKey("alerts.error.loadFailed"))
                                .font(.headline)
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button(LocalizedStringKey("common.retry"), action: reload)
                        }
                        .padding()
                    } else {
                        List {
                            if alerts.isEmpty {
                                ContentUnavailableView(
                                    LocalizedStringKey("alerts.empty.title"),
                                    systemImage: "bell.slash",
                                    description: Text(LocalizedStringKey("alerts.empty.message"))
                                )
                                .listRowBackground(Color.clear)
                            } else {
                                ForEach(alerts, id: \.publicId) { alert in
                                    AlertRow(alert: alert, locale: appState.locale)
                                        .id(alert.publicId)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedAlert = alert
                                        }
                                }
                            }
                        }
                        .refreshable {
                            await load()
                        }
                    }
                }
                .onChange(of: navigationCoordinator.pendingAlertPublicId) { _, _ in
                    consumeDeepLink(proxy: proxy)
                }
                .onChange(of: pendingAnchorRendered) { _, rendered in
                    /// Fires the moment a retained pending anchor
                    /// becomes part of the rendered ``List`` (e.g.
                    /// after a deep-link-triggered ``load()`` commits
                    /// its rows). Scrolling here — rather than inline
                    /// after ``load()`` — guarantees the target row
                    /// exists before
                    /// ``ScrollViewProxy/scrollTo(_:anchor:)``, avoiding
                    /// the silent no-op of scrolling into a not-yet-
                    /// committed / ``ProgressView``-replaced list.
                    if rendered {
                        consumeDeepLink(proxy: proxy)
                    }
                }
                .task(id: navigationCoordinator.pendingAlertPublicId) {
                    /// Mirror the ``.onChange`` consumer so a
                    /// ``pendingAlertPublicId`` that was already
                    /// set BEFORE this view mounted still triggers
                    /// the scroll-to-anchor (or fetch-and-retain)
                    /// contract. ``.onChange`` fires only on
                    /// subsequent value changes, never on the initial
                    /// value, so without this an ``/alerts/<id>`` deep
                    /// link consumed by ``MainTabView`` at first
                    /// ``.onAppear`` would leave the anchor un-handled,
                    /// which the locale-driven ``MainTabView`` remount
                    /// in PR #97 would then replay.
                    consumeDeepLink(proxy: proxy)
                }
            }
            .navigationTitle(LocalizedStringKey("alerts.navTitle"))
            .task {
                if alerts.isEmpty {
                    await load()
                }
            }
            .sheet(item: Binding(
                get: { selectedAlert.map { IdentifiedAlert(alert: $0) } },
                set: { selectedAlert = $0?.alert }
            )) { wrapper in
                AlertDetailView(alert: wrapper.alert, locale: appState.locale)
            }
        }
    }

    private func reload() {
        Task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.fetchAlertHistory(limit: 50)
            alerts = response.payload
        } catch {
            logger.error("Failed to load alert history: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Whether the currently pending deep-link anchor is present among
    /// the loaded ``alerts`` rows. The post-fetch scroll is triggered
    /// off this flipping true so
    /// ``ScrollViewProxy/scrollTo(_:anchor:)`` only runs once the
    /// target row is committed to the ``List``.
    private var pendingAnchorRendered: Bool {
        guard let pid = navigationCoordinator.pendingAlertPublicId else { return false }
        return alerts.contains { $0.publicId == pid }
    }

    /// Advance the deep-link state machine against the current
    /// coordinator + list state, performing only the effect the pure
    /// ``deepLinkStep(pendingId:targetPresent:)`` decision selects.
    private func consumeDeepLink(proxy: ScrollViewProxy) {
        switch AlertsView.deepLinkStep(
            pendingId: navigationCoordinator.pendingAlertPublicId,
            targetPresent: pendingAnchorRendered
        ) {
        case .idle:
            return
        case .scrollThenClear(let pid):
            withAnimation {
                proxy.scrollTo(pid, anchor: .top)
            }
            navigationCoordinator.clearPendingDeepLink()
        case .fetchAndRetain:
            Task { await load() }
        }
    }

    /// Pure, side-effect-free decision for the deep-link state machine,
    /// kept ``static`` so the scroll / fetch / retain / clear contract
    /// is unit-testable without a hosting controller.
    ///
    /// - ``idle``: no pending id — do nothing.
    /// - ``scrollThenClear``: the anchor is present among the rendered
    ///   rows — scroll to it, then clear the pending id.
    /// - ``fetchAndRetain``: a deep link is pending but its anchor is
    ///   absent — fetch and RETAIN the pending id. A miss (including a
    ///   failed load) never clears, so a later successful refresh can
    ///   still resolve the scroll target.
    enum DeepLinkStep: Equatable {
        case idle
        case scrollThenClear(String)
        case fetchAndRetain(String)
    }

    /// Map the current ``pendingId`` and whether its anchor row is
    /// present to the next ``DeepLinkStep``.
    static func deepLinkStep(pendingId: String?, targetPresent: Bool) -> DeepLinkStep {
        guard let pid = pendingId else { return .idle }
        return targetPresent ? .scrollThenClear(pid) : .fetchAndRetain(pid)
    }
}

private struct IdentifiedAlert: Identifiable {
    let alert: AlertEventInfo
    var id: String { alert.publicId }
}

private struct AlertDetailView: View {
    let alert: AlertEventInfo
    /// The user-selected app locale (drives in-app re-localization of
    /// ``title``/``body`` via ``AlertEventInfo.displayTitle(in:)``).
    /// Defaults to ``.us`` so previews and any legacy caller that
    /// still constructs ``AlertDetailView`` without a locale render
    /// English instead of crashing — the same convention used by
    /// ``AlertRow`` and ``LatestAlertCard``.
    var locale: AppLocale = .us

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(verbatim: alert.displayTitle(in: locale.catalogLanguage))
                        .font(.title2.bold())
                    Text(verbatim: alert.displayBody(in: locale.catalogLanguage))
                        .font(.body)
                    Divider()
                    LabeledContent("Type", value: alert.alertType)
                    LabeledContent("Priority", value: alert.priority)
                    LabeledContent("Safety-critical", value: alert.isSafetyCritical ? "Yes" : "No")
                    LabeledContent(LocalizedStringKey("alerts.detail.timestamp"), value: alert.timestamp.formatted(date: .abbreviated, time: .standard))
                    if let threadKey = alert.threadKey {
                        LabeledContent(LocalizedStringKey("alerts.detail.thread"), value: threadKey)
                    }
                    if let topic = alert.sourceTopic {
                        LabeledContent(LocalizedStringKey("alerts.detail.sourceTopic"), value: topic)
                    }
                }
                .padding()
            }
            .navigationTitle(LocalizedStringKey("alerts.detail.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
