import SwiftUI

/// View-model snapshot of the cache-warming endpoint payload.
/// Populated by ``MarketDataViewModel`` from the
/// ``CachedCandlesPayload`` sibling fields each time the metrics
/// candles refresh.
struct CacheStateSnapshot: Equatable {
    let isWarm: Bool
    let sampleCount: Int
    let source: String
}

/// Pure logic helpers backing ``CacheWarmingBannerView``. Tested at
/// the helper layer per ``ios/docs/architecture-mvvm.md``.
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
    ///
    /// Number formatting uses positional ``%@`` slots (not ``%d``)
    /// because the catalog also localizes the counts via
    /// ``NumberFormatter`` would be — for now they pass through as
    /// string-formatted integers (matches the web frontend's
    /// behavior of stringifying via i18next interpolation).
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

/// Cache-warming notice rendered above the chart inside the chart
/// card surface. Two stacked text rows: localized warming message
/// (with sample count + source) and a small monospaced raw source
/// caption for operator-facing debugging.
struct CacheWarmingBannerView: View {
    let cacheState: CacheStateSnapshot?
    let expected: Int
    let language: CatalogLanguage

    var body: some View {
        if let state = cacheState, CacheWarmingBannerLogic.shouldRender(cacheState: state) {
            populated(state: state)
        } else {
            EmptyView()
        }
    }

    private func populated(state: CacheStateSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: CacheWarmingBannerLogic.message(
                cacheState: state,
                expected: expected,
                lang: language
            ))
            .font(.footnote)
            Text(verbatim: CacheWarmingBannerLogic.rawSourceCaption(cacheState: state))
                .font(.system(.caption2, design: .monospaced))
                .opacity(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSurface.opacity(0.5))
    }
}
