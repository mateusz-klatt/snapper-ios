import SwiftUI

/// Notification preferences screen pushed from Settings → Notifications
/// → "Manage preferences".
///
/// Refactored to MVVM in v0.3.1 — data, parallel async load, and
/// optimistic-update flow live in `NotificationPrefsViewModel`.
/// The View binds sheet presentation via `@State`.
///
/// Two sections:
/// - User defaults: each of the five backend `alert_types` is
///   rendered as a row with an enabled toggle + min_priority picker.
///   Toggling fires `mutateDefault` immediately — optimistic UI
///   with revert-on-error so the user never sees a stale toggle
///   position after a network blip.
/// - Device overrides: list of active per-(alert_type, scope) rows
///   for the registered device.
struct NotificationPrefsView: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel = NotificationPrefsViewModel()
    @State private var sheetMode: EditDevicePrefView.Mode?

    var body: some View {
        Form {
            if let loadError = viewModel.loadError {
                Section {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(NotificationPrefsViewModel.alertTypes, id: \.self) { alertType in
                    AlertDefaultRow(
                        alertType: alertType,
                        existing: viewModel.defaults[alertType],
                        isInflight: viewModel.inflightAlertTypes.contains(alertType),
                        onChange: { enabled, minPriority in
                            await viewModel.mutateDefault(
                                alertType: alertType,
                                enabled: enabled,
                                minPriority: minPriority
                            )
                        }
                    )
                }
            } header: {
                Text("User defaults")
            } footer: {
                Text(
                    "Defaults apply when no per-device override matches an inbound alert."
                )
            }

            Section {
                if viewModel.devicePublicId == nil {
                    ContentUnavailableView(
                        "No device registered",
                        systemImage: "iphone.slash",
                        description: Text(
                            "Enable push notifications in Settings → Notifications to register this device."
                        )
                    )
                } else {
                    if viewModel.devicePrefs.isEmpty {
                        Text("No overrides yet — defaults apply to every alert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.devicePrefs, id: \.publicId) { pref in
                            Button {
                                sheetMode = .edit(existing: pref)
                            } label: {
                                DevicePrefRow(pref: pref)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        sheetMode = .create
                    } label: {
                        Label("Add override", systemImage: "plus.circle")
                    }
                    .disabled(viewModel.devicePublicId == nil)
                }
            } header: {
                Text("Device overrides")
            }
        }
        .navigationTitle("Notification preferences")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .sheet(item: Binding(
            get: { sheetMode.map { SheetIdentifier(mode: $0) } },
            set: { newValue in sheetMode = newValue?.mode }
        )) { identifier in
            if let id = viewModel.devicePublicId {
                EditDevicePrefView(
                    mode: identifier.mode,
                    devicePublicId: id,
                    onSaved: { saved in
                        viewModel.applySavedPref(saved)
                    }
                )
            }
        }
    }
}

private struct AlertDefaultRow: View {
    let alertType: String
    let existing: UserAlertDefaultInfo?
    let isInflight: Bool
    let onChange: (Bool, String) async -> Bool

    @State private var enabled: Bool
    @State private var minPriority: String
    /// Synchronous re-entry guard (preserved from pre-MVVM body).
    @State private var localInflight: Bool = false

    init(
        alertType: String,
        existing: UserAlertDefaultInfo?,
        isInflight: Bool,
        onChange: @escaping (Bool, String) async -> Bool
    ) {
        self.alertType = alertType
        self.existing = existing
        self.isInflight = isInflight
        self.onChange = onChange
        _enabled = State(initialValue: existing?.enabled ?? true)
        _minPriority = State(initialValue: existing?.minPriority ?? "medium")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NotificationPrefsViewModel.displayName(for: alertType))
                    .font(.body)
                Spacer()
                if isInflight || localInflight {
                    ProgressView().controlSize(.small)
                }
            }
            Toggle("Enabled", isOn: $enabled)
                .disabled(isInflight || localInflight)
                .onChange(of: enabled) { oldValue, newValue in
                    let baseline = existing?.enabled ?? true
                    guard newValue != baseline else { return }
                    let priorEnabled = oldValue
                    localInflight = true
                    Task {
                        let succeeded = await onChange(newValue, minPriority)
                        localInflight = false
                        if !succeeded {
                            enabled = priorEnabled
                        }
                    }
                }
            Picker("Minimum priority", selection: $minPriority) {
                ForEach(NotificationPrefsViewModel.priorityValues, id: \.self) { priority in
                    Text(NotificationPrefsViewModel.priorityDisplayName(for: priority)).tag(priority)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isInflight || localInflight)
            .onChange(of: minPriority) { oldValue, newValue in
                let baseline = existing?.minPriority ?? "medium"
                guard newValue != baseline else { return }
                let priorMinPriority = oldValue
                localInflight = true
                Task {
                    let succeeded = await onChange(enabled, newValue)
                    localInflight = false
                    if !succeeded {
                        minPriority = priorMinPriority
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onChange(of: existing?.publicId) { _, _ in
            if let existing {
                if enabled != existing.enabled { enabled = existing.enabled }
                if minPriority != existing.minPriority { minPriority = existing.minPriority }
            }
        }
    }
}

private struct DevicePrefRow: View {
    let pref: DeviceAlertPrefInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NotificationPrefsViewModel.displayName(for: pref.alertType))
                .font(.body)
            Text(NotificationPrefsViewModel.scopeLabel(for: pref))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(NotificationPrefsViewModel.summaryLabel(for: pref))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

private struct SheetIdentifier: Identifiable {
    let mode: EditDevicePrefView.Mode

    var id: String {
        switch mode {
        case .create:
            return "create"
        case .edit(let pref):
            return "edit-\(pref.publicId)"
        }
    }
}

struct NotificationPrefsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NotificationPrefsView()
                .environment(AppState.shared)
        }
    }
}
