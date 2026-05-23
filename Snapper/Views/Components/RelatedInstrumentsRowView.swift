import SwiftUI

/// Pure logic helpers powering ``RelatedInstrumentsRowView``.
///
/// Cluster header composition + chip-suffix formatting + empty-state
/// rendering all live here so the SwiftUI body stays thin and excluded
/// from coverage. See ``docs/architecture-mvvm.md`` for the
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
    ///    (``"%1$@:"`` in EN). The wrap exists so the separator
    ///    glyph itself (``":"`` in EN, possibly ``"："`` in
    ///    fullwidth-CJK locales) is owned by the catalog rather
    ///    than hard-coded in source.
    static func clusterHeader(
        group: RelatedInstrumentsGroup,
        lang: CatalogLanguage
    ) -> String {
        let typeKey = "market.related.relationshipType.\(group.relationshipType)"
        let resolvedType = LocaleStrings.localized(typeKey, in: lang)
        /// A catalog miss returns the key verbatim; a degenerate
        /// empty translation returns ``""``. Both fall through to
        /// the backend-provided ``group.label`` so the header is
        /// never blank or just a separator character.
        let typeLabel: String
        if resolvedType == typeKey || resolvedType.isEmpty {
            typeLabel = group.label
        } else {
            typeLabel = resolvedType
        }
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
    /// ``market.related.empty``. The view guards against a nil
    /// selection before calling this helper, so both inputs are
    /// non-optional here.
    static func emptyStateMessage(
        symbol: String,
        exchange: String,
        lang: CatalogLanguage
    ) -> String {
        let template = LocaleStrings.localized("market.related.empty", in: lang)
        if template == "market.related.empty" {
            return "No related instruments configured for \(symbol) on \(exchange)."
        }
        return String(
            format: template,
            locale: Locale(identifier: lang.rawValue),
            symbol,
            exchange
        )
    }
}

/// Horizontal row of grouped derivative / proxy / same-underlying
/// chips that lets the user cross-navigate to a related market via a
/// single tap. Mirrors the web frontend's ``RelatedInstrumentsRow``.
///
/// State semantics:
/// - ``relatedResponse == nil`` — payload not yet loaded (initial /
///   loading / fetch-failed / pre-selection). Row renders nothing
///   so the surface stays out of the way and the empty-state copy
///   does NOT flash through during normal transitions.
/// - ``relatedResponse != nil`` and ``groups.isEmpty`` — backend
///   confirmed no related instruments for the current selection.
///   Row renders the empty-state message.
/// - ``relatedResponse != nil`` and ``groups`` populated — row
///   renders the horizontal chip clusters.
struct RelatedInstrumentsRowView: View {
    let relatedResponse: RelatedInstrumentsResponse?
    let selectedExchange: String?
    let selectedSymbol: String?
    let language: CatalogLanguage
    let onSelect: (_ exchange: String, _ nativeSymbol: String) -> Void

    var body: some View {
        if let payload = relatedResponse?.payload {
            if payload.groups.isEmpty {
                if let symbol = selectedSymbol, let exchange = selectedExchange {
                    emptyState(symbol: symbol, exchange: exchange)
                } else {
                    EmptyView()
                }
            } else {
                populated(payload.groups)
            }
        } else {
            EmptyView()
        }
    }

    private func populated(_ groups: [RelatedInstrumentsGroup]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
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

    private func emptyState(symbol: String, exchange: String) -> some View {
        let message = RelatedInstrumentsRowLogic.emptyStateMessage(
            symbol: symbol,
            exchange: exchange,
            lang: language
        )
        return Text(verbatim: message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
    }
}
