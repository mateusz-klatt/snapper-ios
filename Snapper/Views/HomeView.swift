import SwiftUI
import os

struct HomeView: View {
    private let logger = AppLogger.make(category: "Home")
    @EnvironmentObject var webSocketManager: WebSocketManager
    @Environment(AppState.self) private var appState
    @EnvironmentObject var authService: AuthService
    @State private var systemStatus: SystemStatus?
    @State private var devShouldShowMarket = false
    @State private var positions: [PositionSnapshot] = []
    @State private var orders: [OrderStatus] = []
    @State private var latestAlert: AlertEventInfo?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        WalletPicker()
                        Spacer()
                    }

                    LatestAlertCard(alert: latestAlert, locale: appState.locale)

                    if authService.hasPermission(.readMarketData) {
                        NavigationLink {
                            MarketDataView()
                        } label: {
                            MarketEntryCard()
                        }
                        .buttonStyle(.plain)
                    }

                    connectionStatusView

                    if let status = systemStatus {
                        systemStatusView(status: status)
                    } else if isLoading {
                        ProgressView(LocalizedStringKey("home.refreshing"))
                            .padding()
                    } else if let error = errorMessage {
                        Text(String(format: LocaleStrings.localized("home.error.loadFailed", in: appState.locale.catalogLanguage), error))
                            .foregroundColor(.red)
                            .padding()
                    }

                    if authService.canAccess("health") {
                        NavigationLink {
                            HealthView()
                        } label: {
                            HealthEntryCard()
                        }
                        .buttonStyle(.plain)
                    }

                    if authService.canAccess("backtests") {
                        NavigationLink {
                            BacktestsView()
                        } label: {
                            BacktestsEntryCard()
                        }
                        .buttonStyle(.plain)
                    }

                    if authService.canAccess("processes") {
                        NavigationLink {
                            ProcessesView()
                        } label: {
                            ProcessesEntryCard()
                        }
                        .buttonStyle(.plain)
                    }

                    if authService.canAccess("ai-reviews") {
                        NavigationLink {
                            AiReviewsView()
                        } label: {
                            AiReviewsEntryCard()
                        }
                        .buttonStyle(.plain)
                    }

                    if authService.canAccess("strategies") {
                        NavigationLink {
                            StrategiesView()
                        } label: {
                            StrategiesEntryCard()
                        }
                        .buttonStyle(.plain)
                    }

                    if authService.canAccess("admin") {
                        NavigationLink {
                            AdminView()
                        } label: {
                            AdminEntryCard()
                        }
                        .buttonStyle(.plain)
                    }

                    if authService.canAccess("ai-integration") {
                        NavigationLink {
                            AiIntegrationView()
                        } label: {
                            AiIntegrationEntryCard()
                        }
                        .buttonStyle(.plain)
                    }

                    if !filteredPositions.isEmpty {
                        positionsView
                    }

                    if !filteredOrders.isEmpty {
                        recentOrdersView
                    }
                }
                .padding()
            }
            .background(Color.bgBase)
            .navigationTitle(LocalizedStringKey("tabs.home"))
            .refreshable {
                await loadData()
                await loadLatestAlert()
            }
            .navigationDestination(isPresented: $devShouldShowMarket) {
                MarketDataView()
            }
        }
        .task {
            await loadData()
            applyDevAutoNavigateIfRequested()
        }
        .task(id: appState.selectedWalletPublicId) {
            await loadLatestAlert()
        }
    }

    /// DEBUG-only auto-navigation hook. When the simulator is
    /// launched with ``UserDefaults.snapper.devStartOnMarket = true``
    /// (set via ``xcrun simctl spawn defaults write …``), Home
    /// programmatically pushes ``MarketDataView`` on first appear.
    /// Only fires once per process. Defaults key never read in
    /// release builds.
    @MainActor
    private func applyDevAutoNavigateIfRequested() {
        #if DEBUG
        guard !devShouldShowMarket else { return }
        if UserDefaults.standard.bool(forKey: "snapper.devStartOnMarket") {
            devShouldShowMarket = true
        }
        #endif
    }

    /// Pure helper extracted for unit testing — returns the first
    /// element of an alert history page, or ``nil`` for an empty
    /// page. The card collapses to ``EmptyView`` on ``nil`` so the
    /// Home layout stays compact when the user has no alerts yet.
    static func firstAlert(from history: AlertHistoryResponse) -> AlertEventInfo? {
        return history.payload.first
    }

    /// Wallet-scoped position list — mirrors the ``PositionsView``
    /// filter so a wallet selection in the toolbar propagates to
    /// Home's "Open Positions" counter and detail card.
    var filteredPositions: [PositionSnapshot] {
        return PositionsViewModel.filter(
            positions: positions,
            selectedWalletPublicId: appState.selectedWalletPublicId
        )
    }

    /// Wallet-scoped order list, newest-first by ``createdAt``.
    /// Delegates to ``OrdersViewModel.filterRecent`` so the Home
    /// "Recent Orders" card and the Orders tab "Recent" segment
    /// agree on BOTH the wallet predicate AND the ordering — the
    /// API payload is not guaranteed to arrive sorted, so a plain
    /// wallet-filter would surface older rows ahead of newer ones
    /// whenever the response wasn't already newest-first.
    ///
    /// The Home view's rendering path slices the first 5 rows;
    /// this property hands ``filterRecent`` the canonical 50-row
    /// paging cap so the in-memory sort window stays bounded
    /// regardless of how large the unfiltered list grows.
    var filteredOrders: [OrderStatus] {
        return OrdersViewModel.filterRecent(
            orders: orders,
            selectedWalletPublicId: appState.selectedWalletPublicId
        )
    }

    /// Wallet-scoped active-order subset for the Home stat card.
    /// Uses the canonical "open lifecycle" set
    /// (``OrdersViewModel.openStatuses``) instead of the previous ad-hoc
    /// ``"open"|"pending"`` pair, which under-counted ``new`` /
    /// ``submitted`` / ``partially_filled`` orders the user could
    /// still cancel from the Orders tab.
    var filteredActiveOrders: [OrderStatus] {
        return Self.filterActiveOrders(
            orders: orders,
            selectedWalletPublicId: appState.selectedWalletPublicId
        )
    }

    /// Pure helper extracted for unit testing — joins
    /// ``OrdersViewModel.walletMatches`` and ``OrdersViewModel.isOpen`` so
    /// the Home counter and the OrdersView "Open" segment stay in
    /// lockstep on the canonical lifecycle set.
    static func filterActiveOrders(
        orders: [OrderStatus],
        selectedWalletPublicId: String?
    ) -> [OrderStatus] {
        return orders.filter { order in
            OrdersViewModel.walletMatches(
                rowWalletId: order.walletPublicId,
                selected: selectedWalletPublicId
            )
                && OrdersViewModel.isOpen(status: order.status)
        }
    }

    private func loadLatestAlert() async {
        do {
            let history = try await APIClient.shared.fetchAlertHistory(limit: 1)
            latestAlert = Self.firstAlert(from: history)
        } catch {
            logger.error("Failed to fetch latest alert: \(error)")
        }
    }

    private var connectionStatusView: some View {
        /// TimelineView re-evaluates every 1s so heartbeat freshness color
        /// transitions green → amber → red as time passes between frames
        /// even when no new @Published update fires from `webSocketManager`.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                Circle()
                    .fill(connectionColor(at: context.date))
                    .frame(width: 8, height: 8)

                Text(connectionText(at: context.date))
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    /// Heartbeat-freshness thresholds for the connection-health badge.
    /// Green: heartbeat within 5s. Amber: 5–30s. Red: >30s or never arrived
    /// while the socket is already `.connected` (i.e. healthy connection,
    /// stale heartbeats — distinct from socket-level disconnect).
    private static let heartbeatFreshThreshold: TimeInterval = 5
    private static let heartbeatStaleThreshold: TimeInterval = 30

    private func connectionColor(at now: Date) -> Color {
        switch webSocketManager.connectionState {
        case .connected:
            return heartbeatColor(at: now)
        case .connecting, .authenticating:
            return .orange
        case .disconnected, .error, .authFailed:
            return .brandRed
        }
    }

    /// When the socket is `.connected`, the UI reflects heartbeat freshness
    /// rather than socket state alone — a connected-but-silent publisher
    /// surfaces as amber/red so operators notice stale data.
    private func heartbeatColor(at now: Date) -> Color {
        guard let last = webSocketManager.state.lastHeartbeatAt else {
            return .orange
        }
        let age = now.timeIntervalSince(last)
        if age <= Self.heartbeatFreshThreshold {
            return .brandGreen
        } else if age <= Self.heartbeatStaleThreshold {
            return .orange
        } else {
            return .brandRed
        }
    }

    private func connectionText(at now: Date) -> String {
        let language = appState.locale.catalogLanguage
        if webSocketManager.connectionState == .connected {
            let connectedLabel = webSocketManager.connectionState.displayName(in: language)
            if let last = webSocketManager.state.lastHeartbeatAt {
                let age = Int(now.timeIntervalSince(last))
                let heartbeat = LocaleStrings.localizedPlural(
                    "home.heartbeatAge.seconds",
                    count: age,
                    in: language
                )
                return "\(connectedLabel) · \(heartbeat)"
            }
            return connectedLabel
        }
        return webSocketManager.connectionState.displayName(in: language)
    }

    private func systemStatusView(status: SystemStatus) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(LocalizedStringKey("home.systemStatus.traderStatus"))
                    .font(.headline)
                Spacer()
                Text(status.trader.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status.trader.status == "running" ? Color.brandGreen.opacity(0.2) : Color.brandRed.opacity(0.2))
                    .cornerRadius(4)
            }

            if let strategies = status.strategies, !strategies.isEmpty {
                Divider()
                HStack {
                    Text(LocalizedStringKey("home.systemStatus.activeStrategies"))
                        .font(.subheadline)
                    Spacer()
                    Text("\(strategies.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            Divider()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                statView(
                    title: LocaleStrings.localized("home.section.openPositions", in: appState.locale.catalogLanguage),
                    value: "\(filteredPositions.count)"
                )
                statView(
                    title: LocaleStrings.localized("home.systemStatus.activeOrders", in: appState.locale.catalogLanguage),
                    value: "\(filteredActiveOrders.count)"
                )
            }
        }
        .padding()
        .background(Color.bgSurface)
        .cornerRadius(12)
    }

    private func statView(title: String, value: String, color: Color = .textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.textSecondary)

            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var positionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("home.section.openPositions"))
                .font(.headline)

            ForEach(filteredPositions, id: \.id) { position in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(position.instrument)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(String(
                            format: LocaleStrings.localized("home.position.qtyAtPrice", in: appState.locale.catalogLanguage),
                            position.quantity.formattedDecimal(in: appState.locale, fractionDigits: 4),
                            position.averagePrice?.formattedDecimal(in: appState.locale, fractionDigits: 2) ?? "—"
                        ))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(verbatim: position.unrealizedPnl?.formattedCurrency(in: appState.locale, code: "USD", fractionDigits: 2) ?? "—")
                            .font(.subheadline)
                            .foregroundColor(
                                position.unrealizedPnl.map {
                                    $0 >= 0 ? Color.financialRising(for: appState) : Color.financialFalling(for: appState)
                                } ?? Color.secondary
                            )

                        Text(LocalizedStringKey("home.position.unrealizedPnl"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                Divider()
            }
        }
        .padding()
        .background(Color.bgSurface)
        .cornerRadius(12)
    }

    private var recentOrdersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("home.section.recentOrders"))
                .font(.headline)

            ForEach(filteredOrders.prefix(5), id: \.id) { order in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.instrument)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("\(order.side.uppercased()) \(order.size.formattedDecimal(in: appState.locale, fractionDigits: 4))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(order.status)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(for: order.status))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .padding(.vertical, 8)
                Divider()
            }
        }
        .padding()
        .background(Color.bgSurface)
        .cornerRadius(12)
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        async let statusResult = APIClient.shared.fetchSystemStatus()
        async let positionsResult = APIClient.shared.fetchPositions()
        async let ordersResult = APIClient.shared.fetchOrders()

        do {
            systemStatus = try await statusResult
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            positions = try await positionsResult
        } catch {
            logger.error("Failed to fetch positions: \(error)")
        }

        do {
            orders = try await ordersResult
        } catch {
            logger.error("Failed to fetch orders: \(error)")
        }

        isLoading = false
    }

    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "filled":
            return .brandGreen
        case "pending", "open":
            return .brandRed
        case "cancelled", "rejected":
            return .lossRed
        case "partially_filled":
            return .orange
        default:
            return .textSecondary
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(WebSocketManager.shared)
            .environment(AppState.shared)
            .environmentObject(AuthService.shared)
    }
}
