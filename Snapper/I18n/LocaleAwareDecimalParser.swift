import Foundation

/// Locale-aware decimal-string parser.
///
/// Accepts BOTH the locale's decimal separator AND the universal ``.``
/// when parsing user input, so a PL user typing ``1,5`` and ``1.5`` both
/// yield ``1.5``. Rejects ambiguous shapes like ``1.5.6`` or strings
/// that contain non-digit / non-separator characters.
///
/// Used by trading-input fields (``NewOrderSheet``, ``AttachBracketSheet``,
/// ``AttachTrailingStopSheet``) where the operator's locale may use
/// comma decimal separators but the underlying API expects a canonical
/// decimal-point representation.
enum LocaleAwareDecimalParser {

    /// Parse ``input`` against the user's ``locale``. Returns the
    /// parsed ``Decimal`` or ``nil`` on any failure (empty, whitespace,
    /// multiple separators, non-digit characters outside the leading
    /// sign + thousands group).
    static func parse(_ input: String, locale: AppLocale) -> Decimal? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let canonical = canonicalize(trimmed, locale: locale)
        guard isValidDecimal(canonical) else { return nil }
        return Decimal(string: canonical, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Strip thousands-group separators for the locale and convert the
    /// locale's decimal separator into the canonical ``.``.
    private static func canonicalize(_ input: String, locale: AppLocale) -> String {
        let fLocale = locale.nativeLocale
        let groupingSeparator = fLocale.groupingSeparator ?? ""
        let decimalSeparator = fLocale.decimalSeparator ?? "."
        var stripped = input
        if !groupingSeparator.isEmpty {
            stripped = stripped.replacingOccurrences(of: groupingSeparator, with: "")
        }
        stripped = stripped.replacingOccurrences(of: "\u{00A0}", with: "")
        if decimalSeparator != "." {
            stripped = stripped.replacingOccurrences(of: decimalSeparator, with: ".")
        }
        return stripped
    }

    /// True if ``s`` is a syntactically valid decimal with optional sign
    /// + at most one decimal point + only digits. Rejects scientific
    /// notation by intent (trading inputs never need ``e+12``).
    private static func isValidDecimal(_ s: String) -> Bool {
        let allowedFirst: Set<Character> = ["+", "-"]
        let allowedDigit: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        var dotCount = 0
        var seenDigit = false
        for (index, ch) in s.enumerated() {
            if index == 0 && allowedFirst.contains(ch) { continue }
            if ch == "." {
                dotCount += 1
                if dotCount > 1 { return false }
                continue
            }
            if allowedDigit.contains(ch) {
                seenDigit = true
                continue
            }
            return false
        }
        return seenDigit
    }
}
