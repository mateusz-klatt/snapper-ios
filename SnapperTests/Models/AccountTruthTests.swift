import XCTest
@testable import Snapper

final class AccountTruthTests: XCTestCase {

    private static let now = Date(timeIntervalSince1970: 1_752_408_000)

    private func makeState(
        effectiveStatus: String = "observed",
        isAuthoritative: Bool = true,
        positionStatus: String = "observed",
        balanceObservedAt: Date? = AccountTruthTests.now.addingTimeInterval(-60),
        positionObservedAt: Date? = AccountTruthTests.now.addingTimeInterval(-60),
        authoritativeUntil: Date? = AccountTruthTests.now.addingTimeInterval(300)
    ) -> PortfolioAccountState {
        return PortfolioAccountState(
            type: "portfolio_account_state",
            sequenceId: 1,
            publicId: "acct-1",
            timestamp: Self.now,
            sessionId: "session-1",
            topic: nil,
            walletPublicId: "wallet-1",
            exchange: "kraken",
            mode: "live",
            syncStatus: "observed",
            effectiveStatus: effectiveStatus,
            isAuthoritative: isAuthoritative,
            balanceStatus: "observed",
            positionStatus: positionStatus,
            valuationStatus: "native_only",
            balances: [],
            openPositions: [],
            balanceObservedAt: balanceObservedAt,
            positionObservedAt: positionObservedAt,
            authoritativeUntil: authoritativeUntil,
            currentAttemptObservationId: 1,
            balancePayloadSourceObservationId: 1,
            positionPayloadSourceObservationId: 1,
            error: nil,
            reconciliation: .fixture()
        )
    }

    func testPolicyConstantsMirrorWebMilliseconds() {
        XCTAssertEqual(AccountTruthPolicy.clientAuthorityStalenessMilliseconds, 15_000)
        XCTAssertEqual(AccountTruthPolicy.clientObservationMaxWindowMilliseconds, 900_000)
        XCTAssertEqual(AccountTruthPolicy.clientAuthorityStalenessSeconds, 15)
        XCTAssertEqual(AccountTruthPolicy.clientObservationMaxWindowSeconds, 900)
    }

    func testFreshObservedRowIsAuthoritative() {
        let truth = AccountTruth.derive(
            state: makeState(),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertEqual(truth.clientEffectiveStatus, "observed")
        XCTAssertTrue(truth.isAuthoritative)
        XCTAssertFalse(truth.authorityExpired)
        XCTAssertFalse(truth.pollingStalled)
    }

    func testNonObservedStatusesPassThroughWithoutAuthority() {
        for status in ["simulated", "stale", "clock_error", "corrupt", "unsupported", "forged"] {
            let truth = AccountTruth.derive(
                state: makeState(
                    effectiveStatus: status,
                    balanceObservedAt: nil,
                    positionObservedAt: nil,
                    authoritativeUntil: nil
                ),
                now: Date(timeIntervalSince1970: .nan),
                lastSuccessfulFetch: nil
            )

            XCTAssertEqual(truth.clientEffectiveStatus, status)
            XCTAssertFalse(truth.isAuthoritative)
            XCTAssertFalse(truth.authorityExpired)
            XCTAssertFalse(truth.pollingStalled)
        }
    }

    func testServerNonAuthoritativeObservedRowDemotesBeforeClockChecks() {
        let truth = AccountTruth.derive(
            state: makeState(
                isAuthoritative: false,
                balanceObservedAt: nil,
                positionObservedAt: nil,
                authoritativeUntil: nil
            ),
            now: Self.now,
            lastSuccessfulFetch: nil
        )

        XCTAssertEqual(truth.clientEffectiveStatus, "stale")
        XCTAssertFalse(truth.isAuthoritative)
        XCTAssertFalse(truth.authorityExpired)
        XCTAssertFalse(truth.pollingStalled)
    }

    func testAuthorityWindowElapsedAtBoundary() {
        let truth = AccountTruth.derive(
            state: makeState(authoritativeUntil: Self.now),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
        XCTAssertFalse(truth.isAuthoritative)
    }

    func testMissingAuthorityWindowDemotes() {
        let truth = AccountTruth.derive(
            state: makeState(authoritativeUntil: nil),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
    }

    func testNonFiniteAuthorityWindowDemotes() {
        let truth = AccountTruth.derive(
            state: makeState(authoritativeUntil: Date(timeIntervalSince1970: .nan)),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
    }

    func testNonFiniteNowDemotesAuthority() {
        let truth = AccountTruth.derive(
            state: makeState(),
            now: Date(timeIntervalSince1970: .nan),
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
        XCTAssertFalse(truth.pollingStalled)
    }

    func testMissingBalanceObservationDemotes() {
        let truth = AccountTruth.derive(
            state: makeState(balanceObservedAt: nil),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
    }

    func testNonFiniteBalanceObservationDemotes() {
        let truth = AccountTruth.derive(
            state: makeState(balanceObservedAt: Date(timeIntervalSince1970: .nan)),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
    }

    func testFutureBalanceObservationDemotes() {
        let truth = AccountTruth.derive(
            state: makeState(
                balanceObservedAt: Self.now.addingTimeInterval(1),
                authoritativeUntil: Date.distantFuture
            ),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
    }

    func testBalanceObservationAtMaxWindowBoundaryDemotes() {
        let truth = AccountTruth.derive(
            state: makeState(
                balanceObservedAt: Self.now.addingTimeInterval(-900),
                authoritativeUntil: Date.distantFuture
            ),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
    }

    func testOldPositionObservationDemotesEvenWithFreshBalance() {
        let truth = AccountTruth.derive(
            state: makeState(
                positionObservedAt: Self.now.addingTimeInterval(-901),
                authoritativeUntil: Date.distantFuture
            ),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
    }

    func testPositionObservationAtMaxWindowBoundaryDemotes() {
        let truth = AccountTruth.derive(
            state: makeState(
                positionObservedAt: Self.now.addingTimeInterval(-900),
                authoritativeUntil: Date.distantFuture
            ),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
    }

    func testFuturePositionObservationDemotes() {
        let truth = AccountTruth.derive(
            state: makeState(positionObservedAt: Self.now.addingTimeInterval(1)),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
    }

    func testObservedPositionWithMissingClockDemotes() {
        let truth = AccountTruth.derive(
            state: makeState(positionStatus: "observed", positionObservedAt: nil),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
        XCTAssertFalse(truth.isAuthoritative)
    }

    func testObservedPositionWithNonFiniteClockDemotes() {
        let truth = AccountTruth.derive(
            state: makeState(
                positionStatus: "observed",
                positionObservedAt: Date(timeIntervalSince1970: .nan)
            ),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertTrue(truth.authorityExpired)
    }

    func testNotApplicablePositionWithNullClockStaysAuthoritative() {
        let truth = AccountTruth.derive(
            state: makeState(positionStatus: "not_applicable", positionObservedAt: nil),
            now: Self.now,
            lastSuccessfulFetch: Self.now
        )

        XCTAssertEqual(truth.clientEffectiveStatus, "observed")
        XCTAssertTrue(truth.isAuthoritative)
    }

    func testMissingSuccessfulFetchStallsPolling() {
        let truth = AccountTruth.derive(
            state: makeState(),
            now: Self.now,
            lastSuccessfulFetch: nil
        )

        XCTAssertTrue(truth.pollingStalled)
        XCTAssertFalse(truth.isAuthoritative)
    }

    func testNonFiniteSuccessfulFetchStallsPolling() {
        let truth = AccountTruth.derive(
            state: makeState(),
            now: Self.now,
            lastSuccessfulFetch: Date(timeIntervalSince1970: .nan)
        )

        XCTAssertTrue(truth.pollingStalled)
    }

    func testNonPositiveSuccessfulFetchStallsPolling() {
        for epoch in [0.0, -1.0] {
            let truth = AccountTruth.derive(
                state: makeState(),
                now: Self.now,
                lastSuccessfulFetch: Date(timeIntervalSince1970: epoch)
            )

            XCTAssertTrue(truth.pollingStalled)
        }
    }

    func testPollingBeyondCeilingStalls() {
        let truth = AccountTruth.derive(
            state: makeState(),
            now: Self.now,
            lastSuccessfulFetch: Self.now.addingTimeInterval(-15.001)
        )

        XCTAssertTrue(truth.pollingStalled)
    }

    func testPollingAtCeilingRemainsFresh() {
        let truth = AccountTruth.derive(
            state: makeState(),
            now: Self.now,
            lastSuccessfulFetch: Self.now.addingTimeInterval(-15)
        )

        XCTAssertFalse(truth.pollingStalled)
        XCTAssertTrue(truth.isAuthoritative)
    }

    func testClockRollbackStallsPolling() {
        let truth = AccountTruth.derive(
            state: makeState(),
            now: Self.now,
            lastSuccessfulFetch: Self.now.addingTimeInterval(1)
        )

        XCTAssertTrue(truth.pollingStalled)
        XCTAssertFalse(truth.isAuthoritative)
    }

    func testStatusPresentationMapsEveryToneAndUnknownCautiously() {
        let expected: [(String, AccountTruthTone, String)] = [
            ("observed", .authoritative, "observed"),
            ("simulated", .simulated, "simulated"),
            ("stale", .stale, "stale"),
            ("clock_error", .stale, "clockError"),
            ("corrupt", .corrupt, "corrupt"),
            ("error", .corrupt, "corrupt"),
            ("unsupported", .unsupported, "unsupported"),
            ("not_applicable", .unsupported, "notApplicable"),
            ("forged", .unknown, "unknown"),
        ]

        for (status, tone, suffix) in expected {
            let presentation = AccountTruthStatusPresentation.forStatus(status)
            XCTAssertEqual(presentation.tone, tone)
            XCTAssertEqual(presentation.labelKey, "accounts.status.\(suffix)")
            XCTAssertEqual(presentation.tooltipKey, "accounts.statusTooltip.\(suffix)")
        }
    }
}
