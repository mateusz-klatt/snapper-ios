import SwiftUI

/// Settings surface for the caller's server-scoped desks and optional
/// viewer-attachment capability.
struct DeskView: View {

    @State private var viewModel = DeskViewModel()

    var body: some View {
        Group {
            if !viewModel.hasLoaded || (viewModel.isLoading && viewModel.desks.isEmpty) {
                ProgressView(LocalizedStringKey("common.loading"))
            } else if DeskViewModel.shouldShowLoadError(
                deskCount: viewModel.desks.count,
                loadError: viewModel.loadError,
                isLoading: viewModel.isLoading
            ) {
                loadErrorView
            } else if viewModel.desks.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("desk.empty.title"),
                    systemImage: "person.2.slash",
                    description: Text(LocalizedStringKey("desk.empty.message"))
                )
                .accessibilityIdentifier("desk.empty")
            } else {
                deskForm
            }
        }
        .navigationTitle(LocalizedStringKey("desk.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private var loadErrorView: some View {
        ContentUnavailableView(
            LocalizedStringKey("common.error.loadFailed.title"),
            systemImage: "exclamationmark.triangle",
            description: Text(LocalizedStringKey("desk.load.error"))
        )
        .overlay(alignment: .bottom) {
            Button(LocalizedStringKey("common.retry")) {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    private var deskForm: some View {
        Form {
            Section(LocalizedStringKey("desk.section.accessible")) {
                ForEach(viewModel.desks) { desk in
                    AccessibleDeskRow(desk: desk)
                }
            }

            if viewModel.canManageMemberships {
                attachmentSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgBase)
        .refreshable {
            await viewModel.load()
        }
    }

    private var attachmentSection: some View {
        Section {
            Picker(
                LocalizedStringKey("desk.attach.desk.label"),
                selection: $viewModel.selectedDeskPublicId
            ) {
                ForEach(viewModel.desks) { desk in
                    Text(verbatim: desk.label)
                        .tag(Optional(desk.id))
                }
            }
            .disabled(viewModel.isAttaching)
            .accessibilityIdentifier("desk.attach.selector")

            TextField(
                LocalizedStringKey("desk.attach.username.placeholder"),
                text: $viewModel.viewerUsername
            )
            .textContentType(.username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .disabled(viewModel.isAttaching)
            .accessibilityIdentifier("desk.attach.username")

            if let validationErrorKey = viewModel.validationErrorKey {
                Label(
                    LocalizedStringKey(validationErrorKey),
                    systemImage: "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(Color.brandRed)
            }

            if viewModel.attachmentSucceeded {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        LocalizedStringKey("desk.attach.success.title"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(Color.brandGreen)
                    Text(LocalizedStringKey("desk.attach.success.message"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("desk.attach.success")
            }

            if let attachmentError = viewModel.attachmentError {
                if let detail = DeskViewModel.attachmentServerDetail(for: attachmentError) {
                    Label {
                        Text(verbatim: detail)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.brandRed)
                } else {
                    Label(
                        LocalizedStringKey("common.error.submissionFailed"),
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.brandRed)
                }
            }

            Button {
                Task { await viewModel.attachViewer() }
            } label: {
                HStack {
                    if viewModel.isAttaching {
                        ProgressView()
                    }
                    Text(LocalizedStringKey(
                        viewModel.isAttaching ? "common.loading" : "desk.attach.button"
                    ))
                }
            }
            .disabled(!viewModel.canAttemptAttachment)
            .accessibilityIdentifier("desk.attach.submit")
        } header: {
            Text(LocalizedStringKey("desk.attach.section"))
        } footer: {
            Text(LocalizedStringKey("desk.attach.help"))
        }
    }
}

private struct AccessibleDeskRow: View {
    let desk: AccessibleDesk

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(verbatim: desk.label)
                    .font(.body.weight(.medium))
                if desk.isPrimary {
                    Text(LocalizedStringKey("desk.primary.badge"))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer(minLength: 0)
            }
            if let description = desk.description {
                Text(verbatim: description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(LocalizedStringKey("desk.description.unavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("desk.row.\(desk.id)")
    }
}

struct DeskView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DeskView()
        }
    }
}
