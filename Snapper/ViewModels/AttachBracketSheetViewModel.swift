import Foundation
import Observation

/// ViewModel for `AttachBracketSheet` — extracted in v0.3.1 so the
/// form's state, idempotency key, and submit re-entry guard can be
/// tested in isolation. The View shrinks to a thin Form binder.
///
/// `onSubmit` stays a parent-injected closure (parent VM owns the
/// `APIClient.createBracket` round trip — see Q5 in
/// `docs/architecture-mvvm.md`). The sheet VM only owns form
/// state, parsing, validation, and the `idempotencyKey` lifecycle.
@MainActor
@Observable
final class AttachBracketSheetViewModel {

    var slPriceText: String = ""
    var tpPriceText: String = ""
    var isSubmitting: Bool = false

    /// Stable across in-sheet retries; new key per VM presentation.
    let idempotencyKey: String

    init(idempotencyKey: String = UUID().uuidString) {
        self.idempotencyKey = idempotencyKey
    }

    var parsedSL: Double? {
        return Self.parsePrice(slPriceText)
    }

    var parsedTP: Double? {
        return Self.parsePrice(tpPriceText)
    }

    var canSubmit: Bool {
        return Self.canSubmit(
            slPrice: parsedSL,
            tpPrice: parsedTP,
            isSubmitting: isSubmitting
        )
    }

    /// Submit via the parent-injected closure. Re-entry-guarded so a
    /// frantic double-tap cannot fire two parallel bracket POSTs;
    /// `defer` clears `isSubmitting` so the user can retry on
    /// failure under the same idempotency key.
    @discardableResult
    func submit(
        via onSubmit: (Double?, Double?, String) async -> Bool
    ) async -> Bool {
        guard !isSubmitting, canSubmit else { return false }
        let sl = parsedSL
        let tp = parsedTP
        isSubmitting = true
        defer { isSubmitting = false }
        return await onSubmit(sl, tp, idempotencyKey)
    }
    // for backward-compatible test contract)

    /// Parses a free-text price string into a positive `Double`.
    /// Empty / non-numeric / non-positive input maps to `nil` so the
    /// caller treats it as "not supplied" rather than zero — the
    /// backend's bracket validator rejects zero-priced legs.
    static func parsePrice(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    /// Submit gate: at least one leg parsed AND not already in flight.
    /// Mirrors backend `BracketCreateBody` validator at
    /// `snapper.api.schemas.commands` requiring at least one of
    /// `sl_price` / `tp_price`.
    static func canSubmit(
        slPrice: Double?,
        tpPrice: Double?,
        isSubmitting: Bool
    ) -> Bool {
        guard !isSubmitting else { return false }
        return slPrice != nil || tpPrice != nil
    }

    /// Build the iOS-side `BracketCreateCommand` envelope.
    @MainActor
    static func makeCommand(
        positionCyclePublicId: String,
        slPrice: Double?,
        tpPrice: Double?,
        idempotencyKey: String,
        provenance: EnvelopeMinter.Provenance? = nil
    ) -> BracketCreateCommand {
        let envelope = provenance ?? EnvelopeMinter.shared.next(.control)
        return BracketCreateCommand(
            type: "create_bracket_command",
            sequenceId: envelope.sequenceId,
            publicId: envelope.publicId,
            timestamp: envelope.timestamp,
            sessionId: envelope.sessionId,
            topic: nil,
            payload: BracketCreateBody(
                positionCyclePublicId: positionCyclePublicId,
                slPrice: slPrice,
                tpPrice: tpPrice,
                idempotencyKey: idempotencyKey
            )
        )
    }
}
