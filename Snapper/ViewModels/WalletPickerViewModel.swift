import Foundation
import Observation
import os

/// ViewModel for `WalletPicker` — the top-bar wallet selector
/// surfaced in the Home / Positions / Orders tabs.
///
/// Extracted in v0.3.1 alongside `NewOrderSheetViewModel`. The View
/// is now a thin Menu binder that reads `availableWallets` /
/// `selectedWalletPublicId` from the VM (passthrough into the
/// shared `AppState`) and drives `loadWallets()` on appearance.
/// Architecture rules in `docs/architecture-mvvm.md`.
///
/// AppState is init-injected so tests can run against an
/// ephemeral `UserDefaults` instance instead of mutating
/// `AppState.shared`. The VM mutates `appState.availableWallets`
/// directly on a successful fetch and falls through to the first
/// wallet if the user has not yet picked one (first-launch UX).
@MainActor
@Observable
final class WalletPickerViewModel {

    var loadError: APIError?

    private let api: APIClientProtocol
    private let appState: AppState

    private let logger = AppLogger.make(category: "WalletPickerViewModel")

    init(
        api: APIClientProtocol = APIClient.shared,
        appState: AppState = .shared
    ) {
        self.api = api
        self.appState = appState
    }
    var availableWallets: [WalletInfo] {
        return appState.availableWallets
    }

    var selectedWalletPublicId: String? {
        return appState.selectedWalletPublicId
    }
    var currentLabel: String {
        return Self.currentLabel(
            wallets: appState.availableWallets,
            selected: appState.selectedWalletPublicId,
            loadError: loadError
        )
    }

    var shouldShowLoadError: Bool {
        return Self.shouldShowLoadError(
            wallets: appState.availableWallets,
            loadError: loadError
        )
    }
    /// Fetch the user's accessible wallets via
    /// `APIClient.fetchWallets()`. Updates `appState.availableWallets`
    /// on success, falls through to the first wallet if no prior
    /// selection is cached, and stamps `loadError` on failure. The
    /// success path also clears any prior `loadError` so the menu
    /// recovers cleanly.
    func loadWallets() async {
        do {
            let wallets = try await api.fetchWallets()
            appState.availableWallets = wallets
            loadError = nil
            if appState.selectedWalletPublicId == nil, let first = wallets.first {
                appState.selectedWalletPublicId = first.publicId
            }
        } catch let error as APIError {
            logger.error(
                "Failed to fetch wallets: \(error.localizedDescription, privacy: .public)"
            )
            loadError = error
        } catch {
            logger.error(
                "Failed to fetch wallets: \(error.localizedDescription, privacy: .public)"
            )
            loadError = .invalidResponse
        }
    }

    /// Apply a wallet selection to the shared `AppState` so other
    /// tabs (Positions / Orders / Home) re-scope on the next render.
    func selectWallet(_ publicId: String) {
        appState.selectedWalletPublicId = publicId
    }
    /// Backward-compatible test contract.
    /// When the wallet list could not be loaded and the user has no
    /// prior selection cached, the label collapses to a short
    /// "Wallets unavailable" prompt so the toolbar capsule signals
    /// the failure mode instead of staying stuck on
    /// "Loading wallets…".
    static func currentLabel(
        wallets: [WalletInfo],
        selected: String?,
        loadError: APIError? = nil
    ) -> String {
        guard
            let id = selected,
            let wallet = wallets.first(where: { $0.publicId == id })
        else {
            if wallets.isEmpty, loadError != nil {
                return "Wallets unavailable"
            }
            return wallets.isEmpty ? "Loading wallets..." : "Select wallet"
        }
        return walletDisplayName(wallet)
    }

    /// Decision helper for the error-state branch — returns `true`
    /// when the menu should render the "couldn't load" prompt
    /// instead of an empty (no-options) wallet list. Once any
    /// wallets exist (cached or loaded mid-session) we keep the
    /// picker functional and let the next refresh clear the error.
    static func shouldShowLoadError(
        wallets: [WalletInfo],
        loadError: APIError?
    ) -> Bool {
        guard loadError != nil else { return false }
        return wallets.isEmpty
    }

    static func walletDisplayName(_ wallet: WalletInfo) -> String {
        return wallet.isPaper ? "\(wallet.label) (paper)" : wallet.label
    }
}
