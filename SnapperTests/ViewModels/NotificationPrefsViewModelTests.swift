import XCTest
@testable import Snapper

@MainActor
final class NotificationPrefsViewModelTests: XCTestCase {

    private var mockAPI: MockAPIClient!

    override func setUp() async throws {
        try await super.setUp()
        mockAPI = MockAPIClient()
    }

    override func tearDown() async throws {
        mockAPI = nil
        try await super.tearDown()
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
        minPriority: String = "medium",
        quietHoursStartMin: Int? = nil,
        quietHoursEndMin: Int? = nil,
        muteUntil: Date? = nil
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
            quietHoursStartMin: quietHoursStartMin,
            quietHoursEndMin: quietHoursEndMin,
            muteUntil: muteUntil,
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
    func testInitialStateIsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.defaults.isEmpty)
        XCTAssertTrue(viewModel.devicePrefs.isEmpty)
        XCTAssertNil(viewModel.devicePublicId)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.loadError)
        XCTAssertTrue(viewModel.inflightAlertTypes.isEmpty)
    }
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
        /// The handler must NOT fire — record any call to fail loud.
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

    func testLoadUsesDefaultDeviceRegistrationProviderWhenNotInjected() async {
        let service = DeviceRegistrationService.shared()
        await service.onLogout()
        let viewModel = NotificationPrefsViewModel(api: mockAPI)
        let defaultsResp = makeDefaultsResponse([makeAlertDefault()])
        mockAPI.fetchAlertDefaultsHandler = { defaultsResp }
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
        await service.onLogout()
    }

    /// Empty-string device id leak guard: a `deviceIdProvider`
    /// that returns `""` (e.g. a half-resolved registration state)
    /// must NOT be stored in `devicePublicId`, otherwise the View
    /// would render the device as "registered" and let the user
    /// fire `updateDevicePref` against `/devices//prefs` — an
    /// invalid path segment that would 404 at the backend. The VM
    /// normalizes empty to nil.
    func testLoadNormalizesEmptyDeviceIdToNil() async {
        let viewModel = makeViewModel(deviceId: "")
        let defaultsResp = makeDefaultsResponse([makeAlertDefault()])
        mockAPI.fetchAlertDefaultsHandler = { defaultsResp }
        let calls = NotifPrefsCallCounter()
        mockAPI.fetchDevicePrefsHandler = { _ in
            await calls.increment()
            throw APIError.invalidResponse
        }
        await viewModel.load()
        let count = await calls.count
        XCTAssertEqual(count, 0, "Empty device id must NOT trigger device-prefs fetch")
        XCTAssertNil(
            viewModel.devicePublicId,
            "Empty device id must normalize to nil so the View doesn't render an invalid registered state"
        )
    }

    /// Q9b regression guard: the alert-defaults + device-prefs
    /// fetches must run CONCURRENTLY (`async let` fan-out), not
    /// sequentially. Both handlers sleep for N ms; if the load
    /// is parallel, total wall-clock time ≈ N ms; if it regressed
    /// to sequential, total time ≈ 2N ms. The test asserts the
    /// parallel envelope so a future refactor that accidentally
    /// awaits one before starting the other fails loudly.
    func testLoadFiresAlertDefaultsAndDevicePrefsConcurrently() async {
        let viewModel = makeViewModel()
        let defaultsResp = makeDefaultsResponse([makeAlertDefault()])
        let prefsResp = makePrefsResponse([])
        mockAPI.fetchAlertDefaultsHandler = {
            try await Task.sleep(nanoseconds: 100_000_000)
            return defaultsResp
        }
        mockAPI.fetchDevicePrefsHandler = { _ in
            try await Task.sleep(nanoseconds: 100_000_000)
            return prefsResp
        }
        let started = Date()
        await viewModel.load()
        let elapsedMs = Date().timeIntervalSince(started) * 1000
        /// Sequential would be ≥200 ms (two 100-ms sleeps stacked).
        /// Parallel is ≈100 ms; allow 50 ms slack for actor hop +
        /// CI noise but stay well under the 200 ms regression line.
        XCTAssertLessThan(
            elapsedMs,
            180,
            "load() must fan out async let — sequential would be ≥200ms; got \(elapsedMs)ms"
        )
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

    func testRevokeDevicePrefHappyPathRemovesRowOptimistically() async {
        let viewModel = makeViewModel()
        viewModel.devicePublicId = "device-public-1"
        let pref1 = makeDevicePref(publicId: "p-1")
        let pref2 = makeDevicePref(publicId: "p-2", alertType: "margin_warning")
        viewModel.devicePrefs = [pref1, pref2]
        let revokeResponse = RevokeDevicePrefResponse(
            type: "revoke_device_pref_response",
            sequenceId: 1,
            publicId: "envelope",
            timestamp: Self.baseTimestamp,
            sessionId: "session-test",
            topic: nil,
            payload: pref1
        )
        mockAPI.revokeDevicePrefHandler = { _, _, _ in revokeResponse }

        let success = await viewModel.revokeDevicePref(prefPublicId: "p-1")

        XCTAssertTrue(success)
        XCTAssertEqual(viewModel.devicePrefs.map(\.publicId), ["p-2"])
        XCTAssertNil(viewModel.loadError)
    }

    func testRevokeDevicePrefRevertsRowOnFailure() async {
        let viewModel = makeViewModel()
        viewModel.devicePublicId = "device-public-1"
        let pref = makeDevicePref(publicId: "p-1")
        viewModel.devicePrefs = [pref]
        mockAPI.revokeDevicePrefHandler = { _, _, _ in throw APIError.invalidResponse }

        let success = await viewModel.revokeDevicePref(prefPublicId: "p-1")

        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.devicePrefs.map(\.publicId), ["p-1"])
        XCTAssertNotNil(viewModel.loadError)
    }

    func testRevokeDevicePref404IsTreatedAsSuccess() async {
        let viewModel = makeViewModel()
        viewModel.devicePublicId = "device-public-1"
        viewModel.devicePrefs = [makeDevicePref(publicId: "p-1")]
        mockAPI.revokeDevicePrefHandler = { _, _, _ in throw APIError.httpError(404) }

        let success = await viewModel.revokeDevicePref(prefPublicId: "p-1")

        XCTAssertTrue(success, "404 means already-closed upstream — idempotent re-revoke")
        XCTAssertTrue(viewModel.devicePrefs.isEmpty)
        XCTAssertNil(viewModel.loadError)
    }

    func testRevokeDevicePrefNoOpWhenDeviceNotRegistered() async {
        let viewModel = makeViewModel(deviceId: nil)
        viewModel.devicePrefs = [makeDevicePref(publicId: "p-1")]

        let success = await viewModel.revokeDevicePref(prefPublicId: "p-1")

        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.devicePrefs.map(\.publicId), ["p-1"])
    }

    func testApplySavedPrefReplacesByScopeTupleWhenPublicIdChanges() {
        let viewModel = makeViewModel()
        viewModel.devicePrefs = [
            makeDevicePref(
                publicId: "old-id",
                alertType: "margin_warning",
                walletPublicId: "wallet-1",
                operatorPublicId: "operator-1",
                enabled: true
            )
        ]
        let saved = makeDevicePref(
            publicId: "new-id",
            alertType: "margin_warning",
            walletPublicId: "wallet-1",
            operatorPublicId: "operator-1",
            enabled: false
        )

        viewModel.applySavedPref(saved)

        XCTAssertEqual(viewModel.devicePrefs.count, 1)
        XCTAssertEqual(viewModel.devicePrefs.first?.publicId, "new-id")
        XCTAssertEqual(viewModel.devicePrefs.first?.enabled, false)
    }
    func testDisplayNameMapsKnownAlertTypes() {
        XCTAssertEqual(NotificationPrefsViewModel.displayName(for: "order_fill_full"), "Order filled")
        XCTAssertEqual(NotificationPrefsViewModel.displayName(for: "order_rejected"), "Order rejected")
        XCTAssertEqual(NotificationPrefsViewModel.displayName(for: "position_stop_loss_fired"), "Stop-loss fired")
        XCTAssertEqual(NotificationPrefsViewModel.displayName(for: "margin_warning"), "Margin warning")
        XCTAssertEqual(NotificationPrefsViewModel.displayName(for: "critical_system_error"), "System error")
        XCTAssertEqual(NotificationPrefsViewModel.displayName(for: "unknown"), "unknown")
    }

    func testPriorityDisplayNameCapitalizesFirstLetter() {
        XCTAssertEqual(NotificationPrefsViewModel.priorityDisplayName(for: "medium"), "Medium")
        XCTAssertEqual(NotificationPrefsViewModel.priorityDisplayName(for: ""), "")
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

    func testSummaryLabelIncludesQuietHoursAndFutureMute() {
        let pref = makeDevicePref(
            publicId: "p-1",
            enabled: false,
            minPriority: "high",
            quietHoursStartMin: 60,
            quietHoursEndMin: 125,
            muteUntil: Date().addingTimeInterval(3600)
        )

        let summary = NotificationPrefsViewModel.summaryLabel(for: pref)

        XCTAssertTrue(summary.contains("Muted"))
        XCTAssertTrue(summary.contains("min High"),
                      "Priority should round-trip through catalog (catalog value is 'High', capitalised); got summary=\(summary)")
        XCTAssertTrue(summary.contains("quiet 01:00–02:05"))
        XCTAssertTrue(summary.contains("muted until"))
    }

    func testSummaryLabelSkipsExpiredMute() {
        let pref = makeDevicePref(
            publicId: "p-1",
            muteUntil: Date().addingTimeInterval(-3600)
        )

        let summary = NotificationPrefsViewModel.summaryLabel(for: pref)

        XCTAssertFalse(summary.contains("muted until"))
    }

    /// Catalog round-trip: every leaking helper renders the Polish
    /// catalog string when given ``language: .pl`` — guards against
    /// silent regressions where the rawValue fallback path masks a
    /// missing catalog key.
    func testSummaryAndScopeAndDisplayLabelsLocalize() {
        let pref = makeDevicePref(
            publicId: "p-1",
            walletPublicId: "01961234567890",
            enabled: true,
            minPriority: "medium",
            quietHoursStartMin: 60,
            quietHoursEndMin: 125
        )
        let plDisplay = NotificationPrefsViewModel.displayName(for: "order_fill_full", language: .pl)
        XCTAssertNotEqual(plDisplay, "Order filled",
                          "PL catalog must produce a native value; got \(plDisplay)")

        let plPriority = NotificationPrefsViewModel.priorityDisplayName(for: "medium", language: .pl)
        XCTAssertNotEqual(plPriority, "Medium",
                          "PL catalog must produce a native priority label; got \(plPriority)")

        let plScope = NotificationPrefsViewModel.scopeLabel(for: pref, language: .pl)
        XCTAssertFalse(plScope.hasPrefix("Wallet "),
                       "PL scopeLabel.wallet must NOT leak the EN 'Wallet' prefix; got \(plScope)")

        let plSummary = NotificationPrefsViewModel.summaryLabel(for: pref, language: .pl)
        XCTAssertFalse(plSummary.contains("Enabled"),
                       "PL summary must NOT leak EN 'Enabled'; got \(plSummary)")
        XCTAssertFalse(plSummary.contains("min Medium"),
                       "PL summary must use native priority; got \(plSummary)")
    }
}

private actor NotifPrefsCallCounter {
    private(set) var count: Int = 0
    func increment() { count += 1 }
}
