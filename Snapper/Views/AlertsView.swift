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
/// Deep-link integration: when a notification is tapped,
/// ``AppDelegate.userNotificationCenter(_:didReceive:)`` routes the
/// tap into ``NavigationCoordinator.pendingAlertPublicId``. This
/// view observes that field and — when the pending id lands in the
/// current list — scrolls to it via ``ScrollViewReader``. If the id
/// is NOT in the list (alert arrived while the tab was unmounted),
/// the view re-fetches; the fetched list is guaranteed to include
/// the anchor because the sidecar persists before APNs send.
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
                    } else if alerts.isEmpty {
                        ContentUnavailableView(
                            LocalizedStringKey("alerts.empty.title"),
                            systemImage: "bell.slash",
                            description: Text(LocalizedStringKey("alerts.empty.message"))
                        )
                    } else {
                        List {
                            ForEach(alerts, id: \.publicId) { alert in
                                AlertRow(alert: alert, locale: appState.locale)
                                    .id(alert.publicId)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedAlert = alert
                                    }
                            }
                        }
                        .refreshable {
                            await load()
                        }
                    }
                }
                .onChange(of: navigationCoordinator.pendingAlertPublicId) { _, newValue in
                    handleDeepLink(alertPublicId: newValue, proxy: proxy)
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
                AlertDetailView(alert: wrapper.alert)
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

    private func handleDeepLink(alertPublicId: String?, proxy: ScrollViewProxy) {
        guard let pid = alertPublicId else { return }
        if alerts.contains(where: { $0.publicId == pid }) {
            withAnimation {
                proxy.scrollTo(pid, anchor: .top)
            }
            navigationCoordinator.clearPendingDeepLink()
            return
        }
        Task {
            await load()
            if alerts.contains(where: { $0.publicId == pid }) {
                withAnimation {
                    proxy.scrollTo(pid, anchor: .top)
                }
            }
            navigationCoordinator.clearPendingDeepLink()
        }
    }
}

private struct IdentifiedAlert: Identifiable {
    let alert: AlertEventInfo
    var id: String { alert.publicId }
}

private struct AlertDetailView: View {
    let alert: AlertEventInfo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(alert.title)
                        .font(.title2.bold())
                    Text(alert.body)
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
