import XCTest
@testable import Snapper

@MainActor
final class OrdersViewTests: XCTestCase {

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeOrder(
        publicId: String,
        status: String,
        walletPublicId: String?,
        createdAtOffset: TimeInterval
    ) -> OrderStatus {
        return OrderData(
            type: "order_data",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-orders-test",
            topic: nil,
            exchangeOrderId: nil,
            clientOrderId: "cli-\(publicId)",
            instrument: "BTCUSD",
            exchange: "kraken",
            mode: nil,
            side: "buy",
            status: status,
            orderType: "limit",
            size: 1.0,
            filledSize: 0.0,
            price: 50000.0,
            averagePrice: nil,
            reason: nil,
            timeInForce: nil,
            error: nil,
            createdAt: Self.baseTimestamp.addingTimeInterval(createdAtOffset),
            updatedAt: nil,
            leverage: nil,
            reduceOnly: nil,
            walletPublicId: walletPublicId,
            operatorPublicId: nil,
            userPublicId: nil,
            planPublicId: nil,
            pairedGroupId: nil,
            pairedGroupSize: nil,
            pairedGroupIndex: nil,
            pairedGroupPolicy: nil
        )
    }

    private func makeExecution(
        publicId: String,
        walletPublicId: String?
    ) -> ExecutionRecord {
        return ExecutionData(
            type: "execution_data",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-orders-test",
            topic: nil,
            tradeId: nil,
            exchangeOrderId: nil,
            clientOrderId: "cli-\(publicId)",
            instrument: "BTCUSD",
            exchange: "kraken",
            side: "buy",
            size: 1.0,
            price: 50000.0,
            lastSize: 1.0,
            lastPrice: 50000.0,
            fee: 0.1,
            feeAsset: "USD",
            status: "filled",
            executedAt: Self.baseTimestamp,
            walletPublicId: walletPublicId,
            operatorPublicId: nil,
            userPublicId: nil,
            liquidityRole: nil,
            pairedGroupId: nil,
            pairedGroupSize: nil,
            pairedGroupIndex: nil,
            pairedGroupPolicy: nil
        )
    }

    /// Open lifecycle states from ``OrderStatusEnum`` (``new`` /
    /// ``submitted`` / ``open`` / ``partially_filled``) pass through;
    /// terminal states (``filled``/``cancelled``/``rejected``) drop.
    func testFilterOpenKeepsOnlyOpenStatuses() {
        let orders = [
            makeOrder(publicId: "n", status: "new", walletPublicId: nil, createdAtOffset: 0),
            makeOrder(publicId: "s", status: "submitted", walletPublicId: nil, createdAtOffset: 1),
            makeOrder(publicId: "o", status: "open", walletPublicId: nil, createdAtOffset: 2),
            makeOrder(publicId: "p", status: "partially_filled", walletPublicId: nil, createdAtOffset: 3),
            makeOrder(publicId: "f", status: "filled", walletPublicId: nil, createdAtOffset: 4),
            makeOrder(publicId: "c", status: "cancelled", walletPublicId: nil, createdAtOffset: 5),
            makeOrder(publicId: "r", status: "rejected", walletPublicId: nil, createdAtOffset: 6),
        ]

        let result = OrdersViewModel.filterOpen(orders: orders, selectedWalletPublicId: nil)

        XCTAssertEqual(result.map(\.publicId), ["n", "s", "o", "p"])
    }

    /// Recent sorts newest-first by ``createdAt`` and caps at the
    /// page limit. Wallet scope still applies — rows from other
    /// wallets are removed before the sort + cap.
    func testFilterRecentSortsByCreatedAtAndCaps() {
        let orders = [
            makeOrder(publicId: "old", status: "filled", walletPublicId: "w-a", createdAtOffset: 0),
            makeOrder(publicId: "newest", status: "filled", walletPublicId: "w-a", createdAtOffset: 100),
            makeOrder(publicId: "mid", status: "filled", walletPublicId: "w-a", createdAtOffset: 50),
            makeOrder(publicId: "other", status: "filled", walletPublicId: "w-b", createdAtOffset: 200),
        ]

        let scoped = OrdersViewModel.filterRecent(
            orders: orders,
            selectedWalletPublicId: "w-a",
            limit: 50
        )

        XCTAssertEqual(scoped.map(\.publicId), ["newest", "mid", "old"])

        let capped = OrdersViewModel.filterRecent(
            orders: orders,
            selectedWalletPublicId: nil,
            limit: 2
        )

        XCTAssertEqual(capped.count, 2)
        XCTAssertEqual(capped.first?.publicId, "other")
    }

    /// Fills respect wallet scope; rows with ``nil`` wallet pass
    /// through so legacy / system executions are not silently dropped.
    func testFilterFillsRespectsWalletScope() {
        let executions = [
            makeExecution(publicId: "x-a", walletPublicId: "w-a"),
            makeExecution(publicId: "x-b", walletPublicId: "w-b"),
            makeExecution(publicId: "x-orphan", walletPublicId: nil),
        ]

        let scoped = OrdersViewModel.filterFills(
            executions: executions,
            selectedWalletPublicId: "w-a"
        )

        XCTAssertEqual(Set(scoped.map(\.publicId)), Set(["x-a", "x-orphan"]))

        let unscoped = OrdersViewModel.filterFills(
            executions: executions,
            selectedWalletPublicId: nil
        )

        XCTAssertEqual(unscoped.count, 3)
    }

    func testWalletMatchesCoversScopedUnscopedAndLegacyRows() {
        XCTAssertTrue(OrdersViewModel.walletMatches(rowWalletId: nil, selected: nil))
        XCTAssertTrue(OrdersViewModel.walletMatches(rowWalletId: "w-a", selected: nil))
        XCTAssertTrue(OrdersViewModel.walletMatches(rowWalletId: nil, selected: "w-a"))
        XCTAssertTrue(OrdersViewModel.walletMatches(rowWalletId: "w-a", selected: "w-a"))
        XCTAssertFalse(OrdersViewModel.walletMatches(rowWalletId: "w-b", selected: "w-a"))
    }

    /// Surface-load-errors branch (PR #2): the orders list prepends
    /// a "Couldn't load" Section when the most recent fetch failed.
    func testShouldShowLoadErrorWhenErrorMessageSet() {
        XCTAssertTrue(
            OrdersViewModel.shouldShowLoadError(
                errorMessage: "Network unavailable",
                isLoading: false
            )
        )
    }

    /// Mid-load suppression — the spinner state owns the screen, no
    /// stale error banner flashes above an active fetch.
    func testShouldNotShowLoadErrorWhileLoading() {
        XCTAssertFalse(
            OrdersViewModel.shouldShowLoadError(
                errorMessage: "Network unavailable",
                isLoading: true
            )
        )
    }

    func testShouldNotShowLoadErrorWhenNil() {
        XCTAssertFalse(
            OrdersViewModel.shouldShowLoadError(
                errorMessage: nil,
                isLoading: false
            )
        )
    }

    /// Empty-string defensiveness — the catch block sets
    /// ``error.localizedDescription`` which can theoretically be
    /// empty, in which case the banner has nothing to show.
    func testShouldNotShowLoadErrorOnEmptyString() {
        XCTAssertFalse(
            OrdersViewModel.shouldShowLoadError(
                errorMessage: "",
                isLoading: false
            )
        )
    }

    /// Loading-placeholder branch (PR #2 fix-up): when isLoading
    /// suppresses the error banner and the active segment has no
    /// rows, a "Loading…" placeholder replaces the blank list the
    /// user would otherwise stare at after tapping Retry.
    func testShouldShowLoadingPlaceholderWhenLoadingAndEmpty() {
        XCTAssertTrue(
            OrdersViewModel.shouldShowLoadingPlaceholder(
                isLoading: true,
                activeSegmentIsEmpty: true
            )
        )
    }

    /// Cached rows take priority — re-fetching while the user has
    /// existing data on screen leaves the list visible instead of
    /// pushing a placeholder above their working data.
    func testShouldNotShowLoadingPlaceholderWhenSegmentHasData() {
        XCTAssertFalse(
            OrdersViewModel.shouldShowLoadingPlaceholder(
                isLoading: true,
                activeSegmentIsEmpty: false
            )
        )
    }

    func testShouldNotShowLoadingPlaceholderWhenIdle() {
        XCTAssertFalse(
            OrdersViewModel.shouldShowLoadingPlaceholder(
                isLoading: false,
                activeSegmentIsEmpty: true
            )
        )
    }
}
