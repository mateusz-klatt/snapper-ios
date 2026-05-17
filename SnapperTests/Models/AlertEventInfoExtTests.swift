import XCTest
@testable import Snapper

/// Tests for the Phase D ``AlertEventInfo`` localization helpers
/// (``displayTitle``/``displayBody``) — the in-app re-localization
/// hook for alert rows.
final class AlertEventInfoExtTests: XCTestCase {

    private func makeAlert(
        title: String = "Order filled",
        body: String = "BUY 100 BTCUSD @ $50000.00 filled on Kraken",
        titleLocKey: String? = nil,
        titleLocArgs: [String]? = nil,
        bodyLocKey: String? = nil,
        bodyLocArgs: [String]? = nil
    ) -> AlertEventInfo {
        AlertEventInfo(
            type: "alert_event_info",
            sequenceId: 1,
            publicId: "pid-1",
            timestamp: Date(),
            sessionId: "s",
            topic: nil,
            userPublicId: "u-1",
            operatorPublicId: nil,
            walletPublicId: nil,
            alertType: "order_fill_full",
            priority: "medium",
            isSafetyCritical: false,
            title: title,
            body: body,
            payload: nil,
            titleLocKey: titleLocKey,
            titleLocArgs: titleLocArgs,
            bodyLocKey: bodyLocKey,
            bodyLocArgs: bodyLocArgs,
            dedupKey: nil,
            threadKey: nil,
            sourceTopic: nil
        )
    }

    /// Phase D PL render: loc_key set + valid args + language=PL →
    /// helper resolves to the Polish catalog template, ignoring the
    /// server-rendered EN ``title``/``body`` columns.
    func testPolishDisplayTitleResolvesPolishCatalog() {
        let alert = makeAlert(
            title: "Order filled",
            body: "BUY 100 BTCUSD @ $50000.00 filled on Kraken",
            titleLocKey: "alerts.title.order_fill_full",
            titleLocArgs: [],
            bodyLocKey: "alerts.body.order_fill_full",
            bodyLocArgs: ["BUY", "100", "BTCUSD", "50000.00", "Kraken"]
        )

        XCTAssertEqual(alert.displayTitle(in: .pl), "Zlecenie zrealizowane")
        XCTAssertTrue(alert.displayBody(in: .pl).contains("zrealizowane na Kraken"))
    }

    /// Legacy row before Phase D (no loc_key) — helper short-circuits
    /// to the server-rendered EN columns regardless of which language
    /// the user picks, because the row never carried the metadata to
    /// re-render.
    func testLegacyRowWithoutLocKeyReturnsServerRenderedFields() {
        let alert = makeAlert(
            title: "Custom server-rendered title",
            body: "Custom server-rendered body",
            titleLocKey: nil,
            bodyLocKey: nil
        )

        XCTAssertEqual(alert.displayTitle(in: .pl), "Custom server-rendered title")
        XCTAssertEqual(alert.displayBody(in: .pl), "Custom server-rendered body")
    }

    /// Catalog miss (key present but not in the catalog) — helper
    /// detects the round-trip (rendered == key) and falls back to
    /// the server-rendered columns instead of shipping the literal
    /// key as alert text to the user.
    func testCatalogMissFallsBackToServerColumns() {
        let alert = makeAlert(
            title: "EN title",
            body: "EN body",
            titleLocKey: "alerts.title.does_not_exist",
            titleLocArgs: [],
            bodyLocKey: "alerts.body.does_not_exist",
            bodyLocArgs: []
        )

        XCTAssertEqual(alert.displayTitle(in: .pl), "EN title")
        XCTAssertEqual(alert.displayBody(in: .pl), "EN body")
    }

    /// ``loc_args`` nil (Pydantic ``default_factory=list`` may
    /// serialize as missing on legacy rows) — render defaults to
    /// empty args, which the catalog template tolerates only when
    /// it has no placeholders. For Phase C alert templates (all
    /// have placeholders), we still want a render attempt because
    /// ``LocaleStrings.render`` returns the unmodified template if
    /// args is empty — the user sees ``%@``-laced text. The helper
    /// here doesn't intercept this case; iOS keeps showing the
    /// server-rendered ``title``/``body`` only when ``loc_key`` is
    /// nil. For a defensive callsite the iOS surfaces also have
    /// the server-rendered fallback via the ``rendered == key``
    /// catalog-miss check; this test pins the args=nil behaviour.
    func testNilArgsFallsBackToEmptyArgsRender() {
        let alert = makeAlert(
            title: "EN title",
            titleLocKey: "alerts.title.order_fill_full",
            titleLocArgs: nil
        )

        XCTAssertEqual(alert.displayTitle(in: .en), "Order filled")
    }

    /// Empty ``titleLocKey`` is treated the same as ``nil`` — the
    /// guard ``!key.isEmpty`` prevents an empty string from reaching
    /// ``LocaleStrings.render`` (where it would attempt to load
    /// ``""`` from the catalog and return ``""``).
    func testEmptyLocKeyFallsBackToServerField() {
        let alert = makeAlert(
            title: "Server title",
            titleLocKey: "",
            titleLocArgs: []
        )

        XCTAssertEqual(alert.displayTitle(in: .pl), "Server title")
    }
}
