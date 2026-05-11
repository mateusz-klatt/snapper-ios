import Foundation

/// Shared JSON-decoding helpers reused by ``APIClient`` and
/// ``WebSocketManager``.
///
/// Lives outside the `@MainActor` services because Swift's
/// `JSONDecoder.DateDecodingStrategy.custom(_:)` expects a
/// `@Sendable` non-isolated closure — making the helper a
/// static on a `@MainActor` class would force every caller to
/// hop the main actor on decode, which is wrong for the
/// streaming WS path.
enum SnapperJSON {

    /// Cached ISO-8601 formatter that accepts fractional
    /// seconds (e.g. `2026-05-11T11:43:28.396870Z`). Allocating
    /// a fresh ``ISO8601DateFormatter`` per `Date` decode adds
    /// measurable overhead on an active WS stream (multiple
    /// dates per frame). Static formatters are thread-safe per
    /// Apple's documentation.
    nonisolated(unsafe) private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Fallback formatter for the bare RFC 3339 grammar
    /// (e.g. `2026-05-11T11:43:28Z`). `nonisolated(unsafe)` is
    /// required under Swift 6 strict concurrency because
    /// ``ISO8601DateFormatter`` is not annotated `Sendable`, but
    /// Apple's documentation explicitly guarantees that `date(from:)`
    /// is thread-safe once `formatOptions` is set at initialization
    /// (we never mutate the formatter after the closure returns).
    nonisolated(unsafe) private static let withoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// `JSONDecoder.dateDecodingStrategy = .custom(…)` body
    /// accepting ISO 8601 with OR without fractional seconds.
    /// Used by every Snapper REST / WS decoder so the two
    /// transports share one date contract.
    @Sendable
    static func decodeFractionalOrPlainISO8601(decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        if let date = withFractional.date(from: stringValue) { return date }
        if let date = withoutFractional.date(from: stringValue) { return date }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected ISO 8601 date string, got '\(stringValue)'"
        )
    }
}
