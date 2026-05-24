import Foundation

/// User-selected country code identity that drives both the
/// SwiftUI environment locale (for ``Text``+``LocalizedStringKey``
/// resolution and date formatting) and the catalog language
/// fallback. Mirrors the 45 codes shipped by web v3 at
/// ``frontend/src/i18n/types.ts``.
///
/// Row layout (3×15) matches the LanguageSwitcher grid on
/// ``www.klatt.ie``. Iceland and India use descriptive case names
/// because their ISO country codes are Swift reserved keywords.
///
/// ``rawValue`` is the lowercase ISO-3166-1 alpha-2 country
/// code. ``Identifiable`` conformance via ``id == rawValue`` is
/// required by SwiftUI's ``ForEach(_:content:)`` initializer.
enum AppLocale: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case ie, us, pl, de, fr, es, it, nl, br, se, no, dk, fi, iceland = "is", gr
    case cn, hk, jp, kr, th, vn, ph, my, id, mm, india = "in", bd, ke, ae, il
    case cz, sk, hu, ro, ua, ru, lt, lv, hr, rs, ba, al, tr, ir, am

    var id: String { rawValue }

    /// Row 1: Western Europe + Americas (15 codes).
    static let row1: [AppLocale] = [.ie, .us, .pl, .de, .fr, .es, .it, .nl, .br, .se, .no, .dk, .fi, .iceland, .gr]

    /// Row 2: Asia + Middle East (15 codes).
    static let row2: [AppLocale] = [.cn, .hk, .jp, .kr, .th, .vn, .ph, .my, .id, .mm, .india, .bd, .ke, .ae, .il]

    /// Row 3: CEE + Balkans + Caucasus (15 codes).
    static let row3: [AppLocale] = [.cz, .sk, .hu, .ro, .ua, .ru, .lt, .lv, .hr, .rs, .ba, .al, .tr, .ir, .am]

    /// Locale picked when neither stored UserDefaults nor the
    /// device's preferred languages resolve to a supported code.
    /// Aligned with web v3's ``DEFAULT_LOCALE``.
    static let defaultLocale: AppLocale = .ie

    /// Two regional-indicator codepoints composed from the
    /// uppercase ISO code. Renders as the country's flag emoji on
    /// iOS 26.2 across all 45 codes.
    var flagEmoji: String {
        let base: UInt32 = 0x1F1E6
        return rawValue.uppercased().unicodeScalars
            .compactMap { Unicode.Scalar(base + ($0.value - 65)) }
            .map(String.init)
            .joined()
    }

    /// Right-to-left script flag. Set is locked to ``ae``, ``il``,
    /// ``ir`` per web v3.
    var isRTL: Bool {
        switch self {
        case .ae, .il, .ir: return true
        default: return false
        }
    }

    /// Catalog language to fall back to when this country code does
    /// not have a dedicated translation. Delegates to
    /// ``CountryMappings/catalogLanguage(for:)``.
    var catalogLanguage: CatalogLanguage { CountryMappings.catalogLanguage(for: self) }

    /// BCP-47 locale identifier ``<catalogLanguage>-<COUNTRY>`` for
    /// SwiftUI's ``\.locale`` environment value and Foundation date
    /// formatters. Delegates to
    /// ``CountryMappings/intlLocaleIdentifier(for:)``.
    var intlLocaleIdentifier: String { CountryMappings.intlLocaleIdentifier(for: self) }

    /// Foundation ``Locale`` built from ``intlLocaleIdentifier``.
    /// Cached only inside the SwiftUI environment; callers that
    /// need a strong reference should keep ``intlLocaleIdentifier``
    /// instead.
    var nativeLocale: Locale { Locale(identifier: intlLocaleIdentifier) }

    /// Foundation ``Locale`` that pins numeric formatting to Western
    /// (Latin) digits while preserving the locale's grammar, decimal
    /// separator, grouping, and date/time text. Used by the trading
    /// surfaces (price tiles, chart axes, percent values, durations)
    /// so ``ae``/``ir`` show ``78,041.50`` instead of mixed Eastern-
    /// Arabic ``٥:٠٢`` on the chart vs Western ``78,041.50`` on the
    /// tile. The ``.latn`` numbering system override is a no-op
    /// for locales that already default to Latin digits.
    ///
    /// Built via ``Locale.Components`` rather than a string-spliced
    /// BCP-47 identifier — Foundation in iOS 26 rejects
    /// ``"ga-IE-u-nu-latn"`` from ``NumberFormatter`` (returns ``nil``
    /// from ``string(from:)``), but the structured-components API
    /// produces a Locale that all the formatters accept.
    ///
    /// Confined to numeric and date-component output via
    /// ``LocaleFormatters``; the SwiftUI environment ``\.locale``
    /// keeps ``nativeLocale`` so ``Text(LocalizedStringKey)``
    /// translation lookup is unaffected.
    var westernDigitsLocale: Locale {
        var components = Locale.Components(identifier: intlLocaleIdentifier)
        components.numberingSystem = Locale.NumberingSystem("latn")
        return Locale(components: components)
    }

    /// Country name rendered in the country's own catalog language —
    /// the autonym (``Polska`` for ``.pl``, ``Deutschland`` for
    /// ``.de``, ``中国`` for ``.cn``, ``الإمارات`` for ``.ae``,
    /// ``Éire`` for ``.ie``, ``United States`` for ``.us``). Used by
    /// the locale-picker grid cells so each row is unambiguously
    /// identified by both flag and name even when the user does not
    /// recognize the regional-indicator flag glyph.
    ///
    /// Resolved through ``Locale.localizedString(forRegionCode:)`` on
    /// the country's own ``nativeLocale`` so the rendered string
    /// follows the country's own writing system regardless of the
    /// app-level locale. Falls back to the uppercased ISO-3166 code
    /// when ICU has no entry for the region (should not happen with
    /// the locked 45-code set on iOS 26.2 but the fallback keeps the
    /// cell label non-empty if ICU data changes).
    var nativeCountryName: String {
        nativeLocale.localizedString(forRegionCode: rawValue.uppercased())
            ?? rawValue.uppercased()
    }
}
