import SwiftUI
import os

/// Editor sheet for one device-scoped notification preference.
///
/// Two entry points:
/// - Tap an existing row in
///   ``NotificationPrefsView``'s device-overrides section: opens in
///   edit mode with ``alert_type`` AND scope tuple locked. The SCD2
///   key includes both, so changing either mid-edit would silently
///   create a sibling row instead of mutating the tapped one.
/// - "Add override" button: opens in new mode with the alert_type
///   picker + 3-mode scope picker enabled.
///
/// Scope picker (create mode only):
/// - Device-global: ``operator_public_id`` and ``wallet_public_id``
///   both null. Applies to every alert routed for the alert_type.
/// - Operator: ``operator_public_id`` set, ``wallet_public_id``
///   null. Applies to alerts whose scope tuple matches the operator.
/// - Wallet: BOTH ``operator_public_id`` and ``wallet_public_id``
///   set — backend ``ck_device_alert_valid_scope`` CHECK forbids
///   ``wallet_public_id`` without an accompanying
///   ``operator_public_id``.
///
/// Operator + wallet catalogs are loaded from
/// ``AppState.availableOperators`` / ``availableWallets`` —
/// ``EditDevicePrefView``'s ``.task`` modifier refreshes both on
/// sheet appearance so a stale catalog cannot block a recently-added
/// operator from being narrow-scoped.
struct EditDevicePrefView: View {
    enum Mode {
        case create
        case edit(existing: DeviceAlertPrefInfo)
    }

    enum ScopeKind: String, Hashable {
        case deviceGlobal
        case operator_
        case wallet
    }

    let mode: Mode
    let devicePublicId: String
    let onSaved: (DeviceAlertPrefInfo) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var alertType: String
    @State private var scopeKind: ScopeKind
    @State private var selectedOperatorId: String?
    @State private var selectedWalletId: String?
    @State private var enabled: Bool
    @State private var minPriority: String
    @State private var quietHoursEnabled: Bool
    @State private var quietHoursStart: Date
    @State private var quietHoursEnd: Date
    @State private var muteEnabled: Bool
    @State private var muteUntil: Date
    @State private var isSaving = false
    @State private var saveError: String?

    /// Preserved across save when editing — the SCD2 key on the row
    /// includes the operator+wallet tuple, so changing scope mid-edit
    /// would silently create a sibling row instead of mutating the
    /// tapped one.
    private let lockedOperatorPublicId: String?
    private let lockedWalletPublicId: String?

    private let logger = AppLogger.make(category: "EditDevicePrefView")

    init(
        mode: Mode,
        devicePublicId: String,
        onSaved: @escaping (DeviceAlertPrefInfo) -> Void
    ) {
        self.mode = mode
        self.devicePublicId = devicePublicId
        self.onSaved = onSaved

        let calendar = Calendar(identifier: .gregorian)
        let midnight = calendar.startOfDay(for: Date())

        switch mode {
        case .create:
            _alertType = State(initialValue: NotificationPrefsViewModel.alertTypes[0])
            _scopeKind = State(initialValue: .deviceGlobal)
            _selectedOperatorId = State(initialValue: nil)
            _selectedWalletId = State(initialValue: nil)
            _enabled = State(initialValue: true)
            _minPriority = State(initialValue: "medium")
            _quietHoursEnabled = State(initialValue: false)
            _quietHoursStart = State(initialValue: midnight)
            _quietHoursEnd = State(initialValue: midnight)
            _muteEnabled = State(initialValue: false)
            _muteUntil = State(initialValue: Date())
            self.lockedOperatorPublicId = nil
            self.lockedWalletPublicId = nil
        case .edit(let pref):
            _alertType = State(initialValue: pref.alertType)
            _scopeKind = State(
                initialValue: Self.scopeKindFromExisting(
                    operatorPublicId: pref.operatorPublicId,
                    walletPublicId: pref.walletPublicId
                )
            )
            _selectedOperatorId = State(initialValue: pref.operatorPublicId)
            _selectedWalletId = State(initialValue: pref.walletPublicId)
            _enabled = State(initialValue: pref.enabled)
            _minPriority = State(initialValue: pref.minPriority)
            let quietActive = pref.quietHoursStartMin != nil && pref.quietHoursEndMin != nil
            _quietHoursEnabled = State(initialValue: quietActive)
            _quietHoursStart = State(
                initialValue: Self.dateFromMinutes(pref.quietHoursStartMin ?? 0, base: midnight)
            )
            _quietHoursEnd = State(
                initialValue: Self.dateFromMinutes(pref.quietHoursEndMin ?? 0, base: midnight)
            )
            let muteActive = (pref.muteUntil ?? Date.distantPast) > Date()
            _muteEnabled = State(initialValue: muteActive)
            _muteUntil = State(initialValue: pref.muteUntil ?? Date())
            self.lockedOperatorPublicId = pref.operatorPublicId
            self.lockedWalletPublicId = pref.walletPublicId
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("notifications.devicePref.alertType.label")) {
                    if isAlertTypeLocked {
                        HStack {
                            Text(NotificationPrefsViewModel.displayName(for: alertType))
                            Spacer()
                            Text(LocalizedStringKey("notifications.devicePref.alertType.lockedBadge"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker(LocalizedStringKey("notifications.devicePref.alertType.label"), selection: $alertType) {
                            ForEach(NotificationPrefsViewModel.alertTypes, id: \.self) { type in
                                Text(NotificationPrefsViewModel.displayName(for: type)).tag(type)
                            }
                        }
                    }
                }

                Section {
                    if isAlertTypeLocked {
                        HStack {
                            Text(LocalizedStringKey("notifications.devicePref.scope.label"))
                            Spacer()
                            Text(Self.scopeDescription(
                                operatorPublicId: lockedOperatorPublicId,
                                walletPublicId: lockedWalletPublicId
                            ))
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker(LocalizedStringKey("notifications.devicePref.scope.label"), selection: $scopeKind) {
                            Text(LocalizedStringKey("notifications.devicePref.scope.deviceGlobal")).tag(ScopeKind.deviceGlobal)
                            Text(LocalizedStringKey("notifications.devicePref.scope.operator")).tag(ScopeKind.operator_)
                            Text(LocalizedStringKey("notifications.devicePref.scope.wallet")).tag(ScopeKind.wallet)
                        }
                        .pickerStyle(.segmented)

                        if scopeKind == .operator_ || scopeKind == .wallet {
                            Picker(LocalizedStringKey("notifications.devicePref.operatorPicker.title"), selection: $selectedOperatorId) {
                                Text(LocalizedStringKey("common.picker.selectPlaceholder")).tag(Optional<String>.none)
                                ForEach(appState.availableOperators, id: \.publicId) { operatorInfo in
                                    Text(operatorInfo.label)
                                        .tag(Optional(operatorInfo.publicId))
                                }
                            }
                        }

                        if scopeKind == .wallet {
                            Picker(LocalizedStringKey("notifications.devicePref.walletPicker.title"), selection: $selectedWalletId) {
                                Text(LocalizedStringKey("common.picker.selectPlaceholder")).tag(Optional<String>.none)
                                ForEach(appState.availableWallets, id: \.publicId) { wallet in
                                    Text(WalletPickerViewModel.walletDisplayName(wallet))
                                        .tag(Optional(wallet.publicId))
                                }
                            }
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("notifications.devicePref.scope.label"))
                } footer: {
                    if isAlertTypeLocked {
                        Text(LocalizedStringKey("notifications.devicePref.scope.footer.editLocked"))
                    } else if appState.availableOperators.isEmpty && scopeKind != .deviceGlobal {
                        Text(LocalizedStringKey("notifications.devicePref.scope.footer.loadingOperators"))
                    } else {
                        Text(LocalizedStringKey("notifications.devicePref.scope.footer.walletNeedsOperator"))
                    }
                }

                Section {
                    Toggle(LocalizedStringKey("notifications.prefs.row.enabled"), isOn: $enabled)
                    Picker(LocalizedStringKey("notifications.devicePref.minPriority.label"), selection: $minPriority) {
                        ForEach(NotificationPrefsViewModel.priorityValues, id: \.self) { priority in
                            Text(NotificationPrefsViewModel.priorityDisplayName(for: priority))
                                .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(LocalizedStringKey("notifications.devicePref.delivery.header"))
                }

                Section {
                    Toggle(LocalizedStringKey("notifications.devicePref.quietHours.label"), isOn: $quietHoursEnabled)
                    if quietHoursEnabled {
                        DatePicker(
                            LocalizedStringKey("notifications.devicePref.quietHours.from"),
                            selection: $quietHoursStart,
                            displayedComponents: [.hourAndMinute]
                        )
                        DatePicker(
                            LocalizedStringKey("notifications.devicePref.quietHours.to"),
                            selection: $quietHoursEnd,
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                } header: {
                    Text(LocalizedStringKey("notifications.devicePref.quietHours.label"))
                } footer: {
                    Text(LocalizedStringKey("notifications.devicePref.quietHours.footer"))
                }

                Section {
                    Toggle(LocalizedStringKey("notifications.devicePref.hardMute.label"), isOn: $muteEnabled)
                    if muteEnabled {
                        DatePicker(
                            LocalizedStringKey("notifications.devicePref.muteUntil.label"),
                            selection: $muteUntil,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                } header: {
                    Text(LocalizedStringKey("notifications.devicePref.muteUntil.label"))
                } footer: {
                    Text(LocalizedStringKey("notifications.devicePref.hardMute.footer"))
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("notifications.devicePref.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("backend.url.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("backend.url.save")) {
                        Task { await save() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView().controlSize(.large)
                }
            }
            .task {
                await refreshScopeCatalogs()
            }
        }
    }

    private func refreshScopeCatalogs() async {
        async let operatorsTask = loadOperators()
        async let walletsTask = loadWallets()
        _ = await (operatorsTask, walletsTask)
    }

    private func loadOperators() async {
        do {
            let operators = try await APIClient.shared.fetchOperators()
            appState.availableOperators = operators
        } catch {
            logger.info("Operator catalog refresh skipped: \(error.localizedDescription)")
        }
    }

    private func loadWallets() async {
        guard appState.availableWallets.isEmpty else { return }
        do {
            let wallets = try await APIClient.shared.fetchWallets()
            appState.availableWallets = wallets
        } catch {
            logger.info("Wallet catalog refresh skipped: \(error.localizedDescription)")
        }
    }
    var isAlertTypeLocked: Bool {
        if case .edit = mode { return true }
        return false
    }

    var navigationTitle: String {
        return isAlertTypeLocked ? "Edit override" : "New override"
    }

    var canSave: Bool {
        if isSaving { return false }
        if isAlertTypeLocked { return true }
        switch scopeKind {
        case .deviceGlobal:
            return true
        case .operator_:
            return selectedOperatorId != nil
        case .wallet:
            return selectedOperatorId != nil && selectedWalletId != nil
        }
    }

    /// Derive the editor's ``ScopeKind`` from a persisted scope
    /// tuple. Used in edit mode to seed the read-only display so the
    /// user can see exactly which scope they are editing.
    static func scopeKindFromExisting(
        operatorPublicId: String?,
        walletPublicId: String?
    ) -> ScopeKind {
        if walletPublicId != nil { return .wallet }
        if operatorPublicId != nil { return .operator_ }
        return .deviceGlobal
    }

    /// Resolve the (operator_public_id, wallet_public_id) tuple that
    /// should land in the PATCH command, based on the current scope
    /// state. Edit mode honours the locked tuple so an SCD2 sibling
    /// row is never created mid-edit; create mode pulls from the
    /// active scope picker selections.
    static func resolveScopeTuple(
        isAlertTypeLocked: Bool,
        lockedOperatorPublicId: String?,
        lockedWalletPublicId: String?,
        scopeKind: ScopeKind,
        selectedOperatorId: String?,
        selectedWalletId: String?
    ) -> (operatorPublicId: String?, walletPublicId: String?) {
        if isAlertTypeLocked {
            return (lockedOperatorPublicId, lockedWalletPublicId)
        }
        switch scopeKind {
        case .deviceGlobal:
            return (nil, nil)
        case .operator_:
            return (selectedOperatorId, nil)
        case .wallet:
            return (selectedOperatorId, selectedWalletId)
        }
    }

    /// Format the locked scope tuple for the read-only "Apply to"
    /// row. Wallet/operator narrowed rows surface their truncated
    /// public_ids so the user can correlate with the
    /// ``DevicePrefRow`` summary on the parent screen.
    static func scopeDescription(
        operatorPublicId: String?,
        walletPublicId: String?
    ) -> String {
        if let walletId = walletPublicId {
            let suffix = operatorPublicId.map { " · op \(String($0.prefix(6)))…" } ?? ""
            return "Wallet \(String(walletId.prefix(8)))…\(suffix)"
        }
        if let operatorId = operatorPublicId {
            return "Operator \(String(operatorId.prefix(8)))…"
        }
        return "Device-global"
    }

    /// Convert a ``DatePicker`` Date to the minutes-since-midnight
    /// integer the backend expects for quiet-hours windows.
    static func minutesSinceMidnight(for date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// Inverse of ``minutesSinceMidnight`` — used to seed
    /// ``DatePicker`` from a backend-supplied minute offset.
    static func dateFromMinutes(_ totalMinutes: Int, base: Date, calendar: Calendar = .current) -> Date {
        let clamped = max(0, min(1439, totalMinutes))
        let hour = clamped / 60
        let minute = clamped % 60
        return calendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: base
        ) ?? base
    }

    /// Build the iOS-side envelope for ``PATCH /api/devices/{id}/prefs``.
    /// Provenance fields are minted via ``EnvelopeMinter`` so the
    /// backend gap detector sees a coherent ``session_id`` +
    /// monotonic ``sequence_id`` across iOS-originated commands.
    /// ``timezone`` is sourced from the device locale so the
    /// backend's quiet-hours interpreter at
    /// ``application/notify/routing.py`` evaluates the window in
    /// the user's wall-clock time, not UTC.
    @MainActor
    static func makeDeviceCommand(
        alertType: String,
        operatorPublicId: String? = nil,
        walletPublicId: String? = nil,
        enabled: Bool,
        minPriority: String,
        quietHoursStartMin: Int? = nil,
        quietHoursEndMin: Int? = nil,
        muteUntil: Date? = nil,
        timezone: String = TimeZone.current.identifier,
        provenance: EnvelopeMinter.Provenance? = nil
    ) -> UpdateDevicePrefCommand {
        let envelope = provenance ?? EnvelopeMinter.shared.next(.control)
        return UpdateDevicePrefCommand(
            type: "update_device_pref_command",
            sequenceId: envelope.sequenceId,
            publicId: envelope.publicId,
            timestamp: envelope.timestamp,
            sessionId: envelope.sessionId,
            topic: nil,
            payload: DeviceAlertPrefBody(
                alertType: alertType,
                operatorPublicId: operatorPublicId,
                walletPublicId: walletPublicId,
                enabled: enabled,
                minPriority: minPriority,
                quietHoursStartMin: quietHoursStartMin,
                quietHoursEndMin: quietHoursEndMin,
                muteUntil: muteUntil,
                timezone: timezone
            )
        )
    }
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        saveError = nil

        let scope = Self.resolveScopeTuple(
            isAlertTypeLocked: isAlertTypeLocked,
            lockedOperatorPublicId: lockedOperatorPublicId,
            lockedWalletPublicId: lockedWalletPublicId,
            scopeKind: scopeKind,
            selectedOperatorId: selectedOperatorId,
            selectedWalletId: selectedWalletId
        )
        let command = Self.makeDeviceCommand(
            alertType: alertType,
            operatorPublicId: scope.operatorPublicId,
            walletPublicId: scope.walletPublicId,
            enabled: enabled,
            minPriority: minPriority,
            quietHoursStartMin: quietHoursEnabled
                ? Self.minutesSinceMidnight(for: quietHoursStart) : nil,
            quietHoursEndMin: quietHoursEnabled
                ? Self.minutesSinceMidnight(for: quietHoursEnd) : nil,
            muteUntil: muteEnabled ? muteUntil : nil
        )
        do {
            let response = try await APIClient.shared.updateDevicePref(
                devicePublicId: devicePublicId,
                command: command
            )
            onSaved(response.payload)
            dismiss()
        } catch {
            logger.error("Failed to save device pref: \(error)")
            saveError = "Couldn't save preference. Try again."
        }
    }
}
