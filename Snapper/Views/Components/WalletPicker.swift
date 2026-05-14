import SwiftUI

/// Compact wallet selector surfaced in the Home tab toolbar.
///
/// Refactored to MVVM in v0.3.1 — the View is a thin Menu binder
/// over `WalletPickerViewModel`. Async `loadWallets()`, error
/// state, and the AppState writes for selection / availability all
/// live in the VM.
///
/// Reads + writes `AppState.selectedWalletPublicId` via the VM so
/// other tabs (Positions, Orders) can filter to the wallet the user
/// picked here. Loads wallets on first appearance via
/// `APIClient.fetchWallets`; on success, falls through to the first
/// wallet when the user has not yet picked one (first-launch UX).
///
/// Paper wallets are tagged ``(paper)`` after the label so the user
/// cannot confuse a paper-mode session with a live one — backend
/// disambiguation is ``(label, is_paper)``-keyed and the UI mirrors
/// that exactly.
struct WalletPicker: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel: WalletPickerViewModel?

    var body: some View {
        Menu {
            if let viewModel {
                if viewModel.shouldShowLoadError, let loadError = viewModel.loadError {
                    Text("Couldn't load wallets")
                    Text(loadError.localizedDescription)
                    Button("Retry") {
                        Task { await viewModel.loadWallets() }
                    }
                } else {
                    ForEach(viewModel.availableWallets, id: \.publicId) { wallet in
                        Button {
                            viewModel.selectWallet(wallet.publicId)
                        } label: {
                            HStack {
                                Text(WalletPickerViewModel.walletDisplayName(wallet))
                                if wallet.publicId == viewModel.selectedWalletPublicId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: (viewModel?.shouldShowLoadError ?? false)
                    ? "exclamationmark.triangle"
                    : "wallet.bifold")
                Text(viewModel?.currentLabel ?? "Loading wallets...")
                Image(systemName: "chevron.down")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
        .task {
            if viewModel == nil {
                viewModel = WalletPickerViewModel(appState: appState)
            }
            await viewModel?.loadWallets()
        }
    }
}
