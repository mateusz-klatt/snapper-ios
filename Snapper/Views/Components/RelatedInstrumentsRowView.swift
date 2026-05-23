import SwiftUI

/// Pure logic helpers powering ``RelatedInstrumentsRowView``.
///
/// Cluster header composition + chip-suffix formatting + empty-state
/// rendering all live here so the SwiftUI body stays thin and excluded
/// from coverage. See ``ios/docs/architecture-mvvm.md`` for the
/// architecture rule.
enum RelatedInstrumentsRowLogic {

    /// Resolve a cluster header text for one grouped relationship type.
    ///
    /// Two-step composition:
    /// 1. Resolve the relationship-type label via
    ///    ``market.related.relationshipType.<type>``. Falls back to the
    ///    backend-provided ``group.label`` when the catalog lookup
    ///    misses (e.g. backend introduces a new relationship type
    ///    before the iOS catalog catches up).
    /// 2. Wrap the resolved label in the
    ///    ``market.related.labelSeparator`` template
    ///    (``"%1$@:"`` in EN). Without this wrap, the labelSeparator
    ///    catalog key sits unused — Copilot v4 flagged that in
    ///    plan review.
    static func clusterHeader(
        group: RelatedInstrumentsGroup,
        lang: CatalogLanguage
    ) -> String {
        let typeKey = "market.related.relationshipType.\(group.relationshipType)"
        let resolvedType = LocaleStrings.localized(typeKey, in: lang)
        let typeLabel = resolvedType == typeKey ? group.label : resolvedType
        let template = LocaleStrings.localized("market.related.labelSeparator", in: lang)
        if template == "market.related.labelSeparator" {
            return "\(typeLabel):"
        }
        return String(format: template, locale: Locale(identifier: lang.rawValue), typeLabel)
    }

    /// Build the chip's exchange-suffix line, e.g. ``"· polygon"``.
    /// The middle-dot separator + format come from the catalog
    /// (``market.related.exchangeSeparator``) so other locales can
    /// substitute a culturally appropriate separator.
    static func chipExchangeSuffix(
        exchange: String,
        lang: CatalogLanguage
    ) -> String {
        let template = LocaleStrings.localized("market.related.exchangeSeparator", in: lang)
        if template == "market.related.exchangeSeparator" {
            return "· \(exchange)"
        }
        return String(format: template, locale: Locale(identifier: lang.rawValue), exchange)
    }

    /// Empty-state message shown when the backend returns no related
    /// instruments for the current selection. Substitutes the current
    /// symbol + exchange via the catalog template
    /// ``market.related.empty``. ``nil`` inputs fall through as the
    /// empty string — the template has to tolerate that gracefully
    /// (it does in EN/PL/the audited locales).
    static func emptyStateMessage(
        symbol: String?,
        exchange: String?,
        lang: CatalogLanguage
    ) -> String {
        let template = LocaleStrings.localized("market.related.empty", in: lang)
        if template == "market.related.empty" {
            return "No related instruments configured for \(symbol ?? "") on \(exchange ?? "")."
        }
        return String(
            format: template,
            locale: Locale(identifier: lang.rawValue),
            symbol ?? "",
            exchange ?? ""
        )
    }
}

/// Horizontal row of grouped derivative / proxy / same-underlying
/// chips that lets the user cross-navigate to a related market via a
/// single tap. Mirrors the web frontend's ``RelatedInstrumentsRow``.
struct RelatedInstrumentsRowView: View {
    let groups: [RelatedInstrumentsGroup]
    let selectedExchange: String?
    let selectedSymbol: String?
    let language: CatalogLanguage
    let onSelect: (_ exchange: String, _ nativeSymbol: String) -> Void

    var body: some View {
        if groups.isEmpty {
            empty
        } else {
            populated
        }
    }

    private var populated: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(groups, id: \.relationshipType) { group in
                    cluster(group)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func cluster(_ group: RelatedInstrumentsGroup) -> some View {
        let header = RelatedInstrumentsRowLogic.clusterHeader(
            group: group,
            lang: language
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: header)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(group.items, id: \.instrumentPublicId) { item in
                    chip(item)
                }
            }
        }
    }

    private func chip(_ item: RelatedInstrumentData) -> some View {
        let suffix = RelatedInstrumentsRowLogic.chipExchangeSuffix(
            exchange: item.exchange,
            lang: language
        )
        let isSelected = item.exchange == selectedExchange
            && item.nativeSymbol == selectedSymbol
        return Button(action: { onSelect(item.exchange, item.nativeSymbol) }) {
            HStack(spacing: 4) {
                Text(verbatim: item.nativeSymbol)
                    .font(.caption.weight(.medium))
                Text(verbatim: suffix)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.bgSurface)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.brandGreen : Color.strokeSeparator,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSelected)
    }

    private var empty: some View {
        let message = RelatedInstrumentsRowLogic.emptyStateMessage(
            symbol: selectedSymbol,
            exchange: selectedExchange,
            lang: language
        )
        return Text(verbatim: message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
    }
}
