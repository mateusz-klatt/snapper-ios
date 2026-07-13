import XCTest
@testable import Snapper

@MainActor
final class MainTabViewTests: XCTestCase {

    /// Post-iOS-3 deep-link routing table. Keeps the iOS-4 contract
    /// (``/alerts*`` ending up on the Alerts tab) intact while
    /// promoting ``/positions*`` to its own tab and switching the
    /// Dashboard fallback for ``/system*`` to Home.
    func testDeepLinkRoutingPostIOS3() {
        let alerts = "/alerts"
        let orders = "/orders"
        let positions = "/positions"
        let accounts = "/portfolio/accounts"
        let system = "/system"

        XCTAssertEqual(
            MainTabView.routeDeepLink(
                path: "\(alerts)/abc123",
                alertsPrefix: alerts,
                ordersPrefix: orders,
                positionsPrefix: positions,
                accountsPrefix: accounts,
                systemPrefix: system
            ),
            "alerts",
            "Alerts deep-links must stay on the Alerts tab to preserve the iOS-4 scroll-to-anchor contract."
        )

        XCTAssertEqual(
            MainTabView.routeDeepLink(
                path: "\(orders)/xyz",
                alertsPrefix: alerts,
                ordersPrefix: orders,
                positionsPrefix: positions,
                accountsPrefix: accounts,
                systemPrefix: system
            ),
            "orders"
        )

        XCTAssertEqual(
            MainTabView.routeDeepLink(
                path: "\(positions)/foo",
                alertsPrefix: alerts,
                ordersPrefix: orders,
                positionsPrefix: positions,
                accountsPrefix: accounts,
                systemPrefix: system
            ),
            "positions",
            "Positions deep-links route to the dedicated Positions tab now that iOS-3 has shipped."
        )

        XCTAssertEqual(
            MainTabView.routeDeepLink(
                path: "\(accounts)/wallet-1",
                alertsPrefix: alerts,
                ordersPrefix: orders,
                positionsPrefix: positions,
                accountsPrefix: accounts,
                systemPrefix: system
            ),
            "accounts"
        )

        XCTAssertEqual(
            MainTabView.routeDeepLink(
                path: "\(system)/health",
                alertsPrefix: alerts,
                ordersPrefix: orders,
                positionsPrefix: positions,
                accountsPrefix: accounts,
                systemPrefix: system
            ),
            "home"
        )

        XCTAssertNil(
            MainTabView.routeDeepLink(
                path: nil,
                alertsPrefix: alerts,
                ordersPrefix: orders,
                positionsPrefix: positions,
                accountsPrefix: accounts,
                systemPrefix: system
            ),
            "Empty deep-link must leave the current tab unchanged."
        )

        XCTAssertNil(
            MainTabView.routeDeepLink(
                path: "/auth/login",
                alertsPrefix: alerts,
                ordersPrefix: orders,
                positionsPrefix: positions,
                accountsPrefix: accounts,
                systemPrefix: system
            ),
            "Unrecognised paths must leave the current tab unchanged."
        )
    }

    func testAccountsTabRequiresPermissionAndResourceAccess() {
        XCTAssertTrue(MainTabView.canShowAccounts(
            hasReadAccountState: true,
            canAccessAccountsResource: true
        ))
        XCTAssertFalse(MainTabView.canShowAccounts(
            hasReadAccountState: false,
            canAccessAccountsResource: true
        ))
        XCTAssertFalse(MainTabView.canShowAccounts(
            hasReadAccountState: true,
            canAccessAccountsResource: false
        ))
        XCTAssertFalse(MainTabView.canShowAccounts(
            hasReadAccountState: false,
            canAccessAccountsResource: false
        ))
    }
}
