import SwiftUI

/// Single alert row for the Alerts tab.
///
/// Renders the four user-visible fields —
/// `alert_type` as a badge (colour-coded by priority),
/// `title`, `body`, and the relative-time `timestamp`.
///
/// Safety-critical alerts get a subtle red accent border so users
/// can scan the list for urgent items without reading every row.
/// The row is purely presentational — selection / deep-linking is
/// handled by the parent `AlertsView` via `onTapGesture`.
struct AlertRow: View {
    let alert: AlertEventInfo
    /// The user-selected app locale, used to render the relative
    /// timestamp in the catalog language rather than the host
    /// process's preferred-language list (defaults to ``.us`` for
    /// English so plain previews and legacy callers continue to
    /// render English without explicit injection).
    var locale: AppLocale = .us

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            priorityBadge
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(verbatim: displayBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(relativeTimestamp)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .leading) {
            if alert.isSafetyCritical {
                Rectangle()
                    .fill(.red)
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayTitle). \(displayBody). \(alert.priority) priority.")
    }

    private var displayTitle: String {
        alert.displayTitle(in: locale.catalogLanguage)
    }

    private var displayBody: String {
        alert.displayBody(in: locale.catalogLanguage)
    }

    private var priorityBadge: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 10, height: 10)
            .padding(.top, 6)
    }

    private var priorityColor: Color {
        switch alert.priority {
        case "high": return .red
        case "medium": return .orange
        case "low": return .blue
        default: return .gray
        }
    }

    private var relativeTimestamp: String {
        return Self.relativeTimestamp(
            for: alert.timestamp,
            locale: locale,
            relativeTo: Date()
        )
    }

    /// Locale-scoped relative-time render. Extracted as a static so
    /// it can be unit-tested independently of the SwiftUI body and
    /// so callers (Home's ``LatestAlertCard``) can share the same
    /// behavior. Setting ``locale`` is what makes the formatter pick
    /// the user-selected catalog language (e.g. Irish ``ga-IE``)
    /// rather than the host process's preferred-language list.
    static func relativeTimestamp(
        for date: Date,
        locale: AppLocale,
        relativeTo reference: Date
    ) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale.nativeLocale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: reference)
    }
}
