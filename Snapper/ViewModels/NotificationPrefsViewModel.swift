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
        /// Treat empty-string device id as "not registered" — the
        /// View only nil-checks, so storing "" would render as a
        /// registered device and let the user fire `updateDevicePref`
        /// with an invalid `/devices//prefs` path segment.
        let normalizedDeviceId: String? = (resolvedDeviceId?.isEmpty == false) ? resolvedDeviceId : nil
        devicePublicId = normalizedDeviceId

        /// Fan out alert-defaults + device-prefs concurrently. The
        /// device-prefs call requires the resolved device id; if the
        /// device isn't registered (`nil` after normalization), skip
        /// the device-prefs fetch entirely and surface only the alert
        /// defaults.
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
            /// Device-pref failure does NOT clobber the alert-defaults
            /// banner — overrides being unavailable while defaults load
            /// is the legitimate "device not yet registered" UX.
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
            /// Clear the prior failure banner on a successful save so
            /// the screen doesn't keep showing "Couldn't save…" after
            /// the user retries and the next PATCH lands cleanly.
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

    /// Revoke (SCD2 close) a device-scoped override.
    ///
    /// Optimistic remove with revert-on-failure: drops the row from
    /// the local list before the network call so the swipe-to-delete
    /// gesture lands instantly, then refunds it if the backend call
    /// fails. A 404 is treated as success (the row is already gone
    /// upstream — idempotent re-revoke), which prevents a stuck row
    /// when the user double-taps the swipe action.
    ///
    /// Returns ``true`` on success (row removed); ``false`` on
    /// non-404 failure (row reverted, banner shown).
    @discardableResult
    func revokeDevicePref(prefPublicId: String) async -> Bool {
        guard let devicePublicId else { return false }
        let originalIndex = devicePrefs.firstIndex(where: { $0.publicId == prefPublicId })
        let snapshot = originalIndex.map { devicePrefs[$0] }
        if let originalIndex {
            devicePrefs.remove(at: originalIndex)
        }
        let command = Self.makeRevokeCommand()
        do {
            _ = try await api.revokeDevicePref(
                devicePublicId: devicePublicId,
                prefPublicId: prefPublicId,
                command: command
            )
            loadError = nil
            return true
        } catch let APIError.httpError(404) {
            loadError = nil
            return true
        } catch {
            logger.error(
                "Failed to revoke device pref \(prefPublicId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            if let originalIndex, let snapshot {
                let insertAt = min(originalIndex, devicePrefs.count)
                devicePrefs.insert(snapshot, at: insertAt)
            }
            loadError = "Couldn't remove override. Try again."
            return false
        }
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

    /// Resolve an alert type rawValue ("order_fill_full" etc.) against
    /// the existing ``alerts.alertType.*`` catalog namespace so the
    /// label re-localizes when the user switches in-app language.
    static func displayName(for alertType: String, language: CatalogLanguage = .en) -> String {
        return LocaleStrings.localizedRawValue(
            alertType,
            namespace: "alerts.alertType",
            in: language
        )
    }

    /// Resolve a priority rawValue ("low" / "medium" / "high") against
    /// the ``notifications.prefs.priority.*`` catalog namespace.
    static func priorityDisplayName(for priority: String, language: CatalogLanguage = .en) -> String {
        return LocaleStrings.localizedRawValue(
            priority,
            namespace: "notifications.prefs.priority",
            in: language
        )
    }

    static func scopeLabel(for pref: DeviceAlertPrefInfo, language: CatalogLanguage = .en) -> String {
        let lookupLocale = Locale(identifier: language.rawValue)
        if let walletId = pref.walletPublicId {
            let template = LocaleStrings.localized("notifications.devicePref.scopeLabel.wallet", in: language)
            return String(format: template, locale: lookupLocale, String(walletId.prefix(8)))
        }
        if let operatorId = pref.operatorPublicId {
            let template = LocaleStrings.localized("notifications.devicePref.scopeLabel.operator", in: language)
            return String(format: template, locale: lookupLocale, String(operatorId.prefix(8)))
        }
        return LocaleStrings.localized("notifications.devicePref.scopeLabel.deviceGlobal", in: language)
    }

    static func summaryLabel(for pref: DeviceAlertPrefInfo, language: CatalogLanguage = .en) -> String {
        let lookupLocale = Locale(identifier: language.rawValue)
        var parts: [String] = []
        parts.append(LocaleStrings.localized(
            pref.enabled
                ? "notifications.devicePref.summary.enabled"
                : "notifications.devicePref.summary.muted",
            in: language
        ))
        let priorityName = priorityDisplayName(for: pref.minPriority, language: language)
        let minPriorityTemplate = LocaleStrings.localized("notifications.devicePref.summary.minPriority", in: language)
        parts.append(String(format: minPriorityTemplate, locale: lookupLocale, priorityName))
        if let start = pref.quietHoursStartMin, let end = pref.quietHoursEndMin {
            let quietTemplate = LocaleStrings.localized("notifications.devicePref.summary.quietHours", in: language)
            parts.append(String(
                format: quietTemplate,
                locale: lookupLocale,
                formatMinutes(start),
                formatMinutes(end)
            ))
        }
        if let muteUntil = pref.muteUntil, muteUntil > Date() {
            let relative = formatRelativeDate(muteUntil, language: language)
            let mutedUntilTemplate = LocaleStrings.localized("notifications.devicePref.summary.mutedUntil", in: language)
            parts.append(String(format: mutedUntilTemplate, locale: lookupLocale, relative))
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

    @MainActor
    static func makeRevokeCommand(
        reason: String? = nil,
        provenance: EnvelopeMinter.Provenance? = nil
    ) -> RevokeDevicePrefCommand {
        let envelope = provenance ?? EnvelopeMinter.shared.next(.control)
        return RevokeDevicePrefCommand(
            type: "revoke_device_pref_command",
            sequenceId: envelope.sequenceId,
            publicId: envelope.publicId,
            timestamp: envelope.timestamp,
            sessionId: envelope.sessionId,
            topic: nil,
            payload: RevokeDevicePrefBody(reason: reason)
        )
    }

    /// Relative-time renderer pinned to the requested catalog language so
    /// PL/JP/AR users see native phrasing ("za 5 min", "5分後", "خلال 5
    /// دقائق") instead of English ("in 5 min") regardless of the
    /// device's system locale.
    static func formatRelativeDate(_ date: Date, language: CatalogLanguage = .en) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
