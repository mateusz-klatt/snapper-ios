import XCTest
@testable import Snapper

@MainActor
final class HomeViewTests: XCTestCase {

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeAlert(publicId: String, title: String) -> AlertEventInfo {
        return AlertEventInfo(
            type: "alert_event_info",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-home-test",
            topic: nil,
            userPublicId: "user-1",
            operatorPublicId: nil,
            walletPublicId: nil,
            alertType: "order_filled",
            priority: "low",
            isSafetyCritical: false,
            title: title,
            body: "fixture body",
            payload: nil,
            dedupKey: nil,
            threadKey: nil,
            sourceTopic: nil
        )
    }

    private func makeHistory(payload: [AlertEventInfo]) -> AlertHistoryResponse {
        return AlertHistoryResponse(
            type: "alert_history_response",
            sequenceId: 1,
            publicId: "envelope-1",
            timestamp: Self.baseTimestamp,
            sessionId: "session-home-test",
            topic: nil,
            payload: payload,
            count: payload.count,
            nextCursor: nil
        )
    }

    /// Empty history pages collapse to ``nil`` so ``LatestAlertCard``
    /// renders ``EmptyView`` and the Home layout stays compact.
    func testFirstAlertFromEmptyHistoryReturnsNil() {
        let history = makeHistory(payload: [])
        XCTAssertNil(HomeView.firstAlert(from: history))
    }

    /// Non-empty history surfaces the page-leading row — the backend
    /// orders alerts newest-first so this is the most recent alert.
    func testFirstAlertFromHistoryReturnsLeadingRow() {
        let head = makeAlert(publicId: "newest", title: "BTC fill")
        let tail = makeAlert(publicId: "older", title: "BTC stop")
        let history = makeHistory(payload: [head, tail])

        let result = HomeView.firstAlert(from: history)

        XCTAssertEqual(result?.publicId, "newest")
        XCTAssertEqual(result?.title, "BTC fill")
    }

    private func makeOrder(
        publicId: String,
        status: String,
        walletPublicId: String?
    ) -> OrderStatus {
        return OrderData(
            type: "order_data",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-home-test",
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
            price: 50_000.0,
            averagePrice: nil,
            reason: nil,
            timeInForce: nil,
            error: nil,
            createdAt: Self.baseTimestamp,
            updatedAt: nil,
            leverage: nil,
            reduceOnly: nil,
            walletPublicId: walletPublicId,
            operatorPublicId: nil,
            userPublicId: nil,
            planPublicId: nil
        )
    }

    /// Wallet-scope (PR #6): the Home "Active Orders" counter must
    /// only count orders owned by the wallet the user picked in
    /// the toolbar — previously it counted across the entire
    /// orders array, drifting from PositionsView / OrdersView.
    func testFilterActiveOrdersRespectsWalletScope() {
        let walletAOpen = makeOrder(publicId: "a-open", status: "open", walletPublicId: "wallet-a")
        let walletAFilled = makeOrder(publicId: "a-filled", status: "filled", walletPublicId: "wallet-a")
        let walletBOpen = makeOrder(publicId: "b-open", status: "open", walletPublicId: "wallet-b")
        let orphanOpen = makeOrder(publicId: "orphan-open", status: "open", walletPublicId: nil)

        let scoped = HomeView.filterActiveOrders(
            orders: [walletAOpen, walletAFilled, walletBOpen, orphanOpen],
            selectedWalletPublicId: "wallet-a"
        )

        XCTAssertEqual(
            Set(scoped.map(\.publicId)),
            Set(["a-open", "orphan-open"]),
            "wallet-a + orphan (nil walletPublicId pass-through) should both count; wallet-b drops; filled drops."
        )
    }

    /// Canonical lifecycle set (PR #6): the Active Orders counter
    /// must use ``OrdersView.openStatuses`` (``new`` / ``submitted``
    /// / ``open`` / ``partially_filled``) instead of the previous
    /// ad-hoc ``"open"|"pending"`` pair, which under-counted orders
    /// the user could still cancel.
    func testFilterActiveOrdersCoversFullOpenLifecycleSet() {
        let orders = [
            makeOrder(publicId: "n", status: "new", walletPublicId: nil),
            makeOrder(publicId: "s", status: "submitted", walletPublicId: nil),
            makeOrder(publicId: "o", status: "open", walletPublicId: nil),
            makeOrder(publicId: "p", status: "partially_filled", walletPublicId: nil),
            makeOrder(publicId: "f", status: "filled", walletPublicId: nil),
            makeOrder(publicId: "c", status: "cancelled", walletPublicId: nil),
            makeOrder(publicId: "r", status: "rejected", walletPublicId: nil),
        ]

        let active = HomeView.filterActiveOrders(
            orders: orders,
            selectedWalletPublicId: nil
        )

        XCTAssertEqual(active.map(\.publicId), ["n", "s", "o", "p"])
    }

    /// nil wallet selection passes every row through (Home's
    /// counters fall back to global counts when no wallet is
    /// picked yet on first launch).
    func testFilterActiveOrdersWithNilWalletPassesEveryOpenRow() {
        let walletA = makeOrder(publicId: "a", status: "open", walletPublicId: "wallet-a")
        let walletB = makeOrder(publicId: "b", status: "open", walletPublicId: "wallet-b")

        let active = HomeView.filterActiveOrders(
            orders: [walletA, walletB],
            selectedWalletPublicId: nil
        )

        XCTAssertEqual(active.count, 2)
    }
}
