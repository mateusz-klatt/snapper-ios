import XCTest
@testable import Snapper

@MainActor
final class NotificationPrefsViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() {
        mockAPI = nil
        super.tearDown()
    }

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeViewModel(
        deviceId: String? = "device-public-1"
    ) -> NotificationPrefsViewModel {
        return NotificationPrefsViewModel(
            api: mockAPI,
            deviceIdProvider: { deviceId }
        )
    }

    private func makeAlertDefault(
        alertType: String = "order_fill_full",
        enabled: Bool = true,
        minPriority: String = "medium"
    ) -> UserAlertDefaultInfo {
        return UserAlertDefaultInfo(
            type: "user_alert_default_info",
            sequenceId: 1,
            publicId: "default-\(alertType)",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            userPublicId: "user-1",
            alertType: alertType,
            enabled: enabled,
            minPriority: minPriority
        )
    }

    private func makeDefaultsResponse(
        _ defaults: [UserAlertDefaultInfo]
    ) -> UserAlertDefaultListResponse {
        return UserAlertDefaultListResponse(
            type: "user_alert_default_list_response",
            sequenceId: 1,
            publicId: "envelope",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            payload: defaults,
            count: defaults.count
        )
    }

    private func makeDefaultResponse(
        _ pref: UserAlertDefaultInfo
    ) -> UserAlertDefaultResponse {
        return UserAlertDefaultResponse(
            type: "user_alert_default_response",
            sequenceId: 1,
            publicId: "envelope",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            payload: pref
        )
    }

    private func makeDevicePref(
        publicId: String,
        alertType: String = "order_fill_full",
        walletPublicId: String? = nil,
        operatorPublicId: String? = nil,
        enabled: Bool = true,
        minPriority: String = "medium"
    ) -> DeviceAlertPrefInfo {
        return DeviceAlertPrefInfo(
            type: "device_alert_pref_info",
            sequenceId: 1,
            publicId: publicId,
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            devicePublicId: "device-1",
            alertType: alertType,
            operatorPublicId: operatorPublicId,
            walletPublicId: walletPublicId,
            enabled: enabled,
            minPriority: minPriority,
            quietHoursStartMin: nil,
            quietHoursEndMin: nil,
            muteUntil: nil,
            timezone: "UTC"
        )
    }

    private func makePrefsResponse(
        _ prefs: [DeviceAlertPrefInfo]
    ) -> DeviceAlertPrefListResponse {
        return DeviceAlertPrefListResponse(
            type: "device_alert_pref_list_response",
            sequenceId: 1,
            publicId: "envelope",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            payload: prefs,
            count: prefs.count
        )
    }

    // MARK: - Initialization

    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.defaults.isEmpty)
        XCTAssertTrue(viewModel.devicePrefs.isEmpty)
        XCTAssertNil(viewModel.devicePublicId)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
        XCTAssertTrue(viewModel.inflightAlertTypes.isEmpty)
    }

    // MARK: - load (parallel)

    func testLoadHappyPathPopulatesBoth() async {
        let viewModel = makeViewModel()
        let defaultsResp = makeDefaultsResponse([
            makeAlertDefault(alertType: "order_fill_full"),
            makeAlertDefault(alertType: "order_rejected", enabled: false),
        ])
        let prefsResp = makePrefsResponse([
            makeDevicePref(publicId: "pref-1"),
        ])
        mockAPI.fetchAlertDefaultsHandler = { defaultsResp }
        mockAPI.fetchDevicePrefsHandler = { _ in prefsResp }
        await viewModel.load()
        XCTAssertEqual(viewModel.devicePublicId, "device-public-1")
        XCTAssertEqual(viewModel.defaults.count, 2)
        XCTAssertNotNil(viewModel.defaults["order_fill_full"])
        XCTAssertEqual(viewModel.devicePrefs.count, 1)
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// When the device is not registered (`deviceIdProvider` returns
    /// nil), the device-prefs fetch must be skipped — only alert
    /// defaults load.
    func testLoadSkipsDevicePrefsFetchWhenNoDeviceRegistered() async {
        let viewModel = makeViewModel(deviceId: nil)
        let defaultsResp = makeDefaultsResponse([makeAlertDefault()])
        mockAPI.fetchAlertDefaultsHandler = { defaultsResp }
        // The handler must NOT fire — record any call to fail loud.
        let calls = NotifPrefsCallCounter()
        mockAPI.fetchDevicePrefsHandler = { _ in
            await calls.increment()
            throw APIError.invalidResponse
        }
        await viewModel.load()
        let count = await calls.count
        XCTAssertEqual(count, 0)
        XCTAssertNil(viewModel.devicePublicId)
        XCTAssertEqual(viewModel.defaults.count, 1)
    }

    func testLoadAlertDefaultsFailureStampsLoadError() async {
        let viewModel = makeViewModel()
        let prefsResp = makePrefsResponse([])
        mockAPI.fetchAlertDefaultsHandler = { throw APIError.httpError(503) }
        mockAPI.fetchDevicePrefsHandler = { _ in prefsResp }
        await viewModel.load()
        XCTAssertEqual(viewModel.loadError, "Couldn't load preferences. Pull to refresh.")
    }

    /// Device-pref failure must NOT clobber the alert-defaults
    /// banner — overrides being unavailable while defaults load is
    /// the legitimate "device not yet registered" UX.
    func testLoadDevicePrefsFailureDoesNotClobberDefaultsBanner() async {
        let viewModel = makeViewModel()
        let defaultsResp = makeDefaultsResponse([makeAlertDefault()])
        mockAPI.fetchAlertDefaultsHandler = { defaultsResp }
        mockAPI.fetchDevicePrefsHandler = { _ in throw APIError.httpError(503) }
        await viewModel.load()
        XCTAssertNil(viewModel.loadError, "Device-pref failure must NOT stamp loadError")
        XCTAssertEqual(viewModel.defaults.count, 1)
        XCTAssertTrue(viewModel.devicePrefs.isEmpty)
    }

    // MARK: - mutateDefault

    func testMutateDefaultSuccessReturnsTrueAndUpdatesDefaults() async {
        let viewModel = makeViewModel()
        let updated = makeAlertDefault(alertType: "order_fill_full", enabled: false, minPriority: "high")
        let resp = makeDefaultResponse(updated)
        mockAPI.updateAlertDefaultHandler = { _ in resp }
        let result = await viewModel.mutateDefault(
            alertType: "order_fill_full",
            enabled: false,
            minPriority: "high"
        )
        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.defaults["order_fill_full"]?.enabled, false)
        XCTAssertEqual(viewModel.defaults["order_fill_full"]?.minPriority, "high")
        XCTAssertNil(viewModel.loadError)
        XCTAssertFalse(viewModel.inflightAlertTypes.contains("order_fill_full"))
    }

    func testMutateDefaultClearsPriorLoadErrorOnSuccess() async {
        let viewModel = makeViewModel()
        viewModel.loadError = "Couldn't save preference. Try again."
        let updated = makeAlertDefault()
        let resp = makeDefaultResponse(updated)
        mockAPI.updateAlertDefaultHandler = { _ in resp }
        _ = await viewModel.mutateDefault(
            alertType: "order_fill_full",
            enabled: true,
            minPriority: "medium"
        )
        XCTAssertNil(viewModel.loadError)
    }

    func testMutateDefaultFailureReturnsFalseAndStampsError() async {
        let viewModel = makeViewModel()
        mockAPI.updateAlertDefaultHandler = { _ in throw APIError.httpError(422) }
        let result = await viewModel.mutateDefault(
            alertType: "order_fill_full",
            enabled: false,
            minPriority: "high"
        )
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.loadError, "Couldn't save preference. Try again.")
        XCTAssertFalse(viewModel.inflightAlertTypes.contains("order_fill_full"))
    }

    // MARK: - applySavedPref

    func testApplySavedPrefReplacesByPublicId() {
        let viewModel = makeViewModel()
        let original = makeDevicePref(publicId: "p-1", enabled: true)
        let updated = makeDevicePref(publicId: "p-1", enabled: false)
        viewModel.devicePrefs = [original]
        viewModel.applySavedPref(updated)
        XCTAssertEqual(viewModel.devicePrefs.count, 1)
        XCTAssertEqual(viewModel.devicePrefs.first?.enabled, false)
    }

    func testApplySavedPrefAppendsNewScope() {
        let viewModel = makeViewModel()
        viewModel.devicePrefs = [makeDevicePref(publicId: "p-1")]
        let added = makeDevicePref(publicId: "p-2", alertType: "margin_warning")
        viewModel.applySavedPref(added)
        XCTAssertEqual(viewModel.devicePrefs.count, 2)
    }

    // MARK: - Static helpers (sanity)

    func testDisplayNameMapsKnownAlertTypes() {
        XCTAssertEqual(NotificationPrefsViewModel.displayName(for: "order_fill_full"), "Order filled")
        XCTAssertEqual(NotificationPrefsViewModel.displayName(for: "margin_warning"), "Margin warning")
        XCTAssertEqual(NotificationPrefsViewModel.displayName(for: "unknown"), "unknown")
    }

    func testFormatMinutesHandlesValidAndInvalid() {
        XCTAssertEqual(NotificationPrefsViewModel.formatMinutes(0), "00:00")
        XCTAssertEqual(NotificationPrefsViewModel.formatMinutes(63), "01:03")
        XCTAssertEqual(NotificationPrefsViewModel.formatMinutes(1439), "23:59")
        XCTAssertEqual(
            NotificationPrefsViewModel.formatMinutes(1500),
            "1500",
            "Out-of-range falls back to raw integer"
        )
    }

    func testScopeLabelPrefixesIds() {
        let walletPref = makeDevicePref(publicId: "p-1", walletPublicId: "01961234567890")
        let opPref = makeDevicePref(publicId: "p-2", operatorPublicId: "01abcdefgh1234")
        let globalPref = makeDevicePref(publicId: "p-3")
        XCTAssertTrue(NotificationPrefsViewModel.scopeLabel(for: walletPref).hasPrefix("Wallet "))
        XCTAssertTrue(NotificationPrefsViewModel.scopeLabel(for: opPref).hasPrefix("Operator "))
        XCTAssertEqual(NotificationPrefsViewModel.scopeLabel(for: globalPref), "Device-global")
    }
}

private actor NotifPrefsCallCounter {
    private(set) var count: Int = 0
    func increment() { count += 1 }
}
