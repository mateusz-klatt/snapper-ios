import Foundation
import os

enum AppConfig {

    private static let logger = AppLogger.make(category: "Config")

    private static let configuration = AppConfiguration.load()

    /// Resolve the active backend base URL for this app session.
    ///
    /// Layers, in priority order:
    /// 1. ``BackendURLStore.shared`` override — set by the user via
    ///    Login "Advanced" or Settings "Change backend…".
    /// 2. The bundled ``Configuration.plist`` value, patched at
    ///    Xcode Cloud build time by ``ci_post_clone.sh``.
    ///
    /// Returns the override's ``absoluteString`` so existing
    /// string-concatenation call sites in ``APIClient`` /
    /// ``WebSocketManager`` keep working unchanged.
    static var baseURL: String {
        return BackendURLStore.shared.currentEffectiveURL().absoluteString
    }

    static var apiPrefix: String {
        return configuration.apiPrefix
    }

    static var wsPath: String {
        return configuration.wsPath
    }

    enum URIScheme {
        static let http = "http://"
        static let https = "https://"
        static let ws = "ws://"
        static let wss = "wss://"
        static let httpsPrefix = "https"
    }

    enum ContentType {
        static let json = "application/json"
        static let formURLEncoded = "application/x-www-form-urlencoded"
    }

    enum HTTPHeader {
        static let contentType = "Content-Type"
        static let authorization = "Authorization"
        static let xCSRFToken = "X-CSRF-Token"
    }

    enum CookieName {
        static let csrfToken = "csrf_token"
    }

    static var apiBaseURL: String {
        return makeAPIBaseURL(baseURL: baseURL, apiPrefix: apiPrefix)
    }

    static var wsBaseURL: String {
        return makeWSBaseURL(baseURL: baseURL, apiPrefix: apiPrefix, wsPath: wsPath)
    }

    static func makeAPIBaseURL(baseURL: String, apiPrefix: String) -> String {
        return "\(baseURL)\(apiPrefix)"
    }

    static func makeWSBaseURL(baseURL: String, apiPrefix: String, wsPath: String) -> String {
        let wsProtocol = baseURL.hasPrefix(URIScheme.httpsPrefix) ? URIScheme.wss : URIScheme.ws
        let urlWithoutProtocol = baseURL
            .replacingOccurrences(of: URIScheme.http, with: "")
            .replacingOccurrences(of: URIScheme.https, with: "")
        return "\(wsProtocol)\(urlWithoutProtocol)\(apiPrefix)\(wsPath)"
    }

    enum Endpoints {
        static var login: String {
            return configuration.endpoints.login
        }

        static var logout: String {
            return configuration.endpoints.logout
        }

        static var refresh: String {
            return configuration.endpoints.refresh
        }

        static var me: String {
            return configuration.endpoints.me
        }

        static var orders: String {
            return configuration.endpoints.orders
        }

        static var positions: String {
            return configuration.endpoints.positions
        }

        static var accounts: String {
            return "\(configuration.endpoints.portfolio)/accounts"
        }

        /// Decomposed Net-P&L-since-activation series endpoint.
        /// Derived from the ``Portfolio`` base (mirrors ``accounts``)
        /// so no dedicated ``Configuration.plist`` key is required.
        /// Full wire path resolves to ``/api/portfolio/pnl/series``.
        static var pnlSeries: String {
            return "\(configuration.endpoints.portfolio)/pnl/series"
        }

        static var signals: String {
            return configuration.endpoints.signals
        }
        static var backtests: String {
            return configuration.endpoints.backtests
        }
        static var processSummary: String {
            return configuration.endpoints.processSummary
        }
        static var aiReviews: String {
            return configuration.endpoints.aiReviews
        }

        /// Delegate pending-review queue (``/ai-reviews/pending``),
        /// derived from the ``aiReviews`` root so no dedicated
        /// ``Configuration.plist`` key is required. Full wire path
        /// resolves to ``/api/ai-reviews/pending``.
        ///
        /// The sibling decision write
        /// (``/ai-reviews/{review_public_id}/decision``) is composed in
        /// ``APIClient`` instead, because the review id must be
        /// percent-encoded as a path segment — the same split used by
        /// ``processes`` and its per-name lifecycle routes.
        static var aiReviewsPending: String {
            return "\(configuration.endpoints.aiReviews)/pending"
        }
        static var strategies: String {
            return configuration.endpoints.strategies
        }
        static var users: String {
            return configuration.endpoints.users
        }
        static var delegates: String {
            return configuration.endpoints.delegates
        }

        static var executions: String {
            return configuration.endpoints.executions
        }

        static var status: String {
            return configuration.endpoints.status
        }

        static var health: String {
            return configuration.endpoints.health
        }

        static var devices: String {
            return configuration.endpoints.devices
        }

        static var alerts: String {
            return configuration.endpoints.alerts
        }

        static var system: String {
            return configuration.endpoints.system
        }

        static var wallets: String {
            return configuration.endpoints.wallets
        }

        static var alertDefaults: String {
            return configuration.endpoints.alertDefaults
        }

        static var operators: String {
            return configuration.endpoints.operators
        }

        static var executionPlans: String {
            return configuration.endpoints.executionPlans
        }

        static var trailingStops: String {
            return configuration.endpoints.trailingStops
        }

        /// Root of the processes REST family. Full wire paths resolve to
        /// ``/api/processes`` (per-name lifecycle mutations) and
        /// ``/api/processes/configured``.
        static var processes: String {
            return configuration.endpoints.processes
        }

        /// Configured-process listing endpoint
        /// (``/processes/configured``). Supplies the control-plane
        /// discriminators (``kind`` / ``managedRemotely`` / ``role`` /
        /// ``coordinator``) the summary feed lacks, joined by name in
        /// ``ProcessesViewModel``.
        static var processConfigured: String {
            return "\(processes)/configured"
        }
    }

    struct AppConfiguration {
        let baseURL: String
        let apiPrefix: String
        let wsPath: String
        let endpoints: EndpointConfiguration

        struct EndpointConfiguration {
            let login: String
            let logout: String
            let refresh: String
            let me: String
            let orders: String
            let portfolio: String
            let positions: String
            let signals: String
            let backtests: String
            let processSummary: String
            let processes: String
            let aiReviews: String
            let strategies: String
            let users: String
            let delegates: String
            let executions: String
            let status: String
            let health: String
            let devices: String
            let alerts: String
            let system: String
            let wallets: String
            let alertDefaults: String
            let operators: String
            let executionPlans: String
            let trailingStops: String
        }

        static func load(
            bundle: Bundle = .main,
            assertionHandler: (String) -> Void = { assertionFailure($0) }
        ) -> AppConfiguration {
            guard
                let url = bundle.url(forResource: "Configuration", withExtension: "plist"),
                let data = try? Data(contentsOf: url),
                let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                let dict = plist as? [String: Any]
            else {
                let message = "Failed to load Configuration.plist from bundle at \(bundle.bundleURL.path). " +
                    "Verify the file is included in target resources and contains valid plist data."
                AppConfig.logger.error("\(message, privacy: .public)")
                assertionHandler(message)
                return empty
            }

            return parse(dict, assertionHandler: assertionHandler)
        }

        static func parse(
            _ dict: [String: Any],
            assertOnMissingCriticalFields: Bool = true,
            assertionHandler: (String) -> Void = { assertionFailure($0) }
        ) -> AppConfiguration {
            let endpoints = dict["Endpoints"] as? [String: Any] ?? [:]
            let config = AppConfiguration(
                baseURL: dict["BaseURL"] as? String ?? "",
                apiPrefix: dict["APIPrefix"] as? String ?? "",
                wsPath: dict["WSPath"] as? String ?? "",
                endpoints: EndpointConfiguration(
                    login: endpoints["Login"] as? String ?? "",
                    logout: endpoints["Logout"] as? String ?? "",
                    refresh: endpoints["Refresh"] as? String ?? "",
                    me: endpoints["Me"] as? String ?? "",
                    orders: endpoints["Orders"] as? String ?? "",
                    portfolio: endpoints["Portfolio"] as? String ?? "",
                    positions: endpoints["Positions"] as? String ?? "",
                    signals: endpoints["Signals"] as? String ?? "",
                    backtests: endpoints["Backtests"] as? String ?? "",
                    processSummary: endpoints["ProcessSummary"] as? String ?? "",
                    processes: endpoints["Processes"] as? String ?? "",
                    aiReviews: endpoints["AiReviews"] as? String ?? "",
                    strategies: endpoints["Strategies"] as? String ?? "",
                    users: endpoints["Users"] as? String ?? "",
                    delegates: endpoints["Delegates"] as? String ?? "",
                    executions: endpoints["Executions"] as? String ?? "",
                    status: endpoints["Status"] as? String ?? "",
                    health: endpoints["Health"] as? String ?? "",
                    devices: endpoints["Devices"] as? String ?? "",
                    alerts: endpoints["Alerts"] as? String ?? "",
                    system: endpoints["System"] as? String ?? "",
                    wallets: endpoints["Wallets"] as? String ?? "",
                    alertDefaults: endpoints["AlertDefaults"] as? String ?? "",
                    operators: endpoints["Operators"] as? String ?? "",
                    executionPlans: endpoints["ExecutionPlans"] as? String ?? "",
                    trailingStops: endpoints["TrailingStops"] as? String ?? ""
                )
            )

            if config.baseURL.isEmpty || config.apiPrefix.isEmpty {
                let message = "Configuration.plist missing critical fields. BaseURL=\"\(config.baseURL)\" APIPrefix=\"\(config.apiPrefix)\". Check ios/Snapper/Config/Configuration.plist."
                AppConfig.logger.error("\(message, privacy: .public)")
                if assertOnMissingCriticalFields {
                    assertionHandler(message)
                }
            }

            return config
        }

        static var empty: AppConfiguration {
            return AppConfiguration(
                baseURL: "",
                apiPrefix: "",
                wsPath: "",
                endpoints: EndpointConfiguration(
                    login: "",
                    logout: "",
                    refresh: "",
                    me: "",
                    orders: "",
                    portfolio: "",
                    positions: "",
                    signals: "",
                    backtests: "",
                    processSummary: "",
                    processes: "",
                    aiReviews: "",
                    strategies: "",
                    users: "",
                    delegates: "",
                    executions: "",
                    status: "",
                    health: "",
                    devices: "",
                    alerts: "",
                    system: "",
                    wallets: "",
                    alertDefaults: "",
                    operators: "",
                    executionPlans: "",
                    trailingStops: ""
                )
            )
        }
    }
}
