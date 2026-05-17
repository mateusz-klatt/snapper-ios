import Foundation

/// In-app re-localization helpers for ``AlertEventInfo``.
///
/// The REST alert routes resolve ``title`` / ``body`` server-side from
/// the caller's ``user.default_language`` and ALSO surface the
/// ``title_loc_key`` / ``body_loc_key`` + ``loc_args`` arrays so iOS
/// can re-render the row when the in-app locale picker changes
/// without a server round-trip.
///
/// **Resolution chain:**
///
/// 1. If ``titleLocKey`` / ``bodyLocKey`` is present AND the catalog
///    has the key for ``language``: render via ``LocaleStrings.render``.
/// 2. Otherwise (legacy row before Phase D, or catalog drift):
///    return the server-rendered ``title`` / ``body`` verbatim — those
///    are the EN strings the backend resolved for this user, so the
///    push is never "stuck" in the wrong locale.
///
/// **Why two helpers, not a single function:** iOS calls ``Text(_:)``
/// per field; keeping the API field-shaped means callers don't need
/// to destructure a tuple every time. Both helpers share the same
/// fallback funnel via a private ``renderOrFallback`` so a future
/// change to "treat catalog-miss as <something else>" only edits one
/// site.
extension AlertEventInfo {

    /// Localized title for display. Returns the server-rendered EN
    /// ``title`` column when there is no ``titleLocKey`` (legacy row
    /// before Phase D) or when the catalog lookup misses.
    func displayTitle(in language: CatalogLanguage) -> String {
        renderOrFallback(
            key: titleLocKey,
            args: titleLocArgs,
            fallback: title,
            language: language
        )
    }

    /// Localized body for display. Same fallback chain as
    /// ``displayTitle``.
    func displayBody(in language: CatalogLanguage) -> String {
        renderOrFallback(
            key: bodyLocKey,
            args: bodyLocArgs,
            fallback: body,
            language: language
        )
    }

    private func renderOrFallback(
        key: String?,
        args: [String]?,
        fallback: String,
        language: CatalogLanguage
    ) -> String {
        guard let key, !key.isEmpty else { return fallback }
        let rendered = LocaleStrings.render(key, in: language, args: args ?? [])
        return rendered == key ? fallback : rendered
    }
}
