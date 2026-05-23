import SwiftUI

/// View-model shape for one chip rendered by ``PairStatsRowView``.
/// Built from the backend's ``CachedStatsPayload`` via
/// ``PairStatsRowLogic.buildChips`` — the chip carries only what the
/// row needs to render + navigate so the View body does not have to
/// re-derive peer information per render pass.
struct PairStatsChipModel: Equatable {
    let otherExchange: String
    let otherSymbol: String
    let pearsonR: Double?
    let cointPvalue: Double?
    let isWarm: Bool
}

/// Pure logic helpers backing ``PairStatsRowView``.
///
/// Mirrors the frontend's cointegration metric formatting + chip
/// sort + style threshold so iOS chips read the same as web. All
/// methods are pure (no I/O, no actor isolation) so the View body
/// can stay thin and excluded from coverage per
/// ``ios/docs/architecture-mvvm.md``.
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

/// Horizontal row of cointegration chips for every configured pair
/// involving the currently-selected market. Cointegrated chips wear
/// a ``brandGreen`` border + checkmark; warm-non-cointegrated and
/// cold chips wear neutral borders.
struct PairStatsRowView: View {
    let chips: [PairStatsChipModel]
    let language: CatalogLanguage
    let onSelect: (_ exchange: String, _ symbol: String) -> Void

    var body: some View {
        if chips.isEmpty {
            EmptyView()
        } else {
            populated
        }
    }

    private var populated: some View {
        let label = LocaleStrings.localized("market.pairStats.label", in: language)
        return VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        chipView(chip)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private func chipView(_ chip: PairStatsChipModel) -> some View {
        let style = PairStatsRowLogic.resolveChipStyle(chip: chip)
        let pearsonStr = PairStatsRowLogic.signedPearsonString(chip.pearsonR)
        let pvalueStr = PairStatsRowLogic.pvalueString(chip.cointPvalue)
        let metricTemplate = LocaleStrings.localized("market.pairStats.metric", in: language)
        let metricText: String
        if metricTemplate == "market.pairStats.metric" {
            metricText = "ρ \(pearsonStr) · p \(pvalueStr)"
        } else {
            metricText = String(
                format: metricTemplate,
                locale: Locale(identifier: language.rawValue),
                pearsonStr,
                pvalueStr
            )
        }
        let ariaTemplate = LocaleStrings.localized("market.pairStats.chipAriaLabel", in: language)
        let ariaText: String
        if ariaTemplate == "market.pairStats.chipAriaLabel" {
            ariaText = "Pair stats with \(chip.otherSymbol) on \(chip.otherExchange): Pearson \(pearsonStr), p-value \(pvalueStr)"
        } else {
            ariaText = String(
                format: ariaTemplate,
                locale: Locale(identifier: language.rawValue),
                chip.otherSymbol,
                chip.otherExchange,
                pearsonStr,
                pvalueStr
            )
        }
        let borderColor: Color
        let chipOpacity: Double
        switch style {
        case .cointegrated:
            borderColor = .brandGreen
            chipOpacity = 1.0
        case .warmNonCointegrated:
            borderColor = .strokeSeparator
            chipOpacity = 1.0
        case .cold:
            borderColor = .strokeSeparator
            chipOpacity = 0.6
        }
        return Button(action: { onSelect(chip.otherExchange, chip.otherSymbol) }) {
            HStack(spacing: 4) {
                Text(verbatim: chip.otherSymbol)
                    .font(.caption.weight(.medium))
                Text(verbatim: metricText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if style == .cointegrated {
                    Text(verbatim: "✓")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.brandGreen)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.bgSurface))
            .overlay(Capsule().stroke(borderColor, lineWidth: 1))
            .opacity(chipOpacity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: ariaText))
    }
}
