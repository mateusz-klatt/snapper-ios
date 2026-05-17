import SwiftUI

/// Compact "latest alert" card on the Home tab.
///
/// Displays the single most recent ``AlertEventInfo`` — typically
/// fetched via ``APIClient.fetchAlertHistory(limit: 1)`` from
/// ``HomeView`` on appear and on wallet selection change. When the
/// alert is ``nil`` (no history yet, or fetch failed silently) the
/// card collapses to ``EmptyView`` so the Home layout shifts up
/// instead of leaving a placeholder.
///
/// Vocabulary mirrors ``AlertRow`` (title / body / timestamp) so the
/// summary on Home stays consistent with the full Alerts tab list.
struct LatestAlertCard: View {
    let alert: AlertEventInfo?
    /// The user-selected app locale, used to render the relative
    /// timestamp in the catalog language rather than the host
    /// process's preferred-language list. Defaults to ``.us``
    /// (English) so plain previews and legacy callers continue to
    /// render English without explicit injection.
    var locale: AppLocale = .us

    var body: some View {
        if let alert {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.tint)
                    Text(LocalizedStringKey("home.section.latestAlert"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Self.relativeTimestamp(for: alert.timestamp, locale: locale))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(verbatim: alert.displayTitle(in: locale.catalogLanguage))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(verbatim: alert.displayBody(in: locale.catalogLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .leading) {
                if alert.isSafetyCritical {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.red, lineWidth: 1)
                }
            }
        } else {
            EmptyView()
        }
    }

    /// Locale-scoped relative-time helper. Setting ``locale`` makes
    /// the formatter pick the user-selected catalog language
    /// (e.g. Irish ``ga-IE``) rather than the host process's
    /// preferred-language list — without it, an English-speaking
    /// host renders "1 wk ago" even when the user picked Irish.
    static func relativeTimestamp(
        for date: Date,
        locale: AppLocale,
        relativeTo reference: Date = Date()
    ) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale.nativeLocale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: reference)
    }
}
