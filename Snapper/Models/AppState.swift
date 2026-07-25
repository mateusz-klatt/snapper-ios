import Foundation
import Observation
import os

/// Per-user UX state shared across tabs.
///
/// Lives outside `WSState` because it does not track live WebSocket
/// frames — only the wallet the user picked from `WalletPicker`. The
/// selection persists across app launches via `UserDefaults` so the
/// Home tab opens on the same wallet the user last selected.
///
/// `availableWallets` is a cache populated by `WalletPicker` after
/// `APIClient.fetchWallets()` succeeds. Treat it as a read-through
/// snapshot, not a source of truth — the picker re-fetches on view
/// appear.
///
/// `UserDefaults` is injected for test isolation; production code
/// uses `AppState.shared` which falls through to `.standard`.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    private static let walletKey = "selected_wallet_public_id"
    private static let localeKey = "snapper-locale"
    private static let financialColorPreferenceKey = financialColorPreferenceStorageKey
    private let userDefaults: UserDefaults
    private let preferredLanguagesProvider: () -> [String]
    private let apiClientProvider: @Sendable @MainActor () -> APIClientProtocol
    private let logger = AppLogger.make(category: "AppState")
    /// Single-flight handle for the locale-persist task spawned by
    /// ``locale.didSet``. Reassigning ``locale`` cancels any
    /// in-flight task and replaces it with a fresh one so a stale
    /// network request cannot complete after a newer locale change
    /// and overwrite ``User.default_language`` with the previous
    /// value. Login-path syncs go through ``syncLocaleToBackend``
    /// directly (not through this slot) because the login caller
    /// needs to ``await`` the result before flipping auth state.
    private var pendingLocaleSyncTask: Task<Void, Never>?

    var selectedWalletPublicId: String? {
        didSet {
            if let id = selectedWalletPublicId {
                userDefaults.set(id, forKey: Self.walletKey)
            } else {
                userDefaults.removeObject(forKey: Self.walletKey)
            }
        }
    }

    var availableWallets: [WalletInfo] = []

    /// Monotonic invalidation tick, bumped whenever the AI-review inbox
    /// records an accepted decision.
    ///
    /// Surfaces holding a CACHED pending count — ``HomeView``'s
    /// entry-card badge — observe it to learn their snapshot went stale
    /// while the user was inside the inbox. It carries no data and is
    /// never persisted: it is an invalidation signal, not a channel, so
    /// the badge refetches its own authoritative count rather than
    /// trusting a number pushed from another screen.
    var aiReviewDecisionTick: Int = 0

    /// Operators the caller may act AS, populated by
    /// ``EditDevicePrefView`` on appearance via
    /// ``APIClient.fetchOperators``. Treated as a read-through
    /// cache — the editor refetches every time the sheet opens so
    /// stale catalogs do not narrow the scope picker.
    var availableOperators: [OperatorInfo] = []

    /// User-selected country code that drives the SwiftUI
    /// environment locale (``Text`` / ``LocalizedStringKey``
    /// resolution + date formatting) and the catalog-language
    /// fallback. Persisted to UserDefaults under ``"snapper-locale"``
    /// (matches web v3 localStorage key). Mutating this triggers
    /// the SwiftUI environment chain at the app root to re-resolve
    /// every ``Text(LocalizedStringKey(...))`` in the view tree.
    ///
    /// The ``didSet`` mirror to backend ``User.default_language``
    /// is latest-wins: every assignment cancels any prior in-flight
    /// task before scheduling its own. Without this, two rapid
    /// locale flips can race and the older request could complete
    /// after the newer one — leaving backend ``default_language``
    /// stale relative to the on-screen locale. Same-value
    /// assignments are dropped early so a no-op write does not
    /// cancel a legitimate in-flight task.
    ///
    /// Login drives a separate code path that calls
    /// ``syncLocaleToBackend(skipAuthCheck:authService:)`` directly
    /// before the auth-state flip so the first post-login fetch
    /// sees the persisted preference.
    var locale: AppLocale {
        didSet {
            guard oldValue != locale else { return }
            userDefaults.set(locale.rawValue, forKey: Self.localeKey)
            pendingLocaleSyncTask?.cancel()
            pendingLocaleSyncTask = Task { @MainActor [weak self] in
                await self?.syncLocaleToBackend(skipAuthCheck: false)
            }
        }
    }

    /// Per-user financial-direction color convention preference.
    ///
    /// Defaults to ``.auto`` (locale-derived) on first run. The
    /// resolver in [[FinancialColorPreference.swift]] maps the
    /// stored preference + the current ``locale`` to a concrete
    /// ``EffectiveFinancialColorConvention``; mutating either field
    /// triggers SwiftUI re-render of every view that uses the
    /// ``Color.financialRising(for:)`` / ``financialFalling(for:)``
    /// helpers.
    ///
    /// Persisted under the same UserDefaults key the web localStorage
    /// uses (cross-platform parity — see Phase E precedent for
    /// `snapper-financial-color-preference`).
    var financialColorPreference: FinancialColorPreference {
        didSet {
            userDefaults.set(financialColorPreference.rawValue, forKey: Self.financialColorPreferenceKey)
        }
    }

    /// Initialize app state. ``preferredLanguagesProvider`` is
    /// injected (rather than reading ``Locale.preferredLanguages``
    /// directly) so XCTest can pass deterministic literal arrays
    /// without process-wide ``setenv("AppleLanguages", ...)``
    /// mutations.
    ///
    /// ``apiClientProvider`` is a lazy closure (not a stored
    /// ``APIClientProtocol`` value) so the production default
    /// ``{ APIClient.shared }`` does not evaluate ``APIClient.shared``
    /// at ``AppState.shared`` init time. ``APIClient.shared`` is
    /// itself a ``@MainActor`` static that holds a reference to
    /// ``AuthService.shared``; resolving it eagerly during
    /// ``AppState.shared``'s init triggers a static-init cycle in
    /// production. The closure captures the symbol but defers
    /// evaluation until ``syncLocaleToBackend(...)`` is invoked,
    /// at which point both singletons are fully initialized.
    init(
        userDefaults: UserDefaults = .standard,
        preferredLanguagesProvider: @escaping () -> [String] = { Locale.preferredLanguages },
        apiClientProvider: @escaping @Sendable @MainActor () -> APIClientProtocol = { APIClient.shared }
    ) {
        self.userDefaults = userDefaults
        self.preferredLanguagesProvider = preferredLanguagesProvider
        self.apiClientProvider = apiClientProvider
        self.selectedWalletPublicId = userDefaults.string(forKey: Self.walletKey)
        self.locale = LocaleResolver.resolveInitialLocale(
            userDefaults: userDefaults,
            preferredLanguages: preferredLanguagesProvider(),
            localeKey: Self.localeKey
        )
        if let raw = userDefaults.string(forKey: Self.financialColorPreferenceKey),
           let parsed = FinancialColorPreference(rawValue: raw) {
            self.financialColorPreference = parsed
        } else {
            self.financialColorPreference = .auto
        }
    }

    /// Persist ``locale.catalogLanguage.rawValue`` to backend
    /// ``User.default_language`` so the description endpoint resolves
    /// strings in the user's preferred catalog language.
    ///
    /// Two entry points:
    /// - ``locale.didSet`` calls this with ``skipAuthCheck: false`` —
    ///   the helper no-ops when logged out (the next login will
    ///   persist whatever the current locale is at that moment).
    /// - ``AuthService.login`` success branch calls this with
    ///   ``skipAuthCheck: true`` BEFORE flipping ``isAuthenticated``,
    ///   so the first post-login fetch sees the persisted value
    ///   without a refetch round-trip.
    ///
    /// On success, posts ``.appStateLocaleDidPersist`` with
    /// ``object: self`` and ``userInfo["language"]`` carrying the
    /// language code that was actually persisted, so subscribers
    /// (e.g. ``MarketDataViewModel``) can filter by source instance
    /// and refresh state with the language they know was accepted.
    /// On failure, swallows the error after logging — the local
    /// ``UserDefaults`` persist already happened and the banner
    /// refreshes on the next locale change or relaunch.
    ///
    /// Cancellation: the helper captures ``locale.catalogLanguage.rawValue``
    /// at entry, awaits the backend call, then checks ``Task.isCancelled``
    /// before posting the notification. If a newer ``locale.didSet``
    /// fires while this call is in flight, the prior task is
    /// cancelled and its post-completion notification is suppressed
    /// so subscribers only see a notification corresponding to the
    /// freshest accepted language.
    func syncLocaleToBackend(
        skipAuthCheck: Bool,
        authService: AuthService = .shared
    ) async {
        if !skipAuthCheck && !authService.isAuthenticated {
            return
        }
        let intendedLanguage = locale.catalogLanguage.rawValue
        do {
            try await apiClientProvider().updateDefaultLanguage(intendedLanguage)
            if Task.isCancelled {
                return
            }
            NotificationCenter.default.post(
                name: .appStateLocaleDidPersist,
                object: self,
                userInfo: ["language": intendedLanguage]
            )
        } catch {
            logger.error("syncLocaleToBackend failed: \(String(describing: error), privacy: .public)")
        }
    }
}

extension Notification.Name {
    /// Posted by ``AppState.syncLocaleToBackend(...)`` after the
    /// backend successfully accepts the new ``default_language``.
    /// View models subscribe to refetch description-bearing
    /// endpoints so the rendered prose matches the just-persisted
    /// language without waiting for the user to re-navigate.
    static let appStateLocaleDidPersist = Notification.Name("appStateLocaleDidPersist")
}
