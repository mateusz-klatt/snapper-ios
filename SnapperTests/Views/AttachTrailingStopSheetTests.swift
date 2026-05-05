import XCTest
@testable import Snapper

@MainActor
final class AttachTrailingStopSheetTests: XCTestCase {

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private static let fixedProvenance = EnvelopeMinter.Provenance(
        publicId: "test-public-id",
        sessionId: "session-test",
        sequenceId: 23,
        timestamp: baseTimestamp,
        timestampString: "2023-11-14T22:13:20.000Z"
    )

    func testParsePercentHandlesLocalisedAndPathologicalInput() {
        XCTAssertEqual(AttachTrailingStopSheetViewModel.parsePercent("1.5"), 1.5)
        XCTAssertEqual(AttachTrailingStopSheetViewModel.parsePercent("1,5"), 1.5)
        XCTAssertEqual(AttachTrailingStopSheetViewModel.parsePercent(" 2 "), 2.0)
        XCTAssertNil(AttachTrailingStopSheetViewModel.parsePercent(""))
        XCTAssertNil(AttachTrailingStopSheetViewModel.parsePercent("0"))
        XCTAssertNil(AttachTrailingStopSheetViewModel.parsePercent("-1"))
        XCTAssertNil(AttachTrailingStopSheetViewModel.parsePercent("abc"))
    }

    /// Backend `TrailingStopCreateBody` requires a positive
    /// `trailing_pct`. `min_lock_pct` is optional and never gates
    /// the submit button on its own.
    func testCanSubmitRequiresTrailingDistanceOnly() {
        XCTAssertTrue(
            AttachTrailingStopSheetViewModel.canSubmit(trailingPct: 1.5, minLockPct: nil, isSubmitting: false)
        )
        XCTAssertTrue(
            AttachTrailingStopSheetViewModel.canSubmit(trailingPct: 1.5, minLockPct: 0.5, isSubmitting: false)
        )
        XCTAssertFalse(
            AttachTrailingStopSheetViewModel.canSubmit(trailingPct: nil, minLockPct: nil, isSubmitting: false)
        )
        XCTAssertFalse(
            AttachTrailingStopSheetViewModel.canSubmit(trailingPct: nil, minLockPct: 0.5, isSubmitting: false)
        )
    }

    func testCanSubmitBlocksWhileInFlight() {
        XCTAssertFalse(
            AttachTrailingStopSheetViewModel.canSubmit(trailingPct: 1.5, minLockPct: 0.5, isSubmitting: true)
        )
    }

    func testMakeCommandEmbedsCycleIdAndProvenance() {
        let command = AttachTrailingStopSheetViewModel.makeCommand(
            positionCyclePublicId: "cycle-2",
            trailingPct: 1.5,
            minLockPct: 0.5,
            idempotencyKey: "trail-idem-2",
            provenance: Self.fixedProvenance
        )
        XCTAssertEqual(command.type, "create_trailing_stop_command")
        XCTAssertEqual(command.publicId, "test-public-id")
        XCTAssertEqual(command.sessionId, "session-test")
        XCTAssertEqual(command.sequenceId, 23)
        XCTAssertEqual(command.payload.positionCyclePublicId, "cycle-2")
        XCTAssertEqual(command.payload.trailingPct, 1.5)
        XCTAssertEqual(command.payload.minLockPct, 0.5)
        XCTAssertEqual(command.payload.idempotencyKey, "trail-idem-2")
    }

    func testMakeCommandWithoutMinLockPct() {
        let command = AttachTrailingStopSheetViewModel.makeCommand(
            positionCyclePublicId: "cycle-3",
            trailingPct: 2.0,
            minLockPct: nil,
            idempotencyKey: "trail-idem-3",
            provenance: Self.fixedProvenance
        )
        XCTAssertEqual(command.payload.trailingPct, 2.0)
        XCTAssertNil(command.payload.minLockPct)
        XCTAssertEqual(command.payload.idempotencyKey, "trail-idem-3")
    }
}
