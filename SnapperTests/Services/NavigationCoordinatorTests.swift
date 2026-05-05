import XCTest
import UserNotifications
@testable import Snapper

/// Tests for ``NavigationCoordinator`` deep-link state holder.
///
/// Coordinator only exposes two state fields (pendingDeepLink +
/// pendingAlertPublicId) + two mutators
/// (`handleNotificationTap`, `clearPendingDeepLink`). Tests cover
/// the happy path, the missing-payload-path, and the clear path.
@MainActor
final class NavigationCoordinatorTests: XCTestCase {

    private var coordinator: NavigationCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = NavigationCoordinator()
    }

    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }

    func testHandleTapWithFullPayloadPrimesBothFields() async {
        let response = _makeResponse(withUserInfo: [
            "deep_link_path": "/orders/coid-1",
            "alert_event_public_id": "alert-1",
        ])

        await coordinator.handleNotificationTap(response)

        XCTAssertEqual(coordinator.pendingDeepLink, "/orders/coid-1")
        XCTAssertEqual(coordinator.pendingAlertPublicId, "alert-1")
    }

    func testHandleTapWithDeepLinkOnlyLeavesAnchorNil() async {
        let response = _makeResponse(withUserInfo: ["deep_link_path": "/system"])

        await coordinator.handleNotificationTap(response)

        XCTAssertEqual(coordinator.pendingDeepLink, "/system")
        XCTAssertNil(coordinator.pendingAlertPublicId)
    }

    func testHandleTapWithoutDeepLinkIsNoOp() async {
        let response = _makeResponse(withUserInfo: ["unrelated": "key"])

        await coordinator.handleNotificationTap(response)

        XCTAssertNil(coordinator.pendingDeepLink)
        XCTAssertNil(coordinator.pendingAlertPublicId)
    }

    func testClearResetsBothFields() async {
        let response = _makeResponse(withUserInfo: [
            "deep_link_path": "/orders/x",
            "alert_event_public_id": "alert-x",
        ])
        await coordinator.handleNotificationTap(response)

        coordinator.clearPendingDeepLink()

        XCTAssertNil(coordinator.pendingDeepLink)
        XCTAssertNil(coordinator.pendingAlertPublicId)
    }

    /// Logged-out deep-link replay regression: a notification tap that
    /// lands BEFORE ``MainTabView`` mounts (e.g. while the user is on
    /// ``LoginView``) sets ``pendingDeepLink`` on the coordinator, and
    /// the value must SURVIVE across non-clearing reads so the tab
    /// view's ``.onAppear`` hook can still consume it after the auth
    /// state flips and the tab view mounts. Without this contract,
    /// ``MainTabView``'s ``.onChange``-only consumption would miss
    /// the deep-link entirely (SwiftUI does not fire ``.onChange``
    /// for a value already set at first render).
    func testPendingDeepLinkSurvivesReadsBeforeExplicitClear() async {
        let response = _makeResponse(withUserInfo: [
            "deep_link_path": "/orders/coid-replay",
            "alert_event_public_id": "alert-replay",
        ])
        await coordinator.handleNotificationTap(response)

        // Multiple reads from the consumer (e.g. .onAppear + later
        // .onChange triggered by an unrelated state update) must all
        // see the same primed state until clearPendingDeepLink fires.
        XCTAssertEqual(coordinator.pendingDeepLink, "/orders/coid-replay")
        XCTAssertEqual(coordinator.pendingAlertPublicId, "alert-replay")
        XCTAssertEqual(coordinator.pendingDeepLink, "/orders/coid-replay")
        XCTAssertEqual(coordinator.pendingAlertPublicId, "alert-replay")

        coordinator.clearPendingDeepLink()

        XCTAssertNil(coordinator.pendingDeepLink)
        XCTAssertNil(coordinator.pendingAlertPublicId)
    }

    private func _makeResponse(withUserInfo userInfo: [AnyHashable: Any]) -> UNNotificationResponse {
        let content = UNMutableNotificationContent()
        content.title = "Test"
        content.body = "Body"
        content.userInfo = userInfo
        let request = UNNotificationRequest(identifier: "navtest", content: content, trigger: nil)
        let coder = NSKeyedArchiver(requiringSecureCoding: false)
        coder.encode(request, forKey: "request")
        coder.encode(Date(), forKey: "date")
        coder.finishEncoding()
        let data = coder.encodedData
        guard
            let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data),
            let notification = UNNotification(coder: unarchiver)
        else {
            fatalError("UNNotification synth failed")
        }
        unarchiver.finishDecoding()

        let responseCoder = NSKeyedArchiver(requiringSecureCoding: false)
        responseCoder.encode(notification, forKey: "notification")
        responseCoder.encode(UNNotificationDefaultActionIdentifier, forKey: "actionIdentifier")
        responseCoder.finishEncoding()
        let responseData = responseCoder.encodedData
        guard
            let responseUnarchiver = try? NSKeyedUnarchiver(forReadingFrom: responseData),
            let response = UNNotificationResponse(coder: responseUnarchiver)
        else {
            fatalError("UNNotificationResponse synth failed")
        }
        responseUnarchiver.finishDecoding()
        return response
    }
}
