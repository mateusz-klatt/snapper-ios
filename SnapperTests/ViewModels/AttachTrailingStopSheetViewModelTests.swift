import XCTest
@testable import Snapper

/// Async / instance-state tests for `AttachTrailingStopSheetViewModel`.
@MainActor
final class AttachTrailingStopSheetViewModelTests: XCTestCase {

    // MARK: - Initialization

    func testInitialStateIsBlank() {
        let viewModel = AttachTrailingStopSheetViewModel(idempotencyKey: "tk-1")
        XCTAssertEqual(viewModel.trailingPctText, "")
        XCTAssertEqual(viewModel.minLockPctText, "")
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertEqual(viewModel.idempotencyKey, "tk-1")
        XCTAssertNil(viewModel.parsedTrailing)
        XCTAssertNil(viewModel.parsedMinLock)
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testIdempotencyKeyChangesAcrossPresentations() {
        let vm1 = AttachTrailingStopSheetViewModel()
        let vm2 = AttachTrailingStopSheetViewModel()
        XCTAssertNotEqual(vm1.idempotencyKey, vm2.idempotencyKey)
    }

    // MARK: - Parsed values

    func testParsedTrailingReflectsTrailingPctText() {
        let viewModel = AttachTrailingStopSheetViewModel()
        viewModel.trailingPctText = "1.5"
        XCTAssertEqual(viewModel.parsedTrailing, 1.5)
        viewModel.trailingPctText = "2,5"
        XCTAssertEqual(viewModel.parsedTrailing, 2.5)
        viewModel.trailingPctText = "0"
        XCTAssertNil(viewModel.parsedTrailing)
    }

    func testParsedMinLockReflectsMinLockPctText() {
        let viewModel = AttachTrailingStopSheetViewModel()
        viewModel.minLockPctText = "0.5"
        XCTAssertEqual(viewModel.parsedMinLock, 0.5)
        viewModel.minLockPctText = ""
        XCTAssertNil(viewModel.parsedMinLock)
    }

    // MARK: - canSubmit

    func testCanSubmitRequiresTrailingDistance() {
        let viewModel = AttachTrailingStopSheetViewModel()
        XCTAssertFalse(viewModel.canSubmit)
        viewModel.minLockPctText = "0.5"
        XCTAssertFalse(viewModel.canSubmit, "Min-lock alone is not enough")
        viewModel.trailingPctText = "1.5"
        XCTAssertTrue(viewModel.canSubmit)
        viewModel.minLockPctText = ""
        XCTAssertTrue(viewModel.canSubmit, "Trailing alone is enough")
    }

    func testCanSubmitFalseWhileSubmitting() {
        let viewModel = AttachTrailingStopSheetViewModel()
        viewModel.trailingPctText = "1.5"
        viewModel.isSubmitting = true
        XCTAssertFalse(viewModel.canSubmit)
    }

    // MARK: - submit

    func testSubmitFiresClosureWithParsedValues() async {
        let viewModel = AttachTrailingStopSheetViewModel(idempotencyKey: "ts-9")
        viewModel.trailingPctText = "1.5"
        viewModel.minLockPctText = "0.25"
        let captured = CapturedTrailingCall()
        let result = await viewModel.submit { trailing, minLock, key in
            await captured.set(trailing: trailing, minLock: minLock, key: key)
            return true
        }
        XCTAssertTrue(result)
        let snap = await captured.snapshot
        XCTAssertEqual(snap.0, 1.5)
        XCTAssertEqual(snap.1, 0.25)
        XCTAssertEqual(snap.2, "ts-9")
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func testSubmitFiresClosureWithNilMinLockWhenEmpty() async {
        let viewModel = AttachTrailingStopSheetViewModel(idempotencyKey: "ts-no-lock")
        viewModel.trailingPctText = "2"
        let captured = CapturedTrailingCall()
        _ = await viewModel.submit { trailing, minLock, key in
            await captured.set(trailing: trailing, minLock: minLock, key: key)
            return true
        }
        let snap = await captured.snapshot
        XCTAssertEqual(snap.0, 2)
        XCTAssertNil(snap.1, "Empty min-lock text → nil minLock to backend")
    }

    func testSubmitShortCircuitsWhenCannotSubmit() async {
        let viewModel = AttachTrailingStopSheetViewModel()
        let calls = TrailingCallCounter()
        let result = await viewModel.submit { _, _, _ in
            await calls.increment()
            return true
        }
        XCTAssertFalse(result)
        let count = await calls.count
        XCTAssertEqual(count, 0)
    }

    func testSubmitClearsIsSubmittingOnFailure() async {
        let viewModel = AttachTrailingStopSheetViewModel()
        viewModel.trailingPctText = "1"
        let result = await viewModel.submit { _, _, _ in return false }
        XCTAssertFalse(result)
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func testSubmitGuardsAgainstReentryWhileInFlight() async {
        let viewModel = AttachTrailingStopSheetViewModel()
        viewModel.trailingPctText = "1.5"
        let counter = TrailingCallCounter()
        let firstTask = Task {
            await viewModel.submit { _, _, _ in
                await counter.increment()
                try? await Task.sleep(nanoseconds: 50_000_000)
                return true
            }
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        let secondResult = await viewModel.submit { _, _, _ in
            await counter.increment()
            return true
        }
        await firstTask.value
        let total = await counter.count
        XCTAssertEqual(total, 1)
        XCTAssertFalse(secondResult)
    }

    func testIdempotencyKeyStableAcrossRetries() async {
        let viewModel = AttachTrailingStopSheetViewModel(idempotencyKey: "ts-stable")
        viewModel.trailingPctText = "1.5"
        let collector = TrailingKeyCollector()
        _ = await viewModel.submit { _, _, key in
            await collector.append(key)
            return false
        }
        _ = await viewModel.submit { _, _, key in
            await collector.append(key)
            return true
        }
        let keys = await collector.keys
        XCTAssertEqual(keys, ["ts-stable", "ts-stable"])
    }
}

private actor CapturedTrailingCall {
    private(set) var trailing: Double?
    private(set) var minLock: Double?
    private(set) var key: String?
    func set(trailing: Double?, minLock: Double?, key: String) {
        self.trailing = trailing
        self.minLock = minLock
        self.key = key
    }
    var snapshot: (Double?, Double?, String?) { (trailing, minLock, key) }
}

private actor TrailingCallCounter {
    private(set) var count: Int = 0
    func increment() { count += 1 }
}

private actor TrailingKeyCollector {
    private(set) var keys: [String] = []
    func append(_ key: String) { keys.append(key) }
}
