import Foundation

/// View-model snapshot of the cache-warming endpoint payload.
/// Populated by ``MarketDataViewModel`` from the
/// ``CachedCandlesPayload`` sibling fields returned by the
/// chart-cache state probe (the per-selected-timeframe
/// ``/api/candles/cache`` request that drives the warming
/// banner). NOT sourced from the metrics-grid hourly probe —
/// that probe powers the 24h high/low cards and is intentionally
/// decoupled from this snapshot so cache-state failures and
/// metrics failures stay isolated.
///
/// Lives under ``Snapper/Models`` (not under ``Views/``) because the
/// ViewModel exposes ``cacheState: CacheStateSnapshot?`` as part of
/// its public surface — keeping the type in the View layer would
/// make the VM dependent on the chrome layer that is excluded from
/// coverage per ``docs/architecture-mvvm.md``.
struct CacheStateSnapshot: Equatable {
    let isWarm: Bool
    let sampleCount: Int
    let source: String
}

/// View-model shape for one chip rendered by ``PairStatsRowView``.
/// Built from the backend's ``CachedStatsPayload`` via
/// ``PairStatsRowLogic.buildChips`` — the chip carries only what the
/// row needs to render + navigate so the View body does not have to
/// re-derive peer information per render pass.
///
/// Lives under ``Snapper/Models`` because ``MarketDataViewModel``
/// exposes ``filteredPairChips: [PairStatsChipModel]``; see the
/// rationale on ``CacheStateSnapshot`` above.
struct PairStatsChipModel: Equatable {
    let otherExchange: String
    let otherSymbol: String
    let pearsonR: Double?
    let cointPvalue: Double?
    let isWarm: Bool
}

/// Pure logic helpers powering ``PairStatsRowView`` AND consumed by
/// ``MarketDataViewModel.filteredPairChips``. Lives in the Models
/// layer so the VM does not depend on the Views layer.
///
/// Mirrors the frontend's cointegration metric formatting + chip
/// sort + style threshold so iOS chips read the same as web. All
/// methods are pure (no I/O, no actor isolation).
enum PairStatsRowLogic {

    /// Threshold for considering a pair "cointegrated". Mirrors the
    /// web frontend's ``COINTEGRATION_P_THRESHOLD`` constant. A
    /// strictly-less-than comparison is used: a p-value EQUAL to
    /// the threshold is NOT cointegrated.
    static let cointegrationPThreshold: Double = 0.05

    /// U+2212 MINUS SIGN — the proper typographic minus, NOT
    /// ASCII hyphen (U+002D). The frontend `formatPearson` emits
    /// this glyph for negative correlation values; iOS mirrors so
    /// the chip text is identical across platforms.
    static let minusSign: String = "\u{2212}"

    /// Format Pearson r as a signed 2-decimal string. ``nil`` →
    /// em-dash. Positive values get a ``+`` prefix; negative values
    /// use U+2212. Mirrors the web ``formatPearson`` helper exactly.
    static func signedPearsonString(_ r: Double?) -> String {
        guard let value = r else {
            return "—"
        }
        let magnitude = abs(value)
        let formatted = String(format: "%.2f", magnitude)
        if value < 0 {
            return "\(minusSign)\(formatted)"
        }
        return "+\(formatted)"
    }

    /// Format p-value as a 3-decimal string. ``nil`` → em-dash.
    /// Values below 0.001 collapse to ``"<0.001"`` so the chip text
    /// stays a fixed width. Mirrors the web ``formatPValue`` helper
    /// exactly.
    static func pvalueString(_ p: Double?) -> String {
        guard let value = p else {
            return "—"
        }
        if value < 0.001 {
            return "<0.001"
        }
        return String(format: "%.3f", value)
    }

    /// Cointegration predicate. Returns ``true`` ONLY when ``p`` is
    /// non-nil AND strictly less than
    /// ``cointegrationPThreshold`` (0.05). Mirrors the web behavior.
    static func isCointegrated(_ p: Double?) -> Bool {
        guard let value = p else {
            return false
        }
        return value < cointegrationPThreshold
    }

    /// Split a backend pair-key string of the shape
    /// ``"exchange:symbol"`` into its parts. Mirrors the web
    /// ``splitPairKey`` helper. Returns ``nil`` when the key
    /// contains no ``":"`` or when the ``":"`` is at index 0 (an
    /// empty exchange would render a malformed chip — drop those).
    static func splitPairKey(_ key: String) -> (exchange: String, symbol: String)? {
        guard let idx = key.firstIndex(of: ":") else {
            return nil
        }
        if idx == key.startIndex {
            return nil
        }
        let exchange = String(key[..<idx])
        let symbol = String(key[key.index(after: idx)...])
        return (exchange, symbol)
    }

    /// Derive chips for the currently-selected market.
    ///
    /// For each ``CachedStatsPayload`` row, identify the side that
    /// matches ``selfKey`` (``"<exchange>:<symbol>"``) and emit a
    /// chip pointing at the OTHER side. Pairs that match neither side
    /// are dropped (defensive — backend may include unrelated pairs
    /// in the configured-list response). Pairs whose OTHER key is
    /// malformed (no ``":"`` or empty exchange) are also dropped.
    ///
    /// Sort order matches the frontend ``comparePairChips``:
    /// 1. p-value ASCENDING (lower is "more cointegrated"). ``nil``
    ///    p-values sort LAST via ``+Infinity``.
    /// 2. Tie-break by ``|pearsonR|`` DESCENDING — stronger
    ///    correlation wins when p-values are equal.
    static func buildChips(
        pairs: [CachedStatsPayload],
        selfKey: String
    ) -> [PairStatsChipModel] {
        var chips: [PairStatsChipModel] = []
        for stats in pairs {
            let otherKey: String?
            if stats.left == selfKey {
                otherKey = stats.right
            } else if stats.right == selfKey {
                otherKey = stats.left
            } else {
                otherKey = nil
            }
            guard let key = otherKey, let parsed = splitPairKey(key) else {
                continue
            }
            chips.append(
                PairStatsChipModel(
                    otherExchange: parsed.exchange,
                    otherSymbol: parsed.symbol,
                    pearsonR: stats.pearsonR,
                    cointPvalue: stats.cointPvalue,
                    isWarm: stats.isWarm
                )
            )
        }
        chips.sort { (a, b) in
            let aP = a.cointPvalue ?? .infinity
            let bP = b.cointPvalue ?? .infinity
            if aP != bP {
                return aP < bP
            }
            let aR = abs(a.pearsonR ?? 0)
            let bR = abs(b.pearsonR ?? 0)
            return aR > bR
        }
        return chips
    }

    /// Three styles a pair-stats chip can render in. The view maps
    /// these to actual ``Color`` tokens; keeping the enum data-side
    /// keeps the choice testable.
    enum ChipStyle: Equatable {
        case cointegrated
        case warmNonCointegrated
        case cold
    }

    /// Pick the chip style for ``chip``. Cointegrated trumps
    /// warm/cold; an un-warm cache surfaces as ``.cold`` regardless
    /// of statistical signal.
    static func resolveChipStyle(chip: PairStatsChipModel) -> ChipStyle {
        if !chip.isWarm {
            return .cold
        }
        if isCointegrated(chip.cointPvalue) {
            return .cointegrated
        }
        return .warmNonCointegrated
    }
}

/// Pure logic helpers backing ``CacheWarmingBannerView``. Tested at
/// the helper layer.
///
/// Lives in the Models layer because ``MarketDataViewModel`` writes
/// the ``CacheStateSnapshot`` it consumes; co-locating the helper
/// keeps the layering clean (View layer depends DOWN on Models, not
/// the other way around).
enum CacheWarmingBannerLogic {

    /// Render-gate predicate. The banner is visible ONLY when there
    /// IS a cache state AND it is NOT yet warm. A nil state means
    /// "no cached-candles fetch yet" (initial / pre-selection), and
    /// a warm state means "the cache holds full history" — both
    /// should hide the banner.
    static func shouldRender(cacheState: CacheStateSnapshot?) -> Bool {
        guard let state = cacheState else {
            return false
        }
        return !state.isWarm
    }

    /// Compose the localized warming message. Template is
    /// ``market.cacheBanner.message`` with three positional
    /// placeholders: ``%1$@`` = current sample count, ``%2$@`` =
    /// expected sample count, ``%3$@`` = the localized data-source
    /// suffix (e.g. ``"(derived from 1m)"`` for source ``"derived"``,
    /// empty string for source ``"cache"``).
    static func message(
        cacheState: CacheStateSnapshot,
        expected: Int,
        lang: CatalogLanguage
    ) -> String {
        let sampleLabel = String(cacheState.sampleCount)
        let expectedLabel = String(expected)
        let sourceSuffix = localizedSourceSuffix(source: cacheState.source, lang: lang)
        let template = LocaleStrings.localized("market.cacheBanner.message", in: lang)
        let rendered: String
        if template == "market.cacheBanner.message" {
            let trail = sourceSuffix.isEmpty ? "" : " \(sourceSuffix)"
            rendered = "Cache warming up: \(sampleLabel) / \(expectedLabel) candles available\(trail)"
        } else {
            rendered = String(
                format: template,
                locale: Locale(identifier: lang.rawValue),
                sampleLabel,
                expectedLabel,
                sourceSuffix
            )
        }
        /// Trim the trailing whitespace that the catalog template
        /// leaves dangling for ``source == "cache"`` (the suffix
        /// slot is the empty string in EN; the template ends with
        /// ``"… available %3$@"``). Trimming on the rendered side
        /// keeps the catalog template stable across all locales.
        return rendered.trimmingCharacters(in: .whitespaces)
    }

    /// Raw source token rendered in a monospaced caption below the
    /// localized message. Surfaces the wire value (``"cache"`` /
    /// ``"derived"`` / ``"db"``) so the operator-facing UI can debug
    /// data provenance without parsing the localized text.
    static func rawSourceCaption(cacheState: CacheStateSnapshot) -> String {
        return cacheState.source
    }

    /// Resolve the localized source-label suffix for the
    /// ``market.cacheBanner.message`` template's ``%3$@`` slot.
    /// EN catalog uses ``""`` for source ``"cache"`` (no trailing
    /// parenthetical), ``"(derived from 1m)"`` for ``"derived"``,
    /// and ``"(from DB)"`` for ``"db"``.
    static func localizedSourceSuffix(
        source: String,
        lang: CatalogLanguage
    ) -> String {
        let key = "market.cacheBanner.sources.\(source)"
        let resolved = LocaleStrings.localized(key, in: lang)
        if resolved == key {
            return ""
        }
        return resolved
    }
}

/// Per-task request limits for the two cache endpoints
/// ``MarketDataViewModel`` consumes, plus the matching banner
/// denominator. Replaces the prior single-value
/// ``MarketCacheTarget.expectedSampleCount`` which conflated the
/// banner probe (drives the warming UI) with the metrics-grid
/// hourly fetch (drives the 24h high/low/changePct cards) and
/// produced misleading banner copy when the chart timeframe
/// differed from the metrics timeframe.
///
/// Split semantics:
/// - ``bannerProbeLimit(for:)``: per-selected-timeframe request
///   limit for the ``chartCacheStateTask`` that drives
///   ``cacheState``. Banner reads the SAME value via this helper
///   so the rendered "X / Y" denominator always matches the
///   request that produced the X numerator. Values follow the
///   backend cache's 100-bar 1m deque cap minus worst-case
///   alignment loss (``bucket-1`` 1m bars at the start), so a
///   healthy 100-bar 1m cache always reaches the published target
///   regardless of where the minute boundary falls. For DB-backed
///   long frames (1h/4h/1d) the value is a stable returned-row
///   target for the selected DB-backed timeframe (25 rows).
/// - ``metricsHourlyLimit``: fixed hourly window for the
///   ``metricsCachedTask`` that powers the 24h metric grid. Kept
///   separate from the banner probe because the metric cards need
///   a fixed hourly aggregation regardless of which chart
///   timeframe the user is viewing.
enum MarketCacheLimits {

    /// Number of cached bars the chart-cache state probe requests
    /// for a given selected timeframe. The banner's denominator
    /// reuses this value via the same helper so the request limit
    /// and the rendered denominator can never drift apart.
    ///
    /// Worst-case derivations from the backend's 100-bar 1m cache
    /// deque:
    /// - 1m → 100 (native deque capacity)
    /// - 5m → 19 (``floor((100 - 4) / 5)`` — even if the first 4
    ///   1m bars sit on a non-5m boundary you still get 19 full
    ///   5m bars)
    /// - 15m → 5 (``floor((100 - 14) / 15)``)
    /// - 1h / 4h / 1d → 25 (DB-backed; the cache cannot serve
    ///   long frames so this is the stable returned-row target
    ///   for the selected DB-backed timeframe rather than a
    ///   cache-derived count)
    static func bannerProbeLimit(for tf: MarketTimeframe) -> Int {
        switch tf {
        case .oneMinute:      return 100
        case .fiveMinutes:    return 19
        case .fifteenMinutes: return 5
        case .oneHour:        return 25
        case .fourHours:      return 25
        case .oneDay:         return 25
        }
    }

    /// Fixed 25-bar hourly window for the 24h metrics grid
    /// (high/low/changePct cards). Decoupled from
    /// ``bannerProbeLimit(for:)`` because metrics needs a stable
    /// hourly aggregation regardless of the chart's currently-
    /// selected timeframe.
    static let metricsHourlyLimit: Int = 25
}
