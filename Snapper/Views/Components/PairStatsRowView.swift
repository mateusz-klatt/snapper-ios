import SwiftUI

/// Horizontal row of cointegration chips for every configured pair
/// involving the currently-selected market. Cointegrated chips wear
/// a ``brandGreen`` border + checkmark; warm-non-cointegrated and
/// cold chips wear neutral borders.
///
/// The chip model + sort + style logic live in
/// ``Snapper/Models/MarketDataLogic.swift`` so the view-model can
/// expose ``filteredPairChips`` without depending on the View
/// layer.
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
