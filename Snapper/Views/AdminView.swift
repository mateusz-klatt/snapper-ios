import SwiftUI

/// Read-only platform-users roster from `GET /api/auth/users` — the
/// admin-only "User Management" surface. Pushed from ``HomeView`` (nested
/// in its ``NavigationStack``) rather than owning a tab, mirroring
/// ``StrategiesView``. Not wallet-scoped (see ``AdminViewModel``);
/// pull-to-refresh only. The web's create / edit / deactivate /
/// password-reset actions are out of scope for this first cut.
struct AdminView: View {

    @State private var viewModel: AdminViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.users.isEmpty {
                    ProgressView(LocalizedStringKey("common.loading"))
                } else if AdminViewModel.shouldShowLoadError(
                    count: viewModel.users.count,
                    loadError: viewModel.loadError,
                    isLoading: viewModel.isLoading
                ), let loadError = viewModel.loadError {
                    ContentUnavailableView(
                        LocalizedStringKey("common.error.loadFailed.title"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(verbatim: loadError.localizedDescription)
                    )
                    .overlay(alignment: .bottom) {
                        Button(LocalizedStringKey("common.retry")) {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                } else if viewModel.users.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("admin.empty.title"),
                        systemImage: "person.2",
                        description: Text(LocalizedStringKey("admin.empty.message"))
                    )
                } else {
                    List(viewModel.sortedUsers, id: \.publicId) { user in
                        UserRow(user: user)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.bgBase)
                    .refreshable { await viewModel.load() }
                }
            } else {
                ProgressView(LocalizedStringKey("common.loading"))
            }
        }
        .navigationTitle(LocalizedStringKey("admin.navTitle"))
        .task {
            if viewModel == nil {
                viewModel = AdminViewModel()
            }
            await viewModel?.load()
        }
    }
}

/// One user row: username + optional email, a role badge, an
/// active/inactive status badge, and the account creation date.
private struct UserRow: View {
    let user: UserProfile

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: user.username)
                        .font(.subheadline.weight(.medium))
                    if let email = user.email, !email.isEmpty {
                        Text(verbatim: email)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                statusBadge
            }
            HStack(spacing: 8) {
                roleBadge
                HStack(spacing: 4) {
                    Text(LocalizedStringKey("admin.field.created"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(verbatim: user.createdAt.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .omitted)
                            .locale(appState.locale.nativeLocale)
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var roleBadge: some View {
        let color = roleColor
        return Text(verbatim: user.role.displayName(in: appState.locale.catalogLanguage))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var roleColor: Color {
        switch user.role {
        case .admin: return Color.financialFalling(for: appState)
        case .operatorRole: return .accentColor
        case .aiDelegate: return Color.financialRising(for: appState)
        case .aiReviewer: return .orange
        case .aiResearcher: return .purple
        case .viewer: return .secondary
        }
    }

    private var statusBadge: some View {
        let active = user.isActive == true
        let color = active ? Color.financialRising(for: appState) : Color.secondary
        return Text(LocalizedStringKey(AdminViewModel.statusLabelKey(isActive: user.isActive)))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Tappable Home entry that pushes ``AdminView`` — mirrors
/// ``HealthEntryCard``.
struct AdminEntryCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("admin.navTitle"))
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(LocalizedStringKey("admin.entry.subtitle"))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundColor(.textSecondary)
        }
        .padding(14)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AdminView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AdminView()
                .environment(AppState.shared)
        }
    }
}
