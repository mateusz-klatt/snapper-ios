import Combine
import Foundation
import Observation
import os

/// ViewModel for ``MarketDataView`` — owns exchange/instrument/
/// timeframe selection, the candle snapshot, WS-driven live
/// merges, and the 24h metric set.
///
/// Snapshot + WS-buffer flow (mirrors the frontend WSDispatcher):
/// 1. Selection changes bump ``selectionGeneration`` so any
///    in-flight async result whose generation has moved on is
///    silently discarded.
/// 2. The VM subscribes to the new (candle, tick) topics
///    immediately. Incoming candle frames whose generation
///    matches the current one are appended to ``pendingCandles``.
/// 3. REST snapshot returns → merge ``pendingCandles`` by
///    ``openAt`` (replace existing, append ahead) → set
///    ``isReady = true`` → flush.
/// 4. After ready, new WS frames apply directly under a 200 ms
///    leading-edge throttle: the FIRST frame in a window emits
///    immediately, subsequent frames inside the same window are
///    coalesced into the buffer and emitted when the window
///    opens.
///
/// Concurrency: ``@MainActor`` for view-bound state. WS observation
/// uses the Combine async-sequence pattern matching
/// ``PositionsViewModel`` — ``WSState`` is ``ObservableObject`` /
/// ``@Published``, not ``@Observable``, so ``withObservationTracking``
/// would silently miss updates.
@MainActor
@Observable
final class MarketDataViewModel {

    var exchanges: [String] = []
    var instruments: [InstrumentDetailData] = []
    var selectedExchange: String?
    var selectedInstrument: InstrumentDetailData?
    var selectedTimeframe: MarketTimeframe = .oneHour
    var candles: [MarketCandle] = []
    var metrics: MarketMetrics = .empty
    var isReady: Bool = false
    var isLoading: Bool = false
    var loadError: APIError?
    var showInstrumentPicker: Bool = false

    @ObservationIgnored private var selectionGeneration: Int = 0
    @ObservationIgnored private var pendingCandles: [MarketCandle] = []
    @ObservationIgnored private var lastEmittedAt: Date = .distantPast

    @ObservationIgnored static let throttleNanos: UInt64 = 200_000_000
    @ObservationIgnored static let throttleWindowSeconds: TimeInterval = 0.2

    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []

    /// Single pending flush slot. ``scheduleFlushIfNeeded`` reuses
    /// the slot — only one trailing flush at a time — so an active
    /// stream of suppressed frames cannot accumulate one task per
    /// frame (which would violate the leading-edge throttle bound
    /// AND leak completed-Task storage into ``observationTasks``).
    @ObservationIgnored private var pendingFlushTask: Task<Void, Never>?
    @ObservationIgnored private let api: APIClientProtocol
    @ObservationIgnored private weak var webSocketManager: WebSocketManager?
    @ObservationIgnored private let logger = AppLogger.make(category: "MarketDataViewModel")

    init(
        api: APIClientProtocol = APIClient.shared,
        webSocketManager: WebSocketManager
    ) {
        self.api = api
        self.webSocketManager = webSocketManager
    }

    /// Load the exchange list and seed default selection. Called
    /// from the View's ``.task`` modifier.
    func start() async {
        startObservingFrames()
        startObservingConnectionState()
        await loadExchanges()
        await applyDevAutoSelectIfRequested()
    }

    /// DEBUG-only auto-selection hook. When the simulator is
    /// launched with ``UserDefaults.snapper.devStartOnMarket = true``,
    /// auto-pick BTC-USD on the 1m timeframe so the screen renders
    /// with live data immediately. UI automation against the
    /// Simulator window is brittle in the iOS 17/26 toolchain on
    /// macOS without screen-recording permission; this hook
    /// sidesteps that for the dev/screenshot pipeline. Never reads
    /// in release builds.
    @MainActor
    private func applyDevAutoSelectIfRequested() async {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "snapper.devStartOnMarket") else { return }
        selectedTimeframe = .oneMinute
        if let kraken = exchanges.first(where: { $0 == "kraken" }) ?? exchanges.first {
            await selectExchange(kraken)
        }
        let preferredSymbol = "BTC-USD"
        if let preferred = instruments.first(where: { $0.symbol == preferredSymbol })
            ?? instruments.first {
            await selectInstrument(preferred)
        }
        #endif
    }

    /// Cancel observation tasks and unsubscribe from any active
    /// market topics. Called from ``.onDisappear``.
    func stop() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        pendingFlushTask?.cancel()
        pendingFlushTask = nil
        unsubscribeCurrentSelection()
    }

    func loadExchanges() async {
        isLoading = true
        loadError = nil
        do {
            let fetched = try await api.fetchExchanges()
            exchanges = fetched
            if selectedExchange == nil, let preferred = pickDefaultExchange(from: fetched) {
                await selectExchange(preferred)
            }
        } catch let error as APIError {
            loadError = error
        } catch {
            loadError = .serverError(error.localizedDescription)
        }
        isLoading = false
    }

    private func pickDefaultExchange(from exchanges: [String]) -> String? {
        if exchanges.contains("kraken") { return "kraken" }
        return exchanges.first
    }

    func selectExchange(_ exchange: String) async {
        unsubscribeCurrentSelection()
        selectedExchange = exchange
        selectedInstrument = nil
        candles.removeAll()
        pendingCandles.removeAll()
        metrics = .empty
        isReady = false
        loadError = nil
        selectionGeneration &+= 1
        await loadInstruments(for: exchange)
    }

    private func loadInstruments(for exchange: String) async {
        let generation = selectionGeneration
        do {
            let fetched = try await api.fetchInstruments(exchange: exchange)
            guard generation == selectionGeneration else { return }
            instruments = fetched.filter { $0.canMarketData }
        } catch let error as APIError {
            guard generation == selectionGeneration else { return }
            loadError = error
        } catch {
            guard generation == selectionGeneration else { return }
            loadError = .serverError(error.localizedDescription)
        }
    }

    func selectInstrument(_ instrument: InstrumentDetailData) async {
        unsubscribeCurrentSelection()
        selectedInstrument = instrument
        candles.removeAll()
        pendingCandles.removeAll()
        metrics = .empty
        isReady = false
        loadError = nil
        showInstrumentPicker = false
        selectionGeneration &+= 1
        subscribeCurrentSelection()
        await fetchChartAndMetrics()
    }

    func selectTimeframe(_ timeframe: MarketTimeframe) async {
        guard selectedInstrument != nil else {
            selectedTimeframe = timeframe
            return
        }
        unsubscribeCurrentSelection()
        selectedTimeframe = timeframe
        candles.removeAll()
        pendingCandles.removeAll()
        isReady = false
        loadError = nil
        selectionGeneration &+= 1
        subscribeCurrentSelection()
        await fetchChartAndMetrics()
    }

    private func fetchChartAndMetrics() async {
        guard let exchange = selectedExchange, let instrument = selectedInstrument else { return }
        let generation = selectionGeneration
        isLoading = true
        loadError = nil
        defer {
            /// Clear ``isLoading`` only when the result we observed
            /// is still the current selection; otherwise a newer
            /// `fetchChartAndMetrics` is already in flight and is
            /// responsible for its own loading state. Without this
            /// guard a fast selection switch could leave the screen
            /// stuck in a `ProgressView` when the older fetch
            /// resolves after the newer one.
            if generation == selectionGeneration { isLoading = false }
        }
        do {
            async let chartCandlesTask = api.fetchCandles(
                exchange: exchange,
                instrument: instrument.symbol,
                timeframe: selectedTimeframe,
                limit: 100,
                asOf: nil
            )
            async let metricsCandlesTask = api.fetchCandles(
                exchange: exchange,
                instrument: instrument.symbol,
                timeframe: .oneHour,
                limit: 25,
                asOf: nil
            )
            let chartCandles = try await chartCandlesTask
            let metricsCandles = try await metricsCandlesTask
            guard generation == selectionGeneration else { return }
            mergeBufferIntoSnapshot(snapshot: chartCandles)
            metrics = computeMetrics(
                from: metricsCandles,
                lastTick: lastTickForCurrentSelection()
            )
            isReady = true
        } catch let error as APIError {
            guard generation == selectionGeneration else { return }
            loadError = error
        } catch {
            guard generation == selectionGeneration else { return }
            loadError = .serverError(error.localizedDescription)
        }
    }

    /// Return ``WSState.lastTick`` ONLY if it matches the current
    /// (exchange, instrument). After switching instruments the
    /// global slot can briefly carry the previous symbol's tick;
    /// using it for the new symbol's "last price" would surface
    /// a wrong value until the next per-symbol tick arrives.
    private func lastTickForCurrentSelection() -> TickData? {
        guard let exchange = selectedExchange,
              let instrument = selectedInstrument,
              let tick = webSocketManager?.state.lastTick,
              tick.exchange == exchange,
              tick.instrument == instrument.symbol else { return nil }
        return tick
    }

    /// Merge the REST snapshot with any buffered WS frames that
    /// arrived during the fetch. Buffered candles are applied in
    /// ``openAt`` order: a buffered candle replaces the snapshot
    /// row at the same time, OR is appended when ahead of the
    /// snapshot's tail.
    private func mergeBufferIntoSnapshot(snapshot: [MarketCandle]) {
        var merged = snapshot.sorted(by: { $0.openAt < $1.openAt })
        let sortedBuffer = pendingCandles.sorted(by: { $0.openAt < $1.openAt })
        for buffered in sortedBuffer {
            if let index = merged.firstIndex(where: { $0.openAt == buffered.openAt }) {
                merged[index] = buffered
            } else if let last = merged.last, buffered.openAt > last.openAt {
                merged.append(buffered)
            }
        }
        candles = merged
        pendingCandles.removeAll()
    }

    private func computeMetrics(
        from hourlyCandles: [MarketCandle],
        lastTick: TickData?
    ) -> MarketMetrics {
        let sorted = hourlyCandles.sorted(by: { $0.openAt < $1.openAt })
        let lastPriceDecimal: Decimal?
        if let last = lastTick?.last, let d = Decimal(string: String(describing: last)) {
            lastPriceDecimal = d
        } else {
            lastPriceDecimal = sorted.last?.close
        }
        let high24h = sorted.map(\.high).max()
        let low24h = sorted.map(\.low).min()
        let changePct: Decimal?
        if let first = sorted.first?.open, let last = sorted.last?.close, first > 0 {
            changePct = ((last - first) / first) * Decimal(100)
        } else {
            changePct = nil
        }
        return MarketMetrics(
            lastPrice: lastPriceDecimal,
            changePct24h: changePct,
            high24h: high24h,
            low24h: low24h,
            isDelayed: lastTick?.isDelayed ?? false
        )
    }

    private func subscribeCurrentSelection() {
        guard let manager = webSocketManager,
              let exchange = selectedExchange,
              let instrument = selectedInstrument else { return }
        let topics = [
            MarketTopic.candle(exchange: exchange, instrument: instrument.symbol, timeframe: selectedTimeframe),
            MarketTopic.tick(exchange: exchange, instrument: instrument.symbol)
        ]
        manager.subscribe(topics: topics)
    }

    private func unsubscribeCurrentSelection() {
        guard let manager = webSocketManager,
              let exchange = selectedExchange,
              let instrument = selectedInstrument else { return }
        let topics = [
            MarketTopic.candle(exchange: exchange, instrument: instrument.symbol, timeframe: selectedTimeframe),
            MarketTopic.tick(exchange: exchange, instrument: instrument.symbol)
        ]
        manager.unsubscribe(topics: topics)
    }

    private func resubscribeCurrentSelection() {
        subscribeCurrentSelection()
    }

    /// Combine async-sequence observation over ``WSState``'s
    /// ``@Published`` slots. ``WSState`` is ``ObservableObject`` —
    /// ``withObservationTracking`` would silently not track its
    /// updates, so we go through ``$lastCandle.values.dropFirst()``
    /// the same way [PositionsViewModel](Snapper/ViewModels/PositionsViewModel.swift)
    /// does.
    private func startObservingFrames() {
        guard let manager = webSocketManager else { return }
        let stateRef = manager.state
        observationTasks.append(Task { @MainActor [weak self, weak stateRef] in
            guard let stream = stateRef?.$lastCandle.values.dropFirst() else { return }
            for await frame in stream {
                guard let self else { return }
                if let frame { self.handleIncomingCandle(frame) }
            }
        })
        observationTasks.append(Task { @MainActor [weak self, weak stateRef] in
            guard let stream = stateRef?.$lastTick.values.dropFirst() else { return }
            for await tick in stream {
                guard let self else { return }
                if let tick { self.handleIncomingTick(tick) }
            }
        })
    }

    /// Observe ``WebSocketManager.$connectionState`` for
    /// ``.disconnected`` → ``.connected`` transitions.
    /// ``disconnect()`` clears ``subscribedTopics`` (e.g. on a
    /// scene-backgrounding ``SnapperApp`` hook); without this
    /// observer, foregrounding would never resume market streaming.
    private func startObservingConnectionState() {
        guard let manager = webSocketManager else { return }
        observationTasks.append(Task { @MainActor [weak self, weak manager] in
            guard let stream = manager?.$connectionState.values.dropFirst() else { return }
            for await newState in stream {
                guard let self else { return }
                if case .connected = newState {
                    self.resubscribeCurrentSelection()
                }
            }
        })
    }

    private func handleIncomingCandle(_ frame: CandleData) {
        guard let exchange = selectedExchange,
              let instrument = selectedInstrument,
              frame.exchange == exchange,
              frame.instrument == instrument.symbol,
              frame.timeframe == selectedTimeframe.rawValue else { return }
        guard let candle = MarketCandle.from(wsCandleData: frame) else { return }
        if !isReady {
            pendingCandles.append(candle)
            return
        }
        if shouldEmitNow(at: Date()) {
            applyCandle(candle)
        } else {
            pendingCandles.append(candle)
            scheduleFlushIfNeeded()
        }
    }

    private func handleIncomingTick(_ tick: TickData) {
        guard let exchange = selectedExchange,
              let instrument = selectedInstrument,
              tick.exchange == exchange,
              tick.instrument == instrument.symbol else { return }
        let lastPrice: Decimal?
        if let value = tick.last, let d = Decimal(string: String(describing: value)) {
            lastPrice = d
        } else {
            lastPrice = metrics.lastPrice
        }
        metrics = MarketMetrics(
            lastPrice: lastPrice,
            changePct24h: metrics.changePct24h,
            high24h: metrics.high24h,
            low24h: metrics.low24h,
            isDelayed: tick.isDelayed ?? false
        )
    }

    /// Leading-edge throttle gate. The first frame in a 200 ms
    /// window emits immediately; subsequent frames are buffered.
    private func shouldEmitNow(at now: Date) -> Bool {
        if now.timeIntervalSince(lastEmittedAt) >= Self.throttleWindowSeconds {
            lastEmittedAt = now
            return true
        }
        return false
    }

    private func scheduleFlushIfNeeded() {
        if pendingFlushTask != nil { return }
        let generation = selectionGeneration
        pendingFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.throttleNanos)
            guard let self else { return }
            self.pendingFlushTask = nil
            guard generation == self.selectionGeneration else { return }
            self.flushPendingBuffer()
        }
    }

    private func flushPendingBuffer() {
        guard !pendingCandles.isEmpty else { return }
        let sortedBuffer = pendingCandles.sorted(by: { $0.openAt < $1.openAt })
        pendingCandles.removeAll()
        for candle in sortedBuffer {
            applyCandle(candle)
        }
        lastEmittedAt = Date()
    }

    private func applyCandle(_ candle: MarketCandle) {
        if let index = candles.firstIndex(where: { $0.openAt == candle.openAt }) {
            candles[index] = candle
        } else if let last = candles.last, candle.openAt > last.openAt {
            candles.append(candle)
            if candles.count > 100 { candles.removeFirst(candles.count - 100) }
        } else if candles.isEmpty {
            candles = [candle]
        }
    }
}
