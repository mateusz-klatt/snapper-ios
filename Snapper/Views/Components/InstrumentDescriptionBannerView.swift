import SwiftUI

/// Mirror of the web frontend's asset-class taxonomy. Catalog lookup
/// for the chip label uses ``rawValue`` as the key suffix
/// (``"market.assetClass.<rawValue>"``).
enum BannerAssetClass: String {
    case crypto
    case commodity
    case forex
    case index
    case yield
    case unknown
}

/// Pure logic helpers powering ``InstrumentDescriptionBannerView``.
///
/// All view-rendering decisions that depend on data shape (asset-class
/// normalization, sector slug, chip label fallback chain, description
/// vs fallback template) live here so the SwiftUI body can stay thin
/// and excluded from coverage. See ``ios/docs/architecture-mvvm.md``
/// for the architecture rule.
enum InstrumentDescriptionBannerLogic {

    /// Map the backend's free-form ``asset_class`` string onto the
    /// fixed iOS taxonomy. Unknown / misspelled / future values fall
    /// to ``.unknown`` so the chip still renders.
    static func normalizeAssetClass(_ raw: String) -> BannerAssetClass {
        let lower = raw.lowercased()
        if let exact = BannerAssetClass(rawValue: lower) {
            return exact
        }
        return .unknown
    }

    /// Convert a sector display label (e.g. ``"Industrial Metals"``)
    /// into the catalog-key suffix (``"industrial-metals"``).
    /// Lowercase + replace spaces with hyphens. Other punctuation is
    /// left as-is by design — the backend's sector vocabulary is
    /// curated server-side; if a new sector ships with characters
    /// that need additional normalization, extend this helper and the
    /// catalog keys together.
    static func slugifySector(_ sector: String) -> String {
        return sector
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    /// Resolve the chip text. Three-step fallback chain so the chip
    /// is never empty and degrades gracefully when the catalog or
    /// the backend sector list drifts:
    /// 1. Localized sector label via ``market.sector.<slug>``.
    /// 2. Raw sector string (the backend's display label, untranslated).
    /// 3. Localized asset-class label via ``market.assetClass.<rawValue>``.
    static func chipLabel(
        sector: String?,
        assetClass: BannerAssetClass,
        lang: CatalogLanguage
    ) -> String {
        if let sector, !sector.isEmpty {
            let slug = slugifySector(sector)
            let key = "market.sector.\(slug)"
            let resolved = LocaleStrings.localized(key, in: lang)
            if resolved != key {
                return resolved
            }
            return sector
        }
        let assetKey = "market.assetClass.\(assetClass.rawValue)"
        let assetResolved = LocaleStrings.localized(assetKey, in: lang)
        if assetResolved != assetKey {
            return assetResolved
        }
        return assetClass.rawValue
    }

    /// Resolve the description body. Returns the backend-provided
    /// description verbatim when present, otherwise composes a
    /// fallback line from the underlying's name + asset-class label
    /// via the catalog template ``market.description.fallback``
    /// (``"%1$@ · %2$@"`` in EN).
    static func resolvedDescription(
        underlying: RelatedInstrumentsUnderlying,
        lang: CatalogLanguage
    ) -> String {
        if let description = underlying.description, !description.isEmpty {
            return description
        }
        let assetClass = normalizeAssetClass(underlying.assetClass)
        let assetKey = "market.assetClass.\(assetClass.rawValue)"
        let assetResolved = LocaleStrings.localized(assetKey, in: lang)
        let assetLabel = assetResolved == assetKey ? assetClass.rawValue : assetResolved
        let template = LocaleStrings.localized("market.description.fallback", in: lang)
        if template == "market.description.fallback" {
            return "\(underlying.name) · \(assetLabel)"
        }
        return String(
            format: template,
            locale: Locale(identifier: lang.rawValue),
            underlying.name,
            assetLabel
        )
    }
}

/// Mirror of the web frontend's ``InstrumentDescriptionBanner``:
/// sector chip + ticker + name + per-locale description. The
/// description text is resolved server-side from
/// ``User.default_language``; this view is a thin renderer.
///
/// Layout shows a loading skeleton when ``isLoading`` is true and no
/// ``underlying`` is available yet so the surface does not flash
/// between empty and populated states on first navigation.
struct InstrumentDescriptionBannerView: View {
    let underlying: RelatedInstrumentsUnderlying?
    let isLoading: Bool
    let language: CatalogLanguage

    var body: some View {
        if let underlying {
            populated(underlying: underlying)
        } else if isLoading {
            skeleton
        } else {
            EmptyView()
        }
    }

    private func populated(underlying: RelatedInstrumentsUnderlying) -> some View {
        let assetClass = InstrumentDescriptionBannerLogic.normalizeAssetClass(
            underlying.assetClass
        )
        let chip = InstrumentDescriptionBannerLogic.chipLabel(
            sector: underlying.sector,
            assetClass: assetClass,
            lang: language
        )
        let description = InstrumentDescriptionBannerLogic.resolvedDescription(
            underlying: underlying,
            lang: language
        )
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(verbatim: chip)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().stroke(Color.strokeSeparator, lineWidth: 1)
                    )
                Text(verbatim: underlying.ticker)
                    .font(.headline)
                Text(verbatim: underlying.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            Text(verbatim: description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.strokeSeparator, lineWidth: 1)
        )
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.strokeSeparator.opacity(0.4))
                .frame(width: 120, height: 18)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.strokeSeparator.opacity(0.3))
                .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.strokeSeparator, lineWidth: 1)
        )
    }
}
