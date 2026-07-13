import Foundation

/// Client-side authority ceilings mirrored from the shipped web account surface.
enum AccountTruthPolicy {
    static let clientAuthorityStalenessMilliseconds: TimeInterval = 15_000
    static let clientObservationMaxWindowMilliseconds: TimeInterval = 900_000

    static var clientAuthorityStalenessSeconds: TimeInterval {
        clientAuthorityStalenessMilliseconds / 1_000
    }

    static var clientObservationMaxWindowSeconds: TimeInterval {
        clientObservationMaxWindowMilliseconds / 1_000
    }
}

/// Fail-closed client truth derived from a server account-state row.
struct AccountTruth: Equatable, Sendable {
    let clientEffectiveStatus: String
    let isAuthoritative: Bool
    let authorityExpired: Bool
    let pollingStalled: Bool

    static func derive(
        state: PortfolioAccountState,
        now: Date,
        lastSuccessfulFetch: Date?
    ) -> AccountTruth {
        guard state.effectiveStatus == "observed" else {
            return AccountTruth(
                clientEffectiveStatus: state.effectiveStatus,
                isAuthoritative: false,
                authorityExpired: false,
                pollingStalled: false
            )
        }

        guard state.isAuthoritative else {
            return AccountTruth(
                clientEffectiveStatus: "stale",
                isAuthoritative: false,
                authorityExpired: false,
                pollingStalled: false
            )
        }

        let nowSeconds = now.timeIntervalSince1970
        let untilSeconds = state.authoritativeUntil?.timeIntervalSince1970 ?? .nan
        let balanceObservedSeconds = state.balanceObservedAt?.timeIntervalSince1970 ?? .nan
        let positionObservedSeconds = state.positionObservedAt?.timeIntervalSince1970 ?? .nan
        let balanceObservationBad = !balanceObservedSeconds.isFinite
            || balanceObservedSeconds > nowSeconds
            || nowSeconds >= balanceObservedSeconds + AccountTruthPolicy.clientObservationMaxWindowSeconds
        let positionObservationBad = state.positionStatus == "observed"
            && (!positionObservedSeconds.isFinite
                || positionObservedSeconds > nowSeconds
                || nowSeconds >= positionObservedSeconds + AccountTruthPolicy.clientObservationMaxWindowSeconds)
        let observationExpired = balanceObservationBad || positionObservationBad
        let authorityExpired = !nowSeconds.isFinite
            || !untilSeconds.isFinite
            || nowSeconds >= untilSeconds
            || observationExpired

        let lastFetchSeconds = lastSuccessfulFetch?.timeIntervalSince1970
        let pollingStalled = lastFetchSeconds == nil
            || !(lastFetchSeconds?.isFinite ?? false)
            || (lastFetchSeconds ?? 0) <= 0
            || (lastFetchSeconds ?? 0) > nowSeconds
            || nowSeconds - (lastFetchSeconds ?? 0) > AccountTruthPolicy.clientAuthorityStalenessSeconds

        guard !authorityExpired, !pollingStalled else {
            return AccountTruth(
                clientEffectiveStatus: "stale",
                isAuthoritative: false,
                authorityExpired: authorityExpired,
                pollingStalled: pollingStalled
            )
        }

        return AccountTruth(
            clientEffectiveStatus: "observed",
            isAuthoritative: true,
            authorityExpired: false,
            pollingStalled: false
        )
    }
}

/// Semantic badge tone for a client-effective account status.
enum AccountTruthTone: Equatable, Sendable {
    case authoritative
    case simulated
    case stale
    case corrupt
    case unsupported
    case unknown
}

/// Localization and tone mapping for an account truth badge.
struct AccountTruthStatusPresentation: Equatable, Sendable {
    let tone: AccountTruthTone
    let labelKey: String
    let tooltipKey: String

    static func forStatus(_ status: String) -> AccountTruthStatusPresentation {
        switch status {
        case "observed":
            return make(tone: .authoritative, suffix: "observed")
        case "simulated":
            return make(tone: .simulated, suffix: "simulated")
        case "stale":
            return make(tone: .stale, suffix: "stale")
        case "clock_error":
            return make(tone: .stale, suffix: "clockError")
        case "corrupt", "error":
            return make(tone: .corrupt, suffix: "corrupt")
        case "unsupported":
            return make(tone: .unsupported, suffix: "unsupported")
        case "not_applicable":
            return make(tone: .unsupported, suffix: "notApplicable")
        default:
            return make(tone: .unknown, suffix: "unknown")
        }
    }

    private static func make(tone: AccountTruthTone, suffix: String) -> AccountTruthStatusPresentation {
        return AccountTruthStatusPresentation(
            tone: tone,
            labelKey: "accounts.status.\(suffix)",
            tooltipKey: "accounts.statusTooltip.\(suffix)"
        )
    }
}
