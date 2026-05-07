import Combine
import Foundation
import Observation
import os

/// ViewModel for `PositionsView` — extracted in v0.3.1. The View
/// becomes a thin List binder; the VM owns positions data, async
/// I/O, the four submit flows (market-reduce, bracket, trailing
/// stop, close-via-market-reduce), the wallet-scoped filter, and
/// the derived `canSubmitReduce` / `makeReduceCommand` helpers.
///
/// Sheet/alert presentation flags (`actionSheetPosition`,
/// `reduceModalPosition`, `bracketModalPosition`,
/// `trailingStopModalPosition`, `pendingClosePosition`) stay as
/// `@State` in the View per Q3 of the architect consensus —
/// they're SwiftUI-binding-bound presentation state.
@MainActor
@Observable
final class PositionsViewModel {

    var positions: [PositionSnapshot] = []
    var isLoading: Bool = false
    var loadError: APIError?
    var submitError: String?

    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var liveReloadTask: Task<Void, Never>?

    /// Observation-window debounce. 250ms picked to match
    /// ``OrdersViewModel.liveReloadDebounceNanos``; positions
    /// update path is `ExecutionData` arrival → REST fetch of
    /// `/api/positions` (no `positions.` ZMQ topic exists).
    @ObservationIgnored static let liveReloadDebounceNanos: UInt64 = 250_000_000

    private let api: APIClientProtocol
    private let appState: AppState

    private let logger = AppLogger.make(category: "PositionsViewModel")

    init(
        api: APIClientProtocol = APIClient.shared,
        appState: AppState = .shared
    ) {
        self.api = api
        self.appState = appState
    }

    /// Begin observing ``WSState.lastExecution`` for debounced REST
    /// reload. Self-cleaning re-entry — safe to call repeatedly.
    func startObservingLiveUpdates(from state: WSState) {
        stopObservingLiveUpdates()
        observationTasks = [
            Task { @MainActor [weak self, weak state] in
                guard let stream = state?.$lastExecution.values.dropFirst() else { return }
                for await _ in stream {
                    guard let self else { return }
                    self.scheduleDebouncedReload()
                }
            },
        ]
    }

    /// Cancel observation + pending debounce. Idempotent.
    func stopObservingLiveUpdates() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        liveReloadTask?.cancel()
        liveReloadTask = nil
    }

    private func scheduleDebouncedReload() {
        liveReloadTask?.cancel()
        liveReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.liveReloadDebounceNanos)
            guard !Task.isCancelled, let self else { return }
            await self.load()
        }
    }

    var filteredPositions: [PositionSnapshot] {
        return Self.filter(
            positions: positions,
            selectedWalletPublicId: appState.selectedWalletPublicId
        )
    }
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            positions = try await api.fetchPositions()
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch positions: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch positions: \(error.localizedDescription, privacy: .public)")
            loadError = .invalidResponse
        }
    }

    @discardableResult
    func submitMarketReduce(position: PositionSnapshot, quantity: Double) async -> Bool {
        guard let command = Self.makeReduceCommand(position: position, quantity: quantity) else {
            logger.error("Refusing to submit reduce/close: position missing instrument or wallet public id")
            submitError = "Position is missing the wallet or instrument identifier the backend requires. Try refreshing the positions list."
            return false
        }
        do {
            _ = try await api.createOrder(command: command)
            await load()
            return true
        } catch {
            logger.error("Failed to submit reduce/close: \(error.localizedDescription, privacy: .public)")
            submitError = "Couldn't submit the order. Try again."
            return false
        }
    }

    @discardableResult
    func submitBracket(
        position: PositionSnapshot,
        slPrice: Double?,
        tpPrice: Double?,
        idempotencyKey: String
    ) async -> Bool {
        guard let cycleId = position.positionCyclePublicId else {
            submitError = "Position has no active cycle to attach a bracket to."
            return false
        }
        do {
            let command = AttachBracketSheetViewModel.makeCommand(
                positionCyclePublicId: cycleId,
                slPrice: slPrice,
                tpPrice: tpPrice,
                idempotencyKey: idempotencyKey
            )
            _ = try await api.createBracket(command: command)
            await load()
            return true
        } catch {
            logger.error("Failed to submit bracket: \(error.localizedDescription, privacy: .public)")
            submitError = "Couldn't attach bracket. Try again."
            return false
        }
    }

    @discardableResult
    func submitTrailingStop(
        position: PositionSnapshot,
        trailingPct: Double,
        minLockPct: Double?,
        idempotencyKey: String
    ) async -> Bool {
        guard let cycleId = position.positionCyclePublicId else {
            submitError = "Position has no active cycle to attach a trailing stop to."
            return false
        }
        do {
            let command = AttachTrailingStopSheetViewModel.makeCommand(
                positionCyclePublicId: cycleId,
                trailingPct: trailingPct,
                minLockPct: minLockPct,
                idempotencyKey: idempotencyKey
            )
            _ = try await api.createTrailingStop(command: command)
            await load()
            return true
        } catch {
            logger.error("Failed to submit trailing stop: \(error.localizedDescription, privacy: .public)")
            submitError = "Couldn't attach trailing stop. Try again."
            return false
        }
    }
    /// Backward-compatible test contract.
    /// Pure wallet-match helper. `nil` selection passes through every
    /// row, and `nil` row-side wallet passes through so legacy /
    /// system rows are never silently dropped.
    static func walletMatches(rowWalletId: String?, selected: String?) -> Bool {
        guard let selected else { return true }
        guard let rowWalletId else { return true }
        return rowWalletId == selected
    }

    static func filter(
        positions: [PositionSnapshot],
        selectedWalletPublicId: String?
    ) -> [PositionSnapshot] {
        return positions.filter { position in
            walletMatches(
                rowWalletId: position.walletPublicId,
                selected: selectedWalletPublicId
            )
        }
    }

    /// Decision helper for the error-state branch — returns `true`
    /// when the body should render the "couldn't load" variant
    /// instead of either the generic empty state or the cached list.
    /// We only surface the error variant when there is nothing else
    /// to show.
    static func shouldShowLoadError(
        filteredCount: Int,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard loadError != nil else { return false }
        return filteredCount == 0
    }

    /// Reduce / close eligibility: backend rejects `CreateOrderBody`
    /// with empty `instrumentPublicId` or `walletPublicId` so the UI
    /// must hide the trading actions for legacy / system rows that
    /// arrive without those ids.
    static func canSubmitReduce(position: PositionSnapshot) -> Bool {
        guard
            let walletId = position.walletPublicId, !walletId.isEmpty,
            let instrumentId = position.instrumentPublicId, !instrumentId.isEmpty
        else {
            return false
        }
        return true
    }

    /// Build the iOS-side `CreateOrderCommand` envelope for a
    /// reduce-only market order on the given position.
    @MainActor
    static func makeReduceCommand(
        position: PositionSnapshot,
        quantity: Double,
        provenance: EnvelopeMinter.Provenance? = nil
    ) -> CreateOrderCommand? {
        guard
            let walletId = position.walletPublicId, !walletId.isEmpty,
            let instrumentId = position.instrumentPublicId, !instrumentId.isEmpty
        else {
            return nil
        }
        let envelope = provenance ?? EnvelopeMinter.shared.next(.control)
        let side: String = position.quantity > 0 ? "sell" : "buy"
        return CreateOrderCommand(
            type: "create_order_command",
            sequenceId: envelope.sequenceId,
            publicId: envelope.publicId,
            timestamp: envelope.timestamp,
            sessionId: envelope.sessionId,
            topic: nil,
            payload: CreateOrderBody(
                instrument: position.instrument,
                instrumentPublicId: instrumentId,
                exchange: position.exchange,
                mode: position.mode,
                side: side,
                orderType: "market",
                quantity: quantity,
                price: nil,
                stopPrice: nil,
                timeInForce: "GTC",
                postOnly: false,
                leverage: nil,
                reduceOnly: true,
                walletPublicId: walletId,
                operatorPublicId: nil,
                idempotencyKey: nil,
                aiReviewPublicId: nil
            )
        )
    }
}
