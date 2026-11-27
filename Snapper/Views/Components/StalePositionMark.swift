import SwiftUI

struct StalePositionMark: View {
    let position: PositionSnapshot

    @Environment(AppState.self) private var appState
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(LocalizedStringKey("positions.column.markPrice"))
                .foregroundStyle(.secondary)
            Text(verbatim: Self.priceLabel(for: position, locale: appState.locale))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey("positions.mark.stale"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15), in: Capsule())
                .accessibilityLabel(Text(verbatim: Self.accessibilityLabel(
                    asOf: position.markAsOf,
                    locale: appState.locale,
                    timeZone: timeZone
                )))
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }

    static func priceLabel(for position: PositionSnapshot, locale: AppLocale) -> String {
        guard let price = position.markPrice else { return "—" }
        let fractionDigits = position.priceDecimals.map { $0...$0 } ?? (2...8)
        return price.formatted(
            .number.precision(.fractionLength(fractionDigits)).locale(locale.westernDigitsLocale)
        )
    }

    static func accessibilityLabel(asOf: Date?, locale: AppLocale, timeZone: TimeZone) -> String {
        let language = locale.catalogLanguage
        guard let asOf else {
            return LocaleStrings.localized("positions.mark.stale", in: language)
        }
        let timestamp = LocaleFormatters.timestamp(for: locale, timeZone: timeZone).string(from: asOf)
        return String(format: LocaleStrings.localized("positions.mark.staleAsOf", in: language), timestamp)
    }
}
