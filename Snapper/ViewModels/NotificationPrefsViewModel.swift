import Foundation
import Observation
import os

/// ViewModel for `NotificationPrefsView` — extracted in v0.3.1.
///
/// Owns: alert-default + device-pref data, the device public-id
/// resolution, isLoading, loadError, the per-row in-flight set, the
/// async `load()` (now ACTUALLY parallel via `async let`, fixing
/// Q9b from the architect consensus where the doc claimed parallel
/// but the implementation was sequential), and the
/// optimistic-update `mutateDefault()` flow.
///
/// Sheet/alert presentation flags (`sheetMode`) stay as `@State`
/// in the View per Q3.
@MainActor
@Observable
final class NotificationPrefsViewModel {

    var defaults: [String: UserAlertDefaultInfo] = [:]
    var devicePrefs: [DeviceAlertPrefInfo] = []
    var devicePublicId: String?
    var isLoading: Bool = false
    var loadError: String?
    var inflightAlertTypes: Set<String> = []

    private let api: APIClientProtocol
    private let deviceIdProvider: @Sendable () async -> String?

    private let logger = AppLogger.make(category: "NotificationPrefsViewModel")

    init(
        api: APIClientProtocol = APIClient.shared,
        deviceIdProvider: @escaping @Sendable () async -> String? = { DeviceRegistrationService.shared().currentDevicePublicId() }
    ) {
        self.api = api
        self.deviceIdProvider = deviceIdProvider
    }
    /// Parallel-load alert defaults + device prefs (after resolving
    /// the device public id). The pre-MVVM body's docstring claimed
    /// "fetched in parallel via `async let`" but the implementation
    /// was sequential — Q9b in the architect consensus flagged
    /// the drift; this VM honours the original intent.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        loadError = nil

        let resolvedDeviceId = await deviceIdProvider()
        // Treat empty-string device id as "not registered" — the
        // View only nil-checks, so storing "" would render as a
        // registered device and let the user fire `updateDevicePref`
        // with an invalid `/devices//prefs` path segment.
        let normalizedDeviceId: String? = (resolvedDeviceId?.isEmpty == false) ? resolvedDeviceId : nil
        devicePublicId = normalizedDeviceId

        // Fan out alert-defaults + device-prefs concurrently. The
        // device-prefs call requires the resolved device id; if the
        // device isn't registered (`nil` after normalization), skip
        // the device-prefs fetch entirely and surface only the alert
        // defaults.
        async let defaultsResult = api.fetchAlertDefaults()
        async let prefsResult: DeviceAlertPrefListResponse? = {
            guard let id = normalizedDeviceId else { return nil }
            return try await api.fetchDevicePrefs(devicePublicId: id)
        }()

        do {
            let envelope = try await defaultsResult
            defaults = Dictionary(uniqueKeysWithValues: envelope.payload.map { ($0.alertType, $0) })
        } catch {
            logger.error("Failed to fetch alert defaults: \(error.localizedDescription, privacy: .public)")
            loadError = "Couldn't load preferences. Pull to refresh."
        }

        do {
            if let envelope = try await prefsResult {
                devicePrefs = envelope.payload
            }
        } catch {
            logger.error("Failed to fetch device prefs: \(error.localizedDescription, privacy: .public)")
            // Device-pref failure does NOT clobber the alert-defaults
            // banner — overrides being unavailable while defaults load
            // is the legitimate "device not yet registered" UX.
        }
    }

    /// Optimistic-update + revert-on-failure: returns `true` on
    /// success so the calling row keeps the tapped value, `false`
    /// on failure so the row reverts its local state.
    @discardableResult
    func mutateDefault(
        alertType: String,
        enabled: Bool,
        minPriority: String
    ) async -> Bool {
        inflightAlertTypes.insert(alertType)
        defer { inflightAlertTypes.remove(alertType) }

        let command = Self.makeDefaultCommand(
            alertType: alertType,
            enabled: enabled,
            minPriority: minPriority
        )
        do {
            let response = try await api.updateAlertDefault(command: command)
            defaults[alertType] = response.payload
            // Clear the prior failure banner on a successful save so
            // the screen doesn't keep showing "Couldn't save…" after
            // the user retries and the next PATCH lands cleanly.
            loadError = nil
            return true
        } catch {
            logger.error("Failed to update alert default for \(alertType, privacy: .public): \(error.localizedDescription, privacy: .public)")
            loadError = "Couldn't save preference. Try again."
            return false
        }
    }

    /// Merge a saved `DeviceAlertPrefInfo` into the local cache.
    /// Replaces an existing row that shares the same scope tuple
    /// (alert_type, operator_public_id, wallet_public_id) — the
    /// SCD2 upsert preserves the same `public_id` so a bare
    /// publicId match suffices on the happy path. New scopes
    /// append.
    func applySavedPref(_ saved: DeviceAlertPrefInfo) {
        Self.applySavedPref(saved, into: &devicePrefs)
    }
    /// Backend-canonical alert_types in display order.
    static let alertTypes: [String] = [
        "order_fill_full",
        "order_rejected",
        "position_stop_loss_fired",
        "margin_warning",
        "critical_system_error",
    ]

    static let priorityValues: [String] = ["low", "medium", "high"]

    static func displayName(for alertType: String) -> String {
        switch alertType {
        case "order_fill_full": return "Order filled"
        case "order_rejected": return "Order rejected"
        case "position_stop_loss_fired": return "Stop-loss fired"
        case "margin_warning": return "Margin warning"
        case "critical_system_error": return "System error"
        default: return alertType
        }
    }

    static func priorityDisplayName(for priority: String) -> String {
        return priority.prefix(1).uppercased() + priority.dropFirst()
    }

    static func scopeLabel(for pref: DeviceAlertPrefInfo) -> String {
        if let walletId = pref.walletPublicId {
            return "Wallet \(String(walletId.prefix(8)))…"
        }
        if let operatorId = pref.operatorPublicId {
            return "Operator \(String(operatorId.prefix(8)))…"
        }
        return "Device-global"
    }

    static func summaryLabel(for pref: DeviceAlertPrefInfo) -> String {
        var parts: [String] = []
        parts.append(pref.enabled ? "Enabled" : "Muted")
        parts.append("min \(pref.minPriority)")
        if let start = pref.quietHoursStartMin, let end = pref.quietHoursEndMin {
            parts.append("quiet \(formatMinutes(start))–\(formatMinutes(end))")
        }
        if let muteUntil = pref.muteUntil, muteUntil > Date() {
            parts.append("muted until \(formatRelativeDate(muteUntil))")
        }
        return parts.joined(separator: " · ")
    }

    static func formatMinutes(_ totalMinutes: Int) -> String {
        guard (0..<1440).contains(totalMinutes) else {
            return String(totalMinutes)
        }
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    static func applySavedPref(
        _ saved: DeviceAlertPrefInfo,
        into prefs: inout [DeviceAlertPrefInfo]
    ) {
        if let index = prefs.firstIndex(where: { $0.publicId == saved.publicId }) {
            prefs[index] = saved
        } else if let scopeIndex = prefs.firstIndex(where: {
            $0.alertType == saved.alertType
                && $0.operatorPublicId == saved.operatorPublicId
                && $0.walletPublicId == saved.walletPublicId
        }) {
            prefs[scopeIndex] = saved
        } else {
            prefs.append(saved)
        }
    }

    @MainActor
    static func makeDefaultCommand(
        alertType: String,
        enabled: Bool,
        minPriority: String,
        provenance: EnvelopeMinter.Provenance? = nil
    ) -> UpdateUserAlertDefaultCommand {
        let envelope = provenance ?? EnvelopeMinter.shared.next(.control)
        return UpdateUserAlertDefaultCommand(
            type: "update_user_alert_default_command",
            sequenceId: envelope.sequenceId,
            publicId: envelope.publicId,
            timestamp: envelope.timestamp,
            sessionId: envelope.sessionId,
            topic: nil,
            payload: UserAlertDefaultBody(
                alertType: alertType,
                enabled: enabled,
                minPriority: minPriority
            )
        )
    }

    private static func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
