import Foundation
import Observation
import os

/// ViewModel for ``AiIntegrationView`` — the read-only list of AI
/// delegates from ``APIClientProtocol/fetchDelegates``
/// (`GET /api/ai-delegates`). An AI delegate is a service-account
/// identity that lets an external AI agent (e.g. Claude via MCP) trade on
/// the user's behalf under trading caps.
///
/// Mirrors ``AdminViewModel``/``StrategiesViewModel``: typed error
/// handling, pure ``static`` decision helpers. Not wallet-scoped:
/// ``DelegateRead`` carries no wallet and the endpoint is
/// permission-scoped server-side, so there is no filter and no
/// ``WalletPicker``. Read-only — the web's create ("mint" an MCP token) /
/// update-caps / revoke actions are out of scope for this first cut.
/// Pull-to-refresh only.
@MainActor
@Observable
final class AiIntegrationViewModel {

    var delegates: [DelegateRead] = []
    var isLoading: Bool = false
    var loadError: APIError?

    private let api: APIClientProtocol

    private let logger = AppLogger.make(category: "AiIntegrationViewModel")

    init(api: APIClientProtocol = APIClient.shared) {
        self.api = api
    }

    /// Label-sorted rows for a stable render order.
    var sortedDelegates: [DelegateRead] {
        return delegates.sorted { $0.label < $1.label }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            delegates = try await api.fetchDelegates()
            loadError = nil
        } catch let error as APIError {
            logger.error("Failed to fetch AI delegates: \(error.localizedDescription, privacy: .public)")
            loadError = error
        } catch {
            logger.error("Failed to fetch AI delegates: \(error.localizedDescription, privacy: .public)")
            loadError = .invalidResponse
        }
    }

    /// Surface the "couldn't load" variant only when there is nothing
    /// cached to show and a load has settled.
    static func shouldShowLoadError(
        count: Int,
        loadError: APIError?,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading else { return false }
        guard loadError != nil else { return false }
        return count == 0
    }

    /// Catalog key for a delegate's status — ``active`` when the
    /// delegate is live, ``revoked`` once deactivated.
    static func statusLabelKey(isActive: Bool) -> String {
        return isActive ? "aiIntegration.status.active" : "aiIntegration.status.revoked"
    }

    /// Render an integer cap, or the already-resolved ``defaultLabel``
    /// when the cap is unset (server default applies).
    static func capValueText(_ value: Int?, defaultLabel: String) -> String {
        guard let value else { return defaultLabel }
        return value.description
    }

    /// Render a USD notional cap in the given locale (whole dollars), or
    /// the already-resolved ``defaultLabel`` when the cap is unset.
    static func capCurrencyText(_ value: Double?, locale: AppLocale, defaultLabel: String) -> String {
        guard let value else { return defaultLabel }
        return value.formattedCurrency(in: locale, code: "USD", fractionDigits: 0)
    }
}
