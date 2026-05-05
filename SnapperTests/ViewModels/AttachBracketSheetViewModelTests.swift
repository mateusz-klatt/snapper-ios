import XCTest
@testable import Snapper

/// Async / instance-state tests for `AttachBracketSheetViewModel`.
///
/// Pure-helper coverage (parsePrice, canSubmit, makeCommand) lives
/// in `Views/AttachBracketSheetTests.swift` and exercises the
/// static surface (the existing test contract). The tests here
/// drive the live VM through form mutation, computed parsing,
/// re-entry guard, and idempotency-stable submission.
@MainActor
final class AttachBracketSheetViewModelTests: XCTestCase {

    // MARK: - Initialization

    func testInitialStateIsBlankAndStable() {
        let viewModel = AttachBracketSheetViewModel(idempotencyKey: "test-key")
        XCTAssertEqual(viewModel.slPriceText, "")
        XCTAssertEqual(viewModel.tpPriceText, "")
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertEqual(viewModel.idempotencyKey, "test-key")
        XCTAssertNil(viewModel.parsedSL)
        XCTAssertNil(viewModel.parsedTP)
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testIdempotencyKeyChangesAcrossPresentations() {
        let vm1 = AttachBracketSheetViewModel()
        let vm2 = AttachBracketSheetViewModel()
        XCTAssertNotEqual(vm1.idempotencyKey, vm2.idempotencyKey)
        XCTAssertFalse(vm1.idempotencyKey.isEmpty)
    }

    // MARK: - Parsed legs

    func testParsedSLReflectsSlPriceText() {
        let viewModel = AttachBracketSheetViewModel()
        viewModel.slPriceText = "95.5"
        XCTAssertEqual(viewModel.parsedSL, 95.5)
        viewModel.slPriceText = "  100,5 "
        XCTAssertEqual(viewModel.parsedSL, 100.5)
        viewModel.slPriceText = "0"
        XCTAssertNil(viewModel.parsedSL)
        viewModel.slPriceText = ""
        XCTAssertNil(viewModel.parsedSL)
    }

    func testParsedTPReflectsTpPriceText() {
        let viewModel = AttachBracketSheetViewModel()
        viewModel.tpPriceText = "110"
        XCTAssertEqual(viewModel.parsedTP, 110.0)
        viewModel.tpPriceText = "abc"
        XCTAssertNil(viewModel.parsedTP)
    }

    // MARK: - canSubmit

    func testCanSubmitTrueWhenAtLeastOneLegParsed() {
        let viewModel = AttachBracketSheetViewModel()
        XCTAssertFalse(viewModel.canSubmit)
        viewModel.slPriceText = "95"
        XCTAssertTrue(viewModel.canSubmit)
        viewModel.slPriceText = ""
        viewModel.tpPriceText = "110"
        XCTAssertTrue(viewModel.canSubmit)
        viewModel.slPriceText = "95"
        XCTAssertTrue(viewModel.canSubmit, "Both legs is also valid")
    }

    func testCanSubmitFalseWhileSubmitting() {
        let viewModel = AttachBracketSheetViewModel()
        viewModel.slPriceText = "95"
        viewModel.isSubmitting = true
        XCTAssertFalse(viewModel.canSubmit)
    }

    // MARK: - submit

    func testSubmitFiresClosureWithParsedLegsAndIdempotencyKey() async {
        let viewModel = AttachBracketSheetViewModel(idempotencyKey: "bk-1")
        viewModel.slPriceText = "95.5"
        viewModel.tpPriceText = "110"
        let captured = CapturedBracketCall()
        let result = await viewModel.submit { sl, tp, key in
            await captured.set(sl: sl, tp: tp, key: key)
            return true
        }
        XCTAssertTrue(result)
        let snapshot = await captured.snapshot
        XCTAssertEqual(snapshot.0, 95.5)
        XCTAssertEqual(snapshot.1, 110.0)
        XCTAssertEqual(snapshot.2, "bk-1")
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func testSubmitShortCircuitsWhenCannotSubmit() async {
        let viewModel = AttachBracketSheetViewModel()
        // No price text — canSubmit false.
        let calls = BracketCallCounter()
        let result = await viewModel.submit { _, _, _ in
            await calls.increment()
            return true
        }
        XCTAssertFalse(result)
        let count = await calls.count
        XCTAssertEqual(count, 0)
    }

    func testSubmitClearsIsSubmittingOnFailure() async {
        let viewModel = AttachBracketSheetViewModel()
        viewModel.slPriceText = "95"
        let result = await viewModel.submit { _, _, _ in return false }
        XCTAssertFalse(result)
        XCTAssertFalse(viewModel.isSubmitting)
    }

    /// Re-entry guard: a second submit while the first is in
    /// flight must short-circuit so a frantic double-tap cannot
    /// fire two parallel bracket POSTs.
    func testSubmitGuardsAgainstReentryWhileInFlight() async {
        let viewModel = AttachBracketSheetViewModel()
        viewModel.slPriceText = "95"
        let counter = BracketCallCounter()
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

    /// Idempotency key must stay stable across retries within the
    /// same VM instance — server-side dedup keys on it.
    func testIdempotencyKeyStableAcrossRetries() async {
        let viewModel = AttachBracketSheetViewModel(idempotencyKey: "bk-stable")
        viewModel.slPriceText = "95"
        let collector = BracketKeyCollector()
        _ = await viewModel.submit { _, _, key in
            await collector.append(key)
            return false
        }
        _ = await viewModel.submit { _, _, key in
            await collector.append(key)
            return true
        }
        let keys = await collector.keys
        XCTAssertEqual(keys, ["bk-stable", "bk-stable"])
    }
}

private actor CapturedBracketCall {
    private(set) var sl: Double?
    private(set) var tp: Double?
    private(set) var key: String?
    func set(sl: Double?, tp: Double?, key: String) {
        self.sl = sl
        self.tp = tp
        self.key = key
    }
    var snapshot: (Double?, Double?, String?) { (sl, tp, key) }
}

private actor BracketCallCounter {
    private(set) var count: Int = 0
    func increment() { count += 1 }
}

private actor BracketKeyCollector {
    private(set) var keys: [String] = []
    func append(_ key: String) { keys.append(key) }
}
