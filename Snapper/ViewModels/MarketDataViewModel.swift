import Combine
import Foundation
import Observation
import os

/// Failure surface for ``MarketDataViewModel.selectMarket(exchange:symbol:)``
/// — the cross-exchange navigation entry point used by the related-
/// instruments row. Distinct from ``APIError`` because the failure is
/// data-shape ("instrument not in catalog"), not network/HTTP.
enum MarketSelectionError: Equatable {
    case instrumentNotFound(exchange: String, symbol: String)
}

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
    var selectedTimeframe: MarketTimeframe = .oneMinute
    var candles: [MarketCandle] = []
    var metrics: MarketMetrics = .empty
    var isReady: Bool = false
    var isLoading: Bool = false
    var loadError: APIError?
    var showInstrumentPicker: Bool = false

    /// Related-instruments envelope (underlying + sector + grouped
    /// derivatives) returned by ``GET /api/instruments/.../related``.
    /// Populated alongside the chart/metrics fetch in
    /// ``fetchChartAndMetrics`` and refreshed when the user changes
    /// locale (so the description repaints in the new language).
    /// ``nil`` until the first fetch resolves.
    var relatedResponse: RelatedInstrumentsResponse?

    /// Mirrors ``isLoading`` for the related-instruments fetch so the
    /// banner can show a skeleton independently of the chart fetch.
    var isLoadingRelated: Bool = false

    /// Surfaces failures from ``selectMarket(exchange:symbol:)`` —
    /// specifically the "instrument not in catalog" case the related-
    /// instruments row can hit when the user taps a derivative chip
    /// whose target instrument no longer exists on the destination
    /// venue. Cleared on the next successful navigation.
    var marketSelectionError: MarketSelectionError?

    /// Cache-warming snapshot reflecting the METRICS cache endpoint
    /// (``GET /api/candles/cache?timeframe=1h&limit=25``) — the
    /// surface the 24h metric grid above the chart consumes. NOT
    /// the chart-candles cache state; the chart still calls
    /// ``GET /api/candles`` directly. The banner therefore tells
    /// the operator "the data infrastructure is still building the
    /// metrics dataset"; it does not represent the chart's data
    /// freshness. Placed inside the chart container per the web
    /// reference layout where the same visual hierarchy holds.
    var cacheState: CacheStateSnapshot?

    /// Configured-pair cointegration stats fetched once per session
    /// from ``GET /api/market/cache/stats/configured``. The
    /// ``PairStatsRowView`` filters this to the chips relevant to
    /// the current selection via ``filteredPairChips``.
    var pairStats: ListedCachedStatsResponse?

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
    /// Single-flight handle for the locale-persist refetch task.
    /// Each `.appStateLocaleDidPersist` notification cancels any
    /// in-flight refetch and starts a new one — without this, a
    /// rapid locale flip (en → pl → de) could let the en refetch
    /// resolve after the pl refetch and overwrite the banner with
    /// the older language.
    @ObservationIgnored private var pendingRelatedRefetchTask: Task<Void, Never>?
    /// Monotonic counter incremented at the start of each
    /// ``selectMarket(exchange:symbol:)`` invocation. The probe-then-
    /// commit flow for cross-exchange navigation suspends on
    /// ``fetchInstruments`` before mutating state, so two quick chip
    /// taps can race: the older fetch may resolve last and commit
    /// the wrong venue. Each invocation captures the generation at
    /// entry and verifies it still matches before each state
    /// mutation; stale invocations bail out without touching the VM.
    @ObservationIgnored private var marketSelectionGeneration: Int = 0
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
        startObservingLocalePersistNotification()
        await loadExchanges()
        await loadConfiguredPairStats()
        await applyDevAutoSelectIfRequested()
    }

    /// Fetch the configured-pair cointegration stats list ONCE per
    /// session and cache in ``pairStats``. Failures log + leave the
    /// row hidden — non-fatal because the rest of the screen does
    /// not depend on it.
    private func loadConfiguredPairStats() async {
        do {
            pairStats = try await api.fetchAllConfiguredPairStats()
        } catch {
            logger.warning("fetchAllConfiguredPairStats failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// View-model shape for one pair-stats chip the row renders.
    /// Computed lazily from ``pairStats`` + the current selection.
    var filteredPairChips: [PairStatsChipModel] {
        guard let pairs = pairStats?.payload.pairs,
              let exchange = selectedExchange,
              let symbol = selectedInstrument?.symbol
        else {
            return []
        }
        let selfKey = "\(exchange):\(symbol)"
        return PairStatsRowLogic.buildChips(pairs: pairs, selfKey: selfKey)
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
        pendingRelatedRefetchTask?.cancel()
        pendingRelatedRefetchTask = nil
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
        resetSelectionStateForExchangeChange(to: exchange)
        await loadInstruments(for: exchange, autoPickDefault: true)
    }

    /// Reset per-instrument state for a venue change.
    ///
    /// Mutates: ``selectedExchange``, ``selectedInstrument``,
    /// ``instruments`` (cleared so the picker does not briefly list
    /// the previous venue's catalog while the new one loads),
    /// ``candles`` / ``pendingCandles``, ``metrics``,
    /// ``relatedResponse`` (so the previous market's banner does not
    /// flash through while the new fetch is in flight), ``isReady``,
    /// ``loadError``, ``showInstrumentPicker`` (closed so a stale
    /// sheet cannot survive the transition). Bumps
    /// ``selectionGeneration`` so any in-flight fetches drop their
    /// results when they resolve.
    private func resetSelectionStateForExchangeChange(to exchange: String) {
        unsubscribeCurrentSelection()
        selectedExchange = exchange
        selectedInstrument = nil
        instruments = []
        candles.removeAll()
        pendingCandles.removeAll()
        metrics = .empty
        relatedResponse = nil
        cacheState = nil
        isReady = false
        loadError = nil
        showInstrumentPicker = false
        selectionGeneration &+= 1
    }

    /// Load the instrument catalog for a venue.
    ///
    /// ``autoPickDefault`` controls whether the post-fetch hook
    /// auto-selects a default instrument (BTC-USD / BTC-USD-PERP /
    /// first capable). Targeted navigation via ``selectMarket`` sets
    /// this to ``false`` so the catalog is loaded but the visible
    /// selection is not committed until the caller resolves and
    /// selects the requested symbol — without that hook, a tap on a
    /// cross-exchange chip would auto-pick the destination venue's
    /// default instrument first (visible flash + wasted chart fetch)
    /// before re-selecting the actual target.
    private func loadInstruments(for exchange: String, autoPickDefault: Bool) async {
        let generation = selectionGeneration
        do {
            let fetched = try await api.fetchInstruments(exchange: exchange)
            guard generation == selectionGeneration else { return }
            instruments = fetched.filter { $0.canMarketData }
            if autoPickDefault {
                await autoPickDefaultInstrumentIfNeeded()
            }
        } catch let error as APIError {
            guard generation == selectionGeneration else { return }
            loadError = error
        } catch {
            guard generation == selectionGeneration else { return }
            loadError = .serverError(error.localizedDescription)
        }
    }

    /// Auto-pick a market-data instrument after a successful
    /// ``loadInstruments`` so the chart surface lands on real data
    /// instead of an empty-state on first reach. Prefers a
    /// high-recognition symbol (``BTC-USD`` then ``BTC-USD-PERP``);
    /// falls back to the first market-data-capable instrument the
    /// backend returns. No-op when the user has already chosen an
    /// instrument or when the picker list is empty.
    @MainActor
    private func autoPickDefaultInstrumentIfNeeded() async {
        guard selectedInstrument == nil else { return }
        let preferredSymbols = ["BTC-USD", "BTC-USD-PERP"]
        let preferred = preferredSymbols
            .compactMap { sym in instruments.first(where: { $0.symbol == sym }) }
            .first
        guard let pick = preferred ?? instruments.first else { return }
        await selectInstrument(pick)
    }

    func selectInstrument(_ instrument: InstrumentDetailData) async {
        unsubscribeCurrentSelection()
        selectedInstrument = instrument
        candles.removeAll()
        pendingCandles.removeAll()
        metrics = .empty
        /// Clear the previous market's banner data + cache state
        /// before the new fetch starts so the chip/ticker/name/
        /// description + warming banner do not flash through during
        /// navigation. The skeleton path picks up while
        /// ``isLoadingRelated`` is true.
        relatedResponse = nil
        cacheState = nil
        isReady = false
        loadError = nil
        showInstrumentPicker = false
        selectionGeneration &+= 1
        subscribeCurrentSelection()
        await fetchChartAndMetrics()
    }

    /// Cross-exchange navigation entry point used by the related-
    /// instruments row. For a cross-exchange tap, probes the
    /// destination catalog BEFORE mutating any visible state so a
    /// miss does not visibly wipe the user's current selection (the
    /// user only sees the venue switch when the target is confirmed
    /// to exist there). Auto-pick is intentionally skipped on the
    /// commit path so the venue change does not briefly fetch chart/
    /// metrics/related for the destination venue's default
    /// instrument (e.g. BTC-USD on kraken) before re-selecting the
    /// actual target. Falls through with
    /// ``marketSelectionError = .instrumentNotFound`` on miss; the
    /// previous selection is preserved in both same-exchange and
    /// cross-exchange miss paths.
    func selectMarket(exchange: String, symbol: String) async {
        marketSelectionGeneration &+= 1
        let generation = marketSelectionGeneration
        if exchange != selectedExchange {
            let candidates: [InstrumentDetailData]
            do {
                let fetched = try await api.fetchInstruments(exchange: exchange)
                candidates = fetched.filter { $0.canMarketData }
            } catch {
                guard generation == marketSelectionGeneration else { return }
                marketSelectionError = .instrumentNotFound(exchange: exchange, symbol: symbol)
                logger.warning(
                    "selectMarket: destination catalog fetch failed — exchange=\(exchange, privacy: .public) symbol=\(symbol, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
                return
            }
            guard generation == marketSelectionGeneration else { return }
            guard let target = candidates.first(where: { $0.symbol == symbol }) else {
                marketSelectionError = .instrumentNotFound(exchange: exchange, symbol: symbol)
                logger.warning(
                    "selectMarket: instrument not found in destination catalog — exchange=\(exchange, privacy: .public) symbol=\(symbol, privacy: .public)"
                )
                return
            }
            resetSelectionStateForExchangeChange(to: exchange)
            instruments = candidates
            marketSelectionError = nil
            await selectInstrument(target)
            return
        }
        guard let target = instruments.first(where: { $0.symbol == symbol }) else {
            marketSelectionError = .instrumentNotFound(exchange: exchange, symbol: symbol)
            logger.warning(
                "selectMarket: instrument not found in catalog — exchange=\(exchange, privacy: .public) symbol=\(symbol, privacy: .public)"
            )
            return
        }
        guard generation == marketSelectionGeneration else { return }
        marketSelectionError = nil
        await selectInstrument(target)
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
        cacheState = nil
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
            if generation == selectionGeneration {
                isLoading = false
                isLoadingRelated = false
            }
        }
        do {
            async let chartCandlesTask = api.fetchCandles(
                exchange: exchange,
                instrument: instrument.symbol,
                timeframe: selectedTimeframe,
                limit: 100,
                asOf: nil
            )
            async let metricsCachedTask = api.fetchCachedCandles(
                exchange: exchange,
                symbol: instrument.symbol,
                timeframe: MarketTimeframe.oneHour.rawValue,
                limit: 25
            )
            isLoadingRelated = true
            async let relatedTask = api.fetchRelatedInstruments(
                exchange: exchange,
                symbol: instrument.symbol
            )
            let chartCandles = try await chartCandlesTask
            guard generation == selectionGeneration else { return }
            mergeBufferIntoSnapshot(snapshot: chartCandles)
            isReady = true
            /// Metrics-candles + cache-state come from a separate
            /// cached-endpoint. Failure is non-fatal: the chart
            /// surface above already populated, so an outage on the
            /// metrics/cache service must NOT blank the screen.
            /// Swallow the error after logging; the metric grid
            /// falls back to its ``.empty`` initial state and the
            /// warming banner stays hidden (``cacheState == nil``).
            do {
                let metricsCachedEnvelope = try await metricsCachedTask
                guard generation == selectionGeneration else { return }
                let metricsCandles = metricsCachedEnvelope.payload.candles.compactMap { $0.toMarketCandle() }
                metrics = computeMetrics(
                    from: metricsCandles,
                    lastTick: lastTickForCurrentSelection()
                )
                cacheState = CacheStateSnapshot(
                    isWarm: metricsCachedEnvelope.payload.isWarm,
                    sampleCount: metricsCachedEnvelope.payload.sampleCount,
                    source: metricsCachedEnvelope.payload.source
                )
            } catch {
                guard generation == selectionGeneration else { return }
                logger.warning("fetchCachedCandles (metrics) failed: \(String(describing: error), privacy: .public)")
            }
            /// Related-instruments fetch failure is non-fatal: the chart
            /// + metrics surfaces stay live; only the banner skeleton
            /// holds. Log loudly so an oncall reading the device log
            /// can correlate "no description visible" reports.
            do {
                let related = try await relatedTask
                guard generation == selectionGeneration else { return }
                relatedResponse = related
            } catch {
                guard generation == selectionGeneration else { return }
                /// Drop any stale (previous-market) response on failure
                /// so the banner reverts to skeleton/empty rather than
                /// keeping the prior chip/ticker/description visible
                /// indefinitely.
                relatedResponse = nil
                logger.warning("fetchRelatedInstruments failed: \(String(describing: error), privacy: .public)")
            }
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

    /// Subscribe to ``Notification.Name.appStateLocaleDidPersist`` —
    /// posted by ``AppState.syncLocaleToBackend`` after the backend
    /// accepts a new ``default_language``. On receipt, re-fetch the
    /// related-instruments envelope for the current selection so the
    /// banner description repaints in the new language without
    /// requiring the user to re-navigate.
    ///
    /// Subscription is filtered to ``object: nil`` so any ``AppState``
    /// instance can fire the refresh (matters for previews/tests that
    /// construct their own ``AppState``). The observer task is
    /// cancelled in ``stop()``.
    ///
    /// Latest-wins via ``pendingRelatedRefetchTask``: each notification
    /// cancels any in-flight refetch before scheduling its own. Without
    /// this, a rapid locale flip can race so the older request resolves
    /// after the newer one and repaints the banner with the stale
    /// language.
    private func startObservingLocalePersistNotification() {
        observationTasks.append(Task { @MainActor [weak self] in
            let stream = NotificationCenter.default.notifications(
                named: .appStateLocaleDidPersist
            )
            for await _ in stream {
                guard let self else { return }
                self.pendingRelatedRefetchTask?.cancel()
                self.pendingRelatedRefetchTask = Task { @MainActor [weak self] in
                    await self?.refetchRelatedForCurrentSelection()
                }
            }
        })
    }

    /// Re-fetch the related-instruments envelope for whatever is
    /// currently selected. No-op when no selection is set. Uses the
    /// same generation-token discipline as
    /// ``fetchChartAndMetrics`` so a stale fetch that lands after a
    /// new selection is silently discarded.
    private func refetchRelatedForCurrentSelection() async {
        guard let exchange = selectedExchange,
              let instrument = selectedInstrument else { return }
        let generation = selectionGeneration
        isLoadingRelated = true
        defer {
            if generation == selectionGeneration {
                isLoadingRelated = false
            }
        }
        do {
            let response = try await api.fetchRelatedInstruments(
                exchange: exchange,
                symbol: instrument.symbol
            )
            guard generation == selectionGeneration else { return }
            if Task.isCancelled { return }
            relatedResponse = response
        } catch {
            guard generation == selectionGeneration else { return }
            if Task.isCancelled { return }
            relatedResponse = nil
            logger.warning("refetchRelatedForCurrentSelection failed: \(String(describing: error), privacy: .public)")
        }
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
