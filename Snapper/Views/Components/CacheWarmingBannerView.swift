import SwiftUI

/// Cache-warming notice rendered above the chart inside the chart
/// card surface. Two stacked text rows: localized warming message
/// (with sample count + source) and a small monospaced raw source
/// caption for operator-facing debugging.
///
/// The render-gate + message + suffix logic live in
/// ``Snapper/Models/MarketDataLogic.swift`` so the view-model can
/// own ``cacheState`` without depending on the View layer.
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
