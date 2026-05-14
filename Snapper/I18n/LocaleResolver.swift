import Foundation

/// Pure detection logic for the user's initial locale, extracted
/// from ``AppState`` so the lookup is unit-testable without
/// constructing app state or touching UserDefaults.
///
/// Precedence:
/// 1. Stored value under ``localeKey`` in the passed
///    ``UserDefaults`` (matches the web v3 ``snapper-locale``
///    localStorage key).
/// 2. First valid 2-letter region segment found by walking the
///    ``preferredLanguages`` array in order. For each tag, the
///    parts are walked in reverse so 3-segment tags like
///    ``"zh-Hans-CN"`` resolve to ``cn`` rather than failing on
///    ``"Hans"``.
/// 3. ``AppLocale/defaultLocale`` (``.ie``).
enum LocaleResolver {

    /// Resolve from both UserDefaults precedence + system preferred
    /// languages. Used by ``AppState.init`` at app startup.
    static func resolveInitialLocale(
        userDefaults: UserDefaults,
        preferredLanguages: [String],
        localeKey: String
    ) -> AppLocale {
        if let stored = userDefaults.string(forKey: localeKey),
           let app = AppLocale(rawValue: stored) {
            return app
        }
        return Self.resolveFromPreferredLanguages(preferredLanguages)
    }

    /// Pure function. Tests pass literal arrays without UserDefaults.
    ///
    /// Parses BCP-47-style tags (``"pl-PL"``, ``"en_US"``,
    /// ``"zh-Hans-CN"``). The region is always the last 2-letter
    /// segment when split on ``-`` or ``_``, so the inner loop
    /// walks parts in reverse and picks the first 2-letter segment
    /// that maps to an ``AppLocale`` raw value. Falls back to
    /// ``AppLocale/defaultLocale`` when no tag resolves.
    static func resolveFromPreferredLanguages(_ preferredLanguages: [String]) -> AppLocale {
        for tag in preferredLanguages {
            let parts = tag.split(whereSeparator: { $0 == "-" || $0 == "_" })
            for part in parts.reversed() where part.count == 2 {
                if let app = AppLocale(rawValue: String(part).lowercased()) {
                    return app
                }
            }
        }
        return .defaultLocale
    }
}
