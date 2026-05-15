import Foundation

/// Per-locale number / date / currency / percent formatter factory.
///
/// Reads ``AppLocale.nativeLocale`` (BCP-47 ``<lang>-<COUNTRY>`` form
/// via ``CountryMappings.intlLocaleIdentifier``) to bind each formatter
/// to the user's selected catalog language. New formatters are cheap to
/// create; callers should not cache instances across locale changes
/// (each ``setLocale`` invalidates the prior formatter so a fresh
/// factory call picks up the new locale).
enum LocaleFormatters {

    /// Decimal-number formatter (no currency / percent symbol).
    /// Honors the locale's decimal separator (``,`` for PL, ``.`` for EN)
    /// and grouping (non-breaking space for PL, comma for EN).
    static func decimal(for locale: AppLocale, fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale.nativeLocale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter
    }

    /// Currency formatter bound to ``code`` (ISO 4217). The currency
    /// symbol placement follows the locale (suffix in PL, prefix in EN).
    static func currency(for locale: AppLocale, code: String, fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale.nativeLocale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter
    }

    /// Percent formatter. Input expected as a fraction (``0.05`` ->
    /// ``5%`` in EN, ``5 %`` in PL); locale controls the ``%``-symbol
    /// spacing per CLDR rules.
    static func percent(for locale: AppLocale, fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale.nativeLocale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter
    }

    /// Relative-date formatter ("5 minutes ago" / "5 minut temu").
    static func relativeDateTime(for locale: AppLocale) -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale.nativeLocale
        formatter.unitsStyle = .full
        return formatter
    }

    /// Compact-duration formatter ("5m 30s" / "5min 30 s").
    static func compactDuration(for locale: AppLocale) -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.calendar?.locale = locale.nativeLocale
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.minute, .second]
        return formatter
    }
}

/// Ergonomic helpers that render a ``Double`` through ``LocaleFormatters``.
///
/// Phase D rolls these out across views that previously called
/// ``String(format: "%.4f", value)`` and friends. The bare format
/// specifier always emits ``.`` as the decimal separator, which is
/// wrong for the Polish locale (CLDR mandates ``,``). Callsites that
/// route through these helpers honor the user's ``AppState.locale``.
///
/// Each helper returns a non-optional string with a ``"0"``-fraction
/// fallback when ``NumberFormatter`` declines to format (a near-zero
/// edge case observed only on programmatic locale corruption). The
/// fallback keeps SwiftUI ``Text`` rows non-empty so the layout does
/// not collapse if a formatter ever returns ``nil``.
extension Double {

    /// Locale-aware decimal rendering for plain numbers (quantities,
    /// non-currency prices). Mirrors the existing ``%.Nf`` callsites
    /// but emits ``,`` decimal separators for PL.
    func formattedDecimal(in locale: AppLocale, fractionDigits: Int) -> String {
        let formatter = LocaleFormatters.decimal(for: locale, fractionDigits: fractionDigits)
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }

    /// Locale-aware currency rendering. ``code`` is an ISO 4217 code
    /// (``"USD"`` in the current app). Symbol placement follows CLDR:
    /// prefix in EN (``$4.21``), suffix in PL (``4,21 USD``).
    func formattedCurrency(in locale: AppLocale, code: String, fractionDigits: Int) -> String {
        let formatter = LocaleFormatters.currency(for: locale, code: code, fractionDigits: fractionDigits)
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }

    /// Locale-aware integer-percent rendering for slider ratios like
    /// ``"25%"`` / ``"25 %"`` (PL inserts a NBSP per CLDR). The input
    /// is the underlying ratio (``0.25`` for ``25%``); the formatter
    /// applies the ``×100`` scaling.
    func formattedPercent(in locale: AppLocale, fractionDigits: Int) -> String {
        let formatter = LocaleFormatters.percent(for: locale, fractionDigits: fractionDigits)
        return formatter.string(from: NSNumber(value: self)) ?? "0%"
    }
}
