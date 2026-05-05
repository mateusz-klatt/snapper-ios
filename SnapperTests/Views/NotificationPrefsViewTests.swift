import XCTest
@testable import Snapper

@MainActor
final class NotificationPrefsViewTests: XCTestCase {

    private static let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDevicePref(
        publicId: String,
        alertType: String,
        operatorPublicId: String? = nil,
        walletPublicId: String? = nil,
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
            devicePublicId: "dev-1",
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

    func testAlertTypesMatchBackendCanonicalSet() {
        XCTAssertEqual(
            Set(NotificationPrefsViewModel.alertTypes),
            Set([
                "order_fill_full",
                "order_rejected",
                "position_stop_loss_fired",
                "margin_warning",
                "critical_system_error",
            ])
        )
    }

    func testDisplayNameCoversEveryCanonicalAlertType() {
        for alertType in NotificationPrefsViewModel.alertTypes {
            let label = NotificationPrefsViewModel.displayName(for: alertType)
            XCTAssertNotEqual(
                label,
                alertType,
                "Display name for \(alertType) must be distinct from the raw enum value."
            )
        }
        XCTAssertEqual(
            NotificationPrefsViewModel.displayName(for: "unknown_type"),
            "unknown_type",
            "Unknown alert types fall through to the raw value so a backend addition is visible without a UI patch."
        )
    }

    func testPriorityDisplayNameCapitalisesFirstLetter() {
        XCTAssertEqual(NotificationPrefsViewModel.priorityDisplayName(for: "low"), "Low")
        XCTAssertEqual(NotificationPrefsViewModel.priorityDisplayName(for: "medium"), "Medium")
        XCTAssertEqual(NotificationPrefsViewModel.priorityDisplayName(for: "high"), "High")
    }

    func testScopeLabelCoversEveryScopeShape() {
        let global = makeDevicePref(publicId: "p-1", alertType: "order_fill_full")
        XCTAssertEqual(NotificationPrefsViewModel.scopeLabel(for: global), "Device-global")

        let walletScoped = makeDevicePref(
            publicId: "p-2",
            alertType: "order_fill_full",
            walletPublicId: "wallet-abcdef0123456789"
        )
        XCTAssertTrue(NotificationPrefsViewModel.scopeLabel(for: walletScoped).hasPrefix("Wallet "))

        let operatorScoped = makeDevicePref(
            publicId: "p-3",
            alertType: "order_fill_full",
            operatorPublicId: "operator-1234567890"
        )
        XCTAssertTrue(NotificationPrefsViewModel.scopeLabel(for: operatorScoped).hasPrefix("Operator "))
    }

    func testFormatMinutesProducesHHMM() {
        XCTAssertEqual(NotificationPrefsViewModel.formatMinutes(0), "00:00")
        XCTAssertEqual(NotificationPrefsViewModel.formatMinutes(60), "01:00")
        XCTAssertEqual(NotificationPrefsViewModel.formatMinutes(22 * 60 + 30), "22:30")
        XCTAssertEqual(NotificationPrefsViewModel.formatMinutes(1439), "23:59")
    }

    func testFormatMinutesOutOfRangeFallsThroughToRawInteger() {
        XCTAssertEqual(NotificationPrefsViewModel.formatMinutes(-1), "-1")
        XCTAssertEqual(NotificationPrefsViewModel.formatMinutes(1440), "1440")
    }

    func testSummaryLabelFormat() {
        let live = makeDevicePref(
            publicId: "p-live",
            alertType: "order_fill_full",
            enabled: true,
            minPriority: "high",
            quietHoursStartMin: 22 * 60,
            quietHoursEndMin: 7 * 60
        )
        let summary = NotificationPrefsViewModel.summaryLabel(for: live)
        XCTAssertTrue(summary.contains("Enabled"))
        XCTAssertTrue(summary.contains("min high"))
        XCTAssertTrue(summary.contains("quiet 22:00–07:00"))

        let muted = makeDevicePref(
            publicId: "p-muted",
            alertType: "order_fill_full",
            enabled: false,
            minPriority: "low"
        )
        XCTAssertTrue(NotificationPrefsViewModel.summaryLabel(for: muted).contains("Muted"))
    }

    /// Past ``muteUntil`` is not surfaced — only an active mute is
    /// worth showing in the summary line.
    func testSummaryLabelOmitsExpiredMuteUntil() {
        let pastMute = makeDevicePref(
            publicId: "p-expired",
            alertType: "order_fill_full",
            muteUntil: Date(timeIntervalSince1970: 1_500_000_000)
        )
        XCTAssertFalse(NotificationPrefsViewModel.summaryLabel(for: pastMute).contains("muted until"))
    }

    private static let fixedProvenance = EnvelopeMinter.Provenance(
        publicId: "test-public-id",
        sessionId: "session-test",
        sequenceId: 13,
        timestamp: baseTimestamp,
        timestampString: "2023-11-14T22:13:20.000Z"
    )

    func testMakeDefaultCommandShape() {
        let command = NotificationPrefsViewModel.makeDefaultCommand(
            alertType: "order_fill_full",
            enabled: false,
            minPriority: "high",
            provenance: Self.fixedProvenance
        )
        XCTAssertEqual(command.payload.alertType, "order_fill_full")
        XCTAssertEqual(command.payload.enabled, false)
        XCTAssertEqual(command.payload.minPriority, "high")
        XCTAssertEqual(command.timestamp, Self.baseTimestamp)
        XCTAssertEqual(command.type, "update_user_alert_default_command")
        XCTAssertEqual(command.publicId, "test-public-id")
        XCTAssertEqual(command.sessionId, "session-test")
        XCTAssertEqual(command.sequenceId, 13)
    }
}
