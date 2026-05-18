import Foundation

/// Per-user financial-direction color convention preference.
///
/// Snapper defaults to the Western convention (green = gain / up,
/// red = loss / down). CN / HK / JP / KR markets traditionally
/// invert this — red = up (auspicious / Chinese New Year),
/// green = down. Each user gets a preference that defaults to
/// ``auto`` (locale-derived) on first run and can be overridden via
/// Settings.
///
/// The enum raw values match the web contract at
/// ``frontend/src/theme/financialColorPreference.ts`` so a future
/// server-side sync of the preference is a 1-line change.
enum FinancialColorPreference: String, CaseIterable, Codable, Sendable {
    case auto = "auto"
    case risingRed = "rising-red"
    case risingGreen = "rising-green"
}

/// Concrete resolved convention — ``auto`` is never a runtime value
/// downstream of ``resolveFinancialColorConvention(preference:locale:)``.
enum EffectiveFinancialColorConvention: String, Sendable {
    case risingRed = "rising-red"
    case risingGreen = "rising-green"
}

/// Locales that default to the inverted (red = up) convention.
///
/// The picker layout currently doesn't include ``tw`` (Taiwan) —
/// adding ``tw`` would break ``AppLocale``'s hardcoded 3×15 row
/// model and the existing parity tests. ``hk`` proxies Traditional
/// Chinese (``zh-Hant``) for now; a separate locale-picker redesign
/// PR can add ``tw`` later. TW users wanting the Asian palette can
/// manually pick ``risingRed`` in Settings.
let autoRisingRedLocales: Set<AppLocale> = [.cn, .hk, .jp, .kr]

/// Storage key under ``UserDefaults.standard`` — matches the web
/// localStorage key for cross-platform parity.
let financialColorPreferenceStorageKey = "snapper-financial-color-preference"

/// Map a stored preference + the current locale to the concrete
/// convention that the UI should render.
///
/// Pure function so the same call can drive the ``Theme`` color
/// helpers, the Settings subtitle ("Currently: …"), and any future
/// surface that needs a resolved convention.
///
/// - Parameter preference: Stored user preference (defaults to
///     ``auto``).
/// - Parameter locale: Active ``AppLocale`` from the picker.
/// - Returns: Either ``.risingRed`` or ``.risingGreen`` — never
///     ``auto``.
func resolveFinancialColorConvention(
    preference: FinancialColorPreference,
    locale: AppLocale
) -> EffectiveFinancialColorConvention {
    switch preference {
    case .risingRed:
        return .risingRed
    case .risingGreen:
        return .risingGreen
    case .auto:
        return autoRisingRedLocales.contains(locale) ? .risingRed : .risingGreen
    }
}
