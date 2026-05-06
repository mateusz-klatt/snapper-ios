import Foundation
import Observation

/// ViewModel for `AttachTrailingStopSheet` — extracted in v0.3.1
/// alongside `AttachBracketSheetViewModel`. Same shape: form
/// state, idempotency key, and submit re-entry guard live in the
/// VM; the View binds directly via `$viewModel.field`.
///
/// `onSubmit` stays a parent-injected closure (parent VM owns the
/// `APIClient.createTrailingStop` round trip).
@MainActor
@Observable
final class AttachTrailingStopSheetViewModel {

    var trailingPctText: String = ""
    var minLockPctText: String = ""
    var isSubmitting: Bool = false

    /// Stable across in-sheet retries; new key per VM presentation.
    let idempotencyKey: String

    init(idempotencyKey: String = UUID().uuidString) {
        self.idempotencyKey = idempotencyKey
    }

    var parsedTrailing: Double? {
        return Self.parsePercent(trailingPctText)
    }

    var parsedMinLock: Double? {
        return Self.parsePercent(minLockPctText)
    }

    var canSubmit: Bool {
        return Self.canSubmit(
            trailingPct: parsedTrailing,
            minLockPct: parsedMinLock,
            isSubmitting: isSubmitting
        )
    }

    /// Submit via the parent-injected closure. The trailing
    /// distance is mandatory (the only required payload field) so
    /// the guard rejects a tap if it didn't parse; bracket-shape
    /// `defer` keeps the sheet open on failure.
    @discardableResult
    func submit(
        via onSubmit: (Double, Double?, String) async -> Bool
    ) async -> Bool {
        guard !isSubmitting, let trailing = parsedTrailing else { return false }
        let minLock = parsedMinLock
        isSubmitting = true
        defer { isSubmitting = false }
        return await onSubmit(trailing, minLock, idempotencyKey)
    }

    /// Parse a free-text percent into a positive `Double`. Empty /
    /// non-numeric / non-positive input maps to `nil` so the caller
    /// treats it as "not supplied" rather than zero — the backend
    /// rejects zero-distance trails.
    static func parsePercent(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    /// Submit gate: trailing distance present (the only required
    /// payload field) AND not already in flight.
    static func canSubmit(
        trailingPct: Double?,
        minLockPct: Double?,
        isSubmitting: Bool
    ) -> Bool {
        _ = minLockPct
        guard !isSubmitting else { return false }
        return trailingPct != nil
    }

    /// Build the iOS-side `TrailingStopCreateCommand` envelope.
    @MainActor
    static func makeCommand(
        positionCyclePublicId: String,
        trailingPct: Double,
        minLockPct: Double?,
        idempotencyKey: String,
        provenance: EnvelopeMinter.Provenance? = nil
    ) -> TrailingStopCreateCommand {
        let envelope = provenance ?? EnvelopeMinter.shared.next(.control)
        return TrailingStopCreateCommand(
            type: "create_trailing_stop_command",
            sequenceId: envelope.sequenceId,
            publicId: envelope.publicId,
            timestamp: envelope.timestamp,
            sessionId: envelope.sessionId,
            topic: nil,
            payload: TrailingStopCreateBody(
                positionCyclePublicId: positionCyclePublicId,
                trailingPct: trailingPct,
                minLockPct: minLockPct,
                idempotencyKey: idempotencyKey
            )
        )
    }
}
