import Foundation
import Combine

/// Single source of truth for live WebSocket-driven feature state.
///
/// The dispatcher inside `WebSocketManager` updates these `@Published`
/// properties when typed frames arrive. Views observe the properties
/// they care about (e.g. `HomeView` watches `lastHeartbeatAt` to
/// drive the connection-dot color). Remaining types fall back to the
/// dispatcher's `.debug` log passthrough — bindings for them land in
/// Plan 2 alongside the push-notification work.
///
/// All mutation happens on the main actor via the manager's dispatcher,
/// so SwiftUI observers receive updates without bridging.
@MainActor
final class WSState: ObservableObject {
    @Published var lastTrade: TradeData?
    @Published var lastOrderEvent: OrderEventData?
    @Published var lastExecution: ExecutionData?
    @Published var lastOrderCancel: OrderCancelData?
    @Published var lastHeartbeat: HeartbeatData?
    @Published var lastUserDeactivated: UserDeactivatedData?
    @Published var wsTokenExp: Date?
    @Published var lastHeartbeatAt: Date?
    /// Latest streaming candle frame from `market.*.candles.*`.
    /// Observed by ``MarketDataViewModel`` via the Combine
    /// `$lastCandle.values.dropFirst()` async-sequence pattern.
    @Published var lastCandle: CandleData?
    /// Latest streaming tick frame from `market.*.ticks`.
    /// Drives the "delayed data" pill and feeds the metric
    /// card's `lastPrice` field on the Market screen.
    @Published var lastTick: TickData?
}
