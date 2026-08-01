import XCTest

/// Per-locale screenshot harness for the i18n audit (2026-05-15).
///
/// For each of 45 AppLocale country codes:
/// 1. Launch a fresh `Snapper.app` process with `-snapper-locale <code>`
///    + `-snapper.customBackendURL https://...trycloudflare.com` +
///    `-AppleLanguages` overrides.
/// 2. Log in as `admin` (role sees every tab).
/// 3. Screenshot Home, Positions, Orders, Alerts, Settings, plus the
///    LocaleSwitcher sheet opened from the top-right chip on Login.
/// 4. Attach each PNG with `XCTAttachment.lifetime = .keepAlways` so
///    we can extract them from the `.xcresult` bundle.
///
/// Backend tunnel must be live before this test runs (`cloudflared
/// tunnel --url http://localhost:8000`). The URL is read from the
/// `SNAPPER_UITEST_BACKEND_URL` env var at test build time via
/// processInfo.environment.
@MainActor
final class I18nScreenshotUITests: XCTestCase {

    /// Backend URL the harness drives the app against.
    ///
    /// In source this is intentionally an obvious-invalid sentinel.
    /// ``ios/scripts/screenshot-all-locales.sh`` rewrites this literal in
    /// place to point at the configured tunnel (from
    /// ``ios/.local-backend-url`` or the ``SNAPPER_UITEST_BACKEND_URL`` env
    /// var) before invoking ``xcodebuild test``, then restores the source
    /// on completion. That side-steps the simulator's habit of stripping
    /// host env vars from the test runner.
    ///
    /// Default-CI runs (without the script) hit ``.invalid`` and
    /// ``skipUnlessBackendConfigured`` short-circuits before any login
    /// attempt, so the harness stays inert.
    private var backendURL: String {
        return "https://snapper-uitest-no-backend.invalid"
    }

    private var deskUATDefaultPublicId: String {
        return "snapper-uitest-no-default-desk.invalid"
    }

    private var deskUATSecondaryPublicId: String {
        return "snapper-uitest-no-secondary-desk.invalid"
    }

    private var deskUATFixtureMarker: String {
        return "snapper-uitest-no-fixture-marker.invalid"
    }

    /// Skip when ``backendURL`` is still the sentinel — CI without the
    /// screenshot script would otherwise stall on 45 doomed login retries.
    private func skipUnlessBackendConfigured() throws {
        try XCTSkipUnless(
            !backendURL.contains(".invalid"),
            "No backend URL configured. Run ios/scripts/screenshot-all-locales.sh (which patches this file in place) or trigger .github/workflows/i18n-screenshots.yml with a live tunnel input."
        )
    }

    private let demoUsername = "admin"
    private let demoPassword = "AdminSnapper2026!"

    private struct LocaleSpec {
        let code: String
        let appleLanguageTag: String
    }

    private let locales: [LocaleSpec] = [
        .init(code: "ie", appleLanguageTag: "en-IE"),
        .init(code: "us", appleLanguageTag: "en-US"),
        .init(code: "pl", appleLanguageTag: "pl-PL"),
        .init(code: "de", appleLanguageTag: "de-DE"),
        .init(code: "fr", appleLanguageTag: "fr-FR"),
        .init(code: "es", appleLanguageTag: "es-ES"),
        .init(code: "it", appleLanguageTag: "it-IT"),
        .init(code: "nl", appleLanguageTag: "nl-NL"),
        .init(code: "br", appleLanguageTag: "pt-BR"),
        .init(code: "se", appleLanguageTag: "sv-SE"),
        .init(code: "no", appleLanguageTag: "nb-NO"),
        .init(code: "dk", appleLanguageTag: "da-DK"),
        .init(code: "fi", appleLanguageTag: "fi-FI"),
        .init(code: "is", appleLanguageTag: "is-IS"),
        .init(code: "gr", appleLanguageTag: "el-GR"),
        .init(code: "cn", appleLanguageTag: "zh-Hans-CN"),
        .init(code: "hk", appleLanguageTag: "zh-Hant-HK"),
        .init(code: "jp", appleLanguageTag: "ja-JP"),
        .init(code: "kr", appleLanguageTag: "ko-KR"),
        .init(code: "th", appleLanguageTag: "th-TH"),
        .init(code: "vn", appleLanguageTag: "vi-VN"),
        .init(code: "ph", appleLanguageTag: "fil-PH"),
        .init(code: "my", appleLanguageTag: "ms-MY"),
        .init(code: "id", appleLanguageTag: "id-ID"),
        .init(code: "mm", appleLanguageTag: "my-MM"),
        .init(code: "in", appleLanguageTag: "hi-IN"),
        .init(code: "bd", appleLanguageTag: "bn-BD"),
        .init(code: "ke", appleLanguageTag: "sw-KE"),
        .init(code: "ae", appleLanguageTag: "ar-AE"),
        .init(code: "il", appleLanguageTag: "he-IL"),
        .init(code: "cz", appleLanguageTag: "cs-CZ"),
        .init(code: "sk", appleLanguageTag: "sk-SK"),
        .init(code: "hu", appleLanguageTag: "hu-HU"),
        .init(code: "ro", appleLanguageTag: "ro-RO"),
        .init(code: "ua", appleLanguageTag: "uk-UA"),
        .init(code: "ru", appleLanguageTag: "ru-RU"),
        .init(code: "lt", appleLanguageTag: "lt-LT"),
        .init(code: "lv", appleLanguageTag: "lv-LV"),
        .init(code: "hr", appleLanguageTag: "hr-HR"),
        .init(code: "rs", appleLanguageTag: "sr-Latn-RS"),
        .init(code: "ba", appleLanguageTag: "bs-BA"),
        .init(code: "al", appleLanguageTag: "sq-AL"),
        .init(code: "tr", appleLanguageTag: "tr-TR"),
        .init(code: "ir", appleLanguageTag: "fa-IR"),
        .init(code: "am", appleLanguageTag: "hy-AM"),
    ]

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        addUIInterruptionMonitor(withDescription: "SystemAlerts") { alert in
            MainActor.assumeIsolated {
                for button in alert.buttons.allElementsBoundByIndex {
                    let label = button.label
                    let lower = label.lowercased()
                    if lower.contains("save") || lower.contains("احفظ") || lower.contains("שמור") {
                        continue
                    }
                    button.tap()
                    return true
                }
                return false
            }
        }
    }

    func testCaptureAllLocales() throws {
        try skipUnlessBackendConfigured()
        for spec in locales {
            captureLocale(spec)
        }
    }

    func testCaptureSmoke() throws {
        try skipUnlessBackendConfigured()
        captureLocale(LocaleSpec(code: "us", appleLanguageTag: "en-US"))
        captureLocale(LocaleSpec(code: "ae", appleLanguageTag: "ar-AE"))
    }

    func testCaptureRetryFailures() throws {
        try skipUnlessBackendConfigured()
        let retries: [LocaleSpec] = [
            .init(code: "ae", appleLanguageTag: "ar-AE"),
            .init(code: "il", appleLanguageTag: "he-IL"),
            .init(code: "ir", appleLanguageTag: "fa-IR"),
        ]
        for spec in retries {
            captureLocale(spec)
        }
    }

    /// Release UAT for the admin, operator, and viewer fixture sessions.
    ///
    /// The isolated fixture gives admin and operator the default desk, creates
    /// `deskviewer` without a membership, adds an instrument scope grant for
    /// the paper wallet, and creates one additional unscoped desk. Admin must
    /// see both desks and attach `deskviewer`. A fresh viewer session must then
    /// see exactly the recorded default desk. Operator sees only default and
    /// repeats the same attachment idempotently; another fresh viewer session
    /// must still see exactly that one desk. Viewer retains zero mutation
    /// affordances; admin also sees Users.
    ///
    /// The 3.1 sweep retains build 29's P&L, Processes, Signals, AI-review,
    /// and refreshable-empty-state checks while extending them to operator
    /// and the Desk surface.
    func testCaptureViewerPermissionsUAT() throws {
        try skipUnlessBackendConfigured()
        guard !deskUATDefaultPublicId.contains(".invalid"),
              !deskUATSecondaryPublicId.contains(".invalid"),
              !deskUATFixtureMarker.contains(".invalid") else {
            XCTFail("viewer-uat requires a validated .desk-uat-fixture.json record")
            return
        }
        guard verifyUnattachedViewerBeforeAttach(username: "deskviewer") else { return }
        guard capturePermissionUAT(
            role: "admin",
            username: "admin",
            expectedDeskLabels: ["default", "ios-uat-secondary"],
            expectedDeskPublicIds: [deskUATDefaultPublicId, deskUATSecondaryPublicId],
            expectedFixtureMarker: deskUATFixtureMarker,
            deskAttachmentExpectation: .attachViewer(
                targetPublicId: deskUATDefaultPublicId,
                evidence: "admin initial attachment"
            ),
            homeSurfaces: [
                ("Market data", "market-data", .none),
                ("System Health", "health", .none),
                ("Backtests", "backtests", .none),
                ("Processes", "processes", .processLifecycleControls),
                ("AI Reviews", "ai-reviews", .aiReviewDelegateSegment),
                ("Strategies", "strategies", .none),
                ("Users", "users", .none),
                ("AI Delegates", "ai-delegates", .none),
            ],
            forbiddenHomeSurfaces: []
        ) else { return }
        guard verifyViewerDeskMembership(
            username: "deskviewer",
            phase: "after-admin-attach"
        ) else { return }
        guard capturePermissionUAT(
            role: "operator",
            username: "operator",
            expectedDeskLabels: ["default"],
            expectedDeskPublicIds: [deskUATDefaultPublicId],
            expectedFixtureMarker: nil,
            deskAttachmentExpectation: .attachViewer(
                targetPublicId: deskUATDefaultPublicId,
                evidence: "operator idempotent repeat"
            ),
            homeSurfaces: [
                ("Market data", "market-data", .none),
                ("System Health", "health", .none),
                ("Backtests", "backtests", .none),
                ("Processes", "processes", .processLifecycleControls),
                ("AI Reviews", "ai-reviews", .aiReviewDelegateSegment),
                ("Strategies", "strategies", .none),
                ("AI Delegates", "ai-delegates", .none),
            ],
            forbiddenHomeSurfaces: ["Users"]
        ) else { return }
        guard verifyViewerDeskMembership(
            username: "deskviewer",
            phase: "after-operator-repeat"
        ) else { return }
        guard capturePermissionUAT(
            role: "viewer",
            username: "deskviewer",
            expectedDeskLabels: ["default"],
            expectedDeskPublicIds: [deskUATDefaultPublicId],
            expectedFixtureMarker: nil,
            deskAttachmentExpectation: .hidden,
            homeSurfaces: [
                ("Market data", "market-data", .none),
                ("System Health", "health", .none),
                ("Backtests", "backtests", .none),
                ("Processes", "processes", .processLifecycleControls),
                ("AI Reviews", "ai-reviews", .aiReviewDelegateSegment),
                ("Strategies", "strategies", .none),
                ("AI Delegates", "ai-delegates", .none),
            ],
            forbiddenHomeSurfaces: ["Users"]
        ) else { return }
    }

    /// AppStore marketing showcase: one carefully-chosen screen per
    /// locale that highlights a single i18n capability of the v2
    /// release. The output PNGs feed the 8 ASC screenshot slots
    /// (one image per slot, English-locale gallery — Apple shows
    /// the same gallery across all markets).
    ///
    /// Slot mapping:
    /// 1. Polish login — picker chip showing "🇵🇱 Polska" autonym
    /// 2. EN with locale popover open — 15×3 grid with every
    ///    autonym visible (Deutsch / Français / 中国 / الإمارات / ישראל / Éire ...)
    /// 3. Arabic home — RTL layout + Arabic text + Western digits
    ///    on the trading surfaces
    /// 4. Simplified Chinese home — red-rising / green-falling candle
    ///    convention auto-derived from locale
    /// 5. French positions — French UI strings
    /// 6. German orders — German UI strings
    /// 7. Japanese alerts — Japanese UI strings
    /// 8. Spanish settings — chip "🇪🇸 España" + financial-color
    ///    preference picker
    func testCaptureMarketingShowcase() throws {
        try skipUnlessBackendConfigured()
        captureShowcaseLoginWithPicker(
            spec: .init(code: "pl", appleLanguageTag: "pl-PL"),
            slot: "01-login-pl"
        )
        captureShowcaseLocaleSwitcherPopover(
            spec: .init(code: "us", appleLanguageTag: "en-US"),
            slot: "02-locale-switcher-en"
        )
        captureShowcasePostLogin(
            spec: .init(code: "ae", appleLanguageTag: "ar-AE"),
            slot: "03-home-ar-rtl",
            tabIndex: nil
        )
        captureShowcasePostLogin(
            spec: .init(code: "cn", appleLanguageTag: "zh-Hans-CN"),
            slot: "04-home-cn-redrising",
            tabIndex: nil,
            forceRisingRed: true
        )
        captureShowcasePostLogin(
            spec: .init(code: "fr", appleLanguageTag: "fr-FR"),
            slot: "05-positions-fr",
            tabIndex: 1
        )
        captureShowcasePostLogin(
            spec: .init(code: "de", appleLanguageTag: "de-DE"),
            slot: "06-orders-de",
            tabIndex: 2
        )
        captureShowcasePostLogin(
            spec: .init(code: "jp", appleLanguageTag: "ja-JP"),
            slot: "07-alerts-jp",
            tabIndex: 3
        )
        captureShowcasePostLogin(
            spec: .init(code: "es", appleLanguageTag: "es-ES"),
            slot: "08-settings-es",
            tabIndex: 4
        )
    }

    /// Visual regression test for ``CandlestickChartView`` after
    /// the v2.0.2 SwiftUI-primitive rewrite. Captures three
    /// screenshots into xcresult, one per scenario:
    ///
    /// - ``locale-us__chart-verify-rising-green.png``:
    ///   ``locale=us``, no financial-color-preference override.
    ///   Resolver yields ``.risingGreen`` (Western default).
    ///   Expected visual: rising candles GREEN, falling RED;
    ///   Y-axis labels on TRAILING edge.
    /// - ``locale-cn__chart-verify-rising-red-auto.png``:
    ///   ``locale=cn``, no financial-color-preference override.
    ///   Resolver yields ``.risingRed`` for East-Asian locales.
    ///   Expected visual: rising candles RED, falling GREEN;
    ///   Y-axis labels on TRAILING edge. **This is the path
    ///   broken in v2.0.1** — the rewrite must show red-rising
    ///   here. Critically, no ``forceRisingRed=true`` shortcut
    ///   is used; the live resolver must produce the result.
    /// - ``locale-ae__chart-verify-rtl-axis.png``:
    ///   ``locale=ae``, no financial-color-preference override.
    ///   Expected visual: Y-axis labels on LEADING edge (RTL).
    ///   Colors irrelevant for this slot (Western convention
    ///   like US).
    ///
    /// Navigation uses ``-snapper.devStartOnMarket YES`` so the
    /// DEBUG auto-navigate hook in ``HomeView`` pushes
    /// ``MarketDataView`` straight after login, bypassing manual
    /// tab/Home taps.
    ///
    /// See plan
    /// [[plan_2026_05_24_ios_v202_candlestick_primitive_rewrite]]
    /// §Tests for the acceptance criteria.
    func testCaptureChartColorVerification() throws {
        try skipUnlessBackendConfigured()
        let cases: [(LocaleSpec, String)] = [
            (.init(code: "us", appleLanguageTag: "en-US"), "chart-verify-rising-green"),
            (.init(code: "cn", appleLanguageTag: "zh-Hans-CN"), "chart-verify-rising-red-auto"),
            (.init(code: "ae", appleLanguageTag: "ar-AE"), "chart-verify-rtl-axis"),
        ]
        for (spec, slot) in cases {
            XCTContext.runActivity(named: "\(spec.code)/\(slot)") { _ in
                let app = launchApp(
                    spec: spec,
                    resetSession: true,
                    forceRisingRed: false,
                    devStartOnMarket: true
                )
                guard performLogin(in: app) else {
                    attach(code: spec.code, screen: "\(slot)-login-failed")
                    XCTFail("\(spec.code)/\(slot) did not reach the post-login UI")
                    app.terminate()
                    return
                }
                dismissSavePasswordDialog(app: app)
                sleep(4)
                attach(code: spec.code, screen: slot)
                app.terminate()
            }
        }
    }

    /// Capture the Login screen with the locale picker chip visible.
    /// Does NOT log in — the goal is to show the chip + autonym
    /// before the first interaction. Output filename uses ``slot``
    /// so the gallery can be ordered by ASC slot index without
    /// renaming.
    ///
    /// Passes ``-snapper.resetSessionState YES`` so the DEBUG hook in
    /// ``AppDelegate.resetSessionStateIfRequested`` clears any
    /// persisted auth cookies before the SwiftUI root mounts.
    /// Without this the simulator's prior login session would
    /// auto-flip ``isAuthenticated = true`` on launch and the
    /// harness would screenshot ``MainTabView`` instead of
    /// ``LoginView``.
    private func captureShowcaseLoginWithPicker(spec: LocaleSpec, slot: String) {
        XCTContext.runActivity(named: "showcase-\(slot)") { _ in
            let app = launchApp(spec: spec, resetSession: true)
            sleep(4)
            attach(code: spec.code, screen: slot)
            app.terminate()
        }
    }

    /// Capture the Login screen with the locale picker popover open
    /// so the 15×3 grid of autonyms is visible. Resets the session
    /// (so the trigger is on the LoginView header), then taps the
    /// chip via its stable accessibility identifier rather than
    /// fragile screen coordinates.
    private func captureShowcaseLocaleSwitcherPopover(spec: LocaleSpec, slot: String) {
        XCTContext.runActivity(named: "showcase-\(slot)") { _ in
            let app = launchApp(spec: spec, resetSession: true)
            sleep(4)
            let trigger = app.buttons["locale.switcher.trigger"]
            if trigger.waitForExistence(timeout: 5) {
                trigger.tap()
            } else {
                let chevronCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.08))
                chevronCoord.tap()
            }
            sleep(2)
            attach(code: spec.code, screen: slot)
            app.terminate()
        }
    }

    /// Log in and optionally navigate to a specific tab before
    /// taking the screenshot. ``tabIndex == nil`` keeps the user
    /// on Home (which auto-pushes the Market Data screen on first
    /// appear for users with a single configured pair).
    /// ``forceRisingRed`` explicitly forces the red-rising candle
    /// convention via launchArg — used for the CN showcase slot so
    /// the screenshot proves the East-Asian palette regardless of
    /// any locale-auto-resolver edge case in the harness.
    private func captureShowcasePostLogin(
        spec: LocaleSpec,
        slot: String,
        tabIndex: Int?,
        forceRisingRed: Bool = false
    ) {
        XCTContext.runActivity(named: "showcase-\(slot)") { _ in
            let app = launchApp(spec: spec, forceRisingRed: forceRisingRed)
            guard performLogin(in: app) else {
                attach(code: spec.code, screen: "\(slot)-login-failed")
                XCTFail("showcase \(slot) did not reach the post-login UI")
                app.terminate()
                return
            }
            dismissSavePasswordDialog(app: app)
            sleep(4)
            if let index = tabIndex {
                let tabBar = app.tabBars.firstMatch
                if tabBar.exists, tabBar.buttons.count > index {
                    tabBar.buttons.element(boundBy: index).tap()
                } else {
                    let normalized = CGVector(dx: 0.1 + 0.2 * CGFloat(index), dy: 0.96)
                    app.coordinate(withNormalizedOffset: normalized).tap()
                }
                sleep(3)
            }
            attach(code: spec.code, screen: slot)
            app.terminate()
        }
    }

    /// UUID of the paper wallet seeded by
    /// ``scripts/seed_demo.py`` — pinned so the showcase test
    /// renders against the wallet that has the demo positions /
    /// orders / alerts rather than the main wallet which is empty
    /// by default. Apple reviewer screenshots are taken against
    /// this wallet via the ``selected_wallet_public_id``
    /// UserDefault launch override.
    private static let demoPaperWalletPublicId = "019e5384-75a3-77a0-bd87-7a820e21475c"

    /// Build + launch the app for ``spec`` with the AppLanguages /
    /// AppleLocale overrides that the screenshot harness relies on.
    /// Pass ``resetSession: true`` to also wipe HTTP cookies +
    /// wallet defaults before the SwiftUI root mounts.
    /// Pass ``forceRisingRed: true`` to seed the
    /// ``snapper-financial-color-preference`` UserDefault with
    /// ``rising-red`` so the chart renders the East-Asian palette
    /// regardless of locale-resolver behavior.
    private func launchApp(
        spec: LocaleSpec,
        resetSession: Bool = false,
        forceRisingRed: Bool = false,
        devStartOnMarket: Bool = false,
        useDemoWallet: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-snapper-locale", spec.code,
            "-snapper.customBackendURL", backendURL,
            "-AppleLanguages", "(\(spec.appleLanguageTag))",
            "-AppleLocale", spec.appleLanguageTag,
        ]
        if useDemoWallet {
            args += ["-selected_wallet_public_id", Self.demoPaperWalletPublicId]
        }
        if resetSession {
            args += ["-snapper.resetSessionState", "YES"]
        }
        if forceRisingRed {
            args += ["-snapper-financial-color-preference", "rising-red"]
        }
        if devStartOnMarket {
            args += ["-snapper.devStartOnMarket", "YES"]
        }
        app.launchArguments = args
        app.launch()
        return app
    }

    private func captureLocale(_ spec: LocaleSpec) {
        XCTContext.runActivity(named: "locale-\(spec.code)") { _ in
            let app = XCUIApplication()
            app.launchArguments = [
                "-snapper-locale", spec.code,
                "-snapper.customBackendURL", backendURL,
                "-AppleLanguages", "(\(spec.appleLanguageTag))",
                "-AppleLocale", spec.appleLanguageTag,
            ]
            app.launch()

            attach(code: spec.code, screen: "01-login")

            guard performLogin(in: app) else {
                attach(code: spec.code, screen: "02-login-failed")
                XCTFail("\(spec.code) did not reach the post-login UI")
                app.terminate()
                return
            }

            dismissSavePasswordDialog(app: app)
            sleep(3)
            attach(code: spec.code, screen: "03-home")

            captureTabSequence(app: app, code: spec.code)

            app.terminate()
        }
    }

    private func performLogin(
        in app: XCUIApplication,
        usernameValue: String? = nil,
        passwordValue: String? = nil
    ) -> Bool {
        // Cached session may auto-log-us-in. If no login text field appears
        // within a short window, assume we're already logged in.
        let username = app.textFields["login.username"]
        if !username.waitForExistence(timeout: 5) {
            return app.tabBars.firstMatch.waitForExistence(timeout: 20)
        }
        // Race guard (id-ID and other cached-session locales): the
        // auto-login can complete between `waitForExistence` and `tap`,
        // tearing down the login form. Re-check `.exists` right before
        // each interaction so we don't crash trying to tap an element
        // that's already gone.
        if !username.exists {
            return app.tabBars.firstMatch.waitForExistence(timeout: 20)
        }
        username.tap()
        username.typeText(usernameValue ?? demoUsername)

        let password = app.secureTextFields["login.password"]
        if !password.waitForExistence(timeout: 5) { return false }
        if !password.exists {
            return app.tabBars.firstMatch.waitForExistence(timeout: 20)
        }
        password.tap()
        password.typeText(passwordValue ?? demoPassword)

        let signInButton = app.buttons["login.signIn"]
        if !signInButton.waitForExistence(timeout: 5) { return false }
        if !signInButton.exists {
            return app.tabBars.firstMatch.waitForExistence(timeout: 20)
        }
        signInButton.tap()

        return app.tabBars.firstMatch.waitForExistence(timeout: 20)
    }

    /// Extra release-29 assertion run while one Home destination is open,
    /// after its screenshot and before the harness navigates back. Keeping
    /// it on the surface descriptor means the widened checks reuse the
    /// existing single navigation pass instead of re-entering each screen.
    private enum UatSurfaceInspection {
        case none
        case processLifecycleControls
        case aiReviewDelegateSegment
    }

    /// Expected membership-control behavior for one named fixture session.
    /// The UI sweep proves these concrete sessions; unit tests independently
    /// prove that production visibility is derived from effective permissions.
    private enum DeskAttachmentExpectation {
        case hidden
        case attachViewer(targetPublicId: String, evidence: String)
    }

    private func capturePermissionUAT(
        role: String,
        username: String,
        expectedDeskLabels: [String],
        expectedDeskPublicIds: [String],
        expectedFixtureMarker: String?,
        deskAttachmentExpectation: DeskAttachmentExpectation,
        homeSurfaces: [(title: String, slug: String, inspection: UatSurfaceInspection)],
        forbiddenHomeSurfaces: [String]
    ) -> Bool {
        var deskGatePassed = false
        XCTContext.runActivity(named: "permission-uat-\(role)") { _ in
            let app = launchApp(
                spec: LocaleSpec(code: "us", appleLanguageTag: "en-US"),
                resetSession: true,
                useDemoWallet: false
            )
            guard performLogin(
                in: app,
                usernameValue: username,
                passwordValue: "change-me-after-first-login"
            ) else {
                attach(code: "us", screen: "uat-\(role)-login-failed")
                XCTFail("\(role) did not reach the post-login UI")
                app.terminate()
                return
            }
            dismissSavePasswordDialog(app: app)
            selectRootTab(app: app, title: "Home")
            XCTAssertTrue(
                app.navigationBars["Home"].waitForExistence(timeout: 20),
                "\(role) did not reach Home after login"
            )
            selectWallet(app: app, role: role, displayName: "paper (paper)")
            attach(code: "us", screen: "uat-\(role)-01-home")

            let homeScroll = app.scrollViews.firstMatch
            for _ in 0..<4 where homeScroll.exists {
                homeScroll.swipeUp()
            }
            attach(code: "us", screen: "uat-\(role)-02-home-tools")

            for forbiddenTitle in forbiddenHomeSurfaces {
                XCTAssertFalse(
                    app.staticTexts[forbiddenTitle].exists,
                    "\(role) must not see the \(forbiddenTitle) Home card"
                )
            }

            captureRootTab(
                app: app,
                role: role,
                tabTitle: "Positions",
                navigationTitle: "Positions",
                screen: "positions"
            )
            verifyPositionMutationPath(
                app: app,
                role: role,
                shouldExposeActions: role != "viewer"
            )
            capturePnlTimelineSegment(app: app, role: role)

            captureRootTab(
                app: app,
                role: role,
                tabTitle: "Orders",
                navigationTitle: "Orders",
                screen: "orders"
            )
            verifyOrderMutationPath(
                app: app,
                role: role,
                shouldExposeActions: role != "viewer"
            )

            for (index, surface) in homeSurfaces.enumerated() {
                captureHomeSurface(
                    app: app,
                    role: role,
                    title: surface.title,
                    screen: String(
                        format: "uat-%@-%02d-%@",
                        role,
                        index + 3,
                        surface.slug
                    ),
                    inspection: surface.inspection
                )
            }

            captureRootTab(
                app: app,
                role: role,
                tabTitle: "Alerts",
                navigationTitle: "Alerts",
                screen: "alerts"
            )
            captureRootTab(
                app: app,
                role: role,
                tabTitle: "Accounts",
                navigationTitle: "Venue Accounts",
                screen: "accounts"
            )
            captureRefreshableEmptyState(app: app, role: role)
            captureRootTab(
                app: app,
                role: role,
                tabTitle: "Signals",
                navigationTitle: "Signals",
                screen: "signals"
            )
            captureSignalsToolbar(app: app, role: role)
            captureRootTab(
                app: app,
                role: role,
                tabTitle: "Settings",
                navigationTitle: "Settings",
                screen: "settings"
            )
            deskGatePassed = captureDeskSurface(
                app: app,
                role: role,
                expectedDeskLabels: expectedDeskLabels,
                expectedDeskPublicIds: expectedDeskPublicIds,
                expectedFixtureMarker: expectedFixtureMarker,
                attachmentExpectation: deskAttachmentExpectation
            )

            app.terminate()
        }
        return deskGatePassed
    }

    private func verifyPositionMutationPath(
        app: XCUIApplication,
        role: String,
        shouldExposeActions: Bool
    ) {
        let positionRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "positions.row.")
        ).firstMatch
        XCTAssertTrue(
            positionRow.waitForExistence(timeout: 15),
            "\(role) did not render a seeded position row"
        )
        guard positionRow.exists else { return }

        positionRow.tap()

        let actionLabels = [
            "Close position",
            "Reduce position",
            "Attach SL / TP",
            "Attach trailing stop",
        ]
        if shouldExposeActions {
            for label in actionLabels {
                XCTAssertTrue(
                    app.buttons[label].waitForExistence(timeout: 5),
                    "\(role) did not expose the \(label) position action"
                )
            }
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
            } else {
                app.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.08, dy: 0.18)
                ).tap()
            }
            XCTAssertFalse(
                app.buttons[actionLabels[0]].waitForExistence(timeout: 5),
                "\(role) position action dialog could not be dismissed"
            )
        } else {
            for label in actionLabels {
                XCTAssertFalse(
                    app.buttons[label].waitForExistence(timeout: 2),
                    "\(role) must not expose the \(label) position action"
                )
            }
        }
    }

    private func verifyOrderMutationPath(
        app: XCUIApplication,
        role: String,
        shouldExposeActions: Bool
    ) {
        let newOrderButton = app.buttons["New order"]
        if shouldExposeActions {
            XCTAssertTrue(
                newOrderButton.waitForExistence(timeout: 5),
                "\(role) did not expose the New order action"
            )
        } else {
            XCTAssertFalse(
                newOrderButton.waitForExistence(timeout: 2),
                "\(role) must not expose the New order action"
            )
        }

        let openOrderRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "orders.open.row.")
        ).firstMatch
        XCTAssertTrue(
            openOrderRow.waitForExistence(timeout: 15),
            "\(role) did not render a seeded open order row"
        )
        guard openOrderRow.exists else { return }

        openOrderRow.swipeLeft()

        let cancelOrderButton = app.buttons["Cancel order"]
        if shouldExposeActions {
            XCTAssertTrue(
                cancelOrderButton.waitForExistence(timeout: 5),
                "\(role) did not expose Cancel order after swiping an open order"
            )
        } else {
            XCTAssertFalse(
                cancelOrderButton.waitForExistence(timeout: 2),
                "\(role) must not expose Cancel order after swiping an open order"
            )
        }
        openOrderRow.swipeRight()
    }

    /// Resolve one segmented-control segment by its rendered title.
    ///
    /// SwiftUI bridges `.pickerStyle(.segmented)` to a `segmentedControl`
    /// whose segments are buttons, but the flattened `buttons` query also
    /// reaches them; querying the container first keeps the match from
    /// colliding with a same-labeled button elsewhere on screen.
    private func segment(in app: XCUIApplication, title: String) -> XCUIElement {
        let scoped = app.segmentedControls.buttons[title]
        if scoped.exists {
            return scoped
        }
        return app.buttons[title]
    }

    /// Open the `Current | P&L Timeline` segment inside Positions and
    /// retain both the chart region and the tables below it.
    ///
    /// The timeline is a read-only surface for every role, so the pass is
    /// identical for admin and viewer: both must reach it and both must
    /// render either populated points or the screen's own empty state.
    private func capturePnlTimelineSegment(app: XCUIApplication, role: String) {
        selectRootTab(app: app, title: "Positions")
        XCTAssertTrue(
            app.navigationBars["Positions"].waitForExistence(timeout: 15),
            "\(role) could not return to Positions for the P&L timeline"
        )

        let timeline = segment(in: app, title: "P&L Timeline")
        XCTAssertTrue(
            timeline.waitForExistence(timeout: 10),
            "\(role) cannot reach the P&L Timeline segment"
        )
        guard timeline.exists else { return }
        timeline.tap()
        sleep(8)
        attach(code: "us", screen: "uat-\(role)-pnl-timeline-chart")

        let timelineScroll = app.scrollViews.firstMatch
        for _ in 0..<3 where timelineScroll.exists {
            timelineScroll.swipeUp()
        }
        sleep(2)
        attach(code: "us", screen: "uat-\(role)-pnl-timeline-tables")

        let current = segment(in: app, title: "Current")
        if current.exists {
            current.tap()
            sleep(2)
        }
    }

    /// Prove the Processes lifecycle controls follow `manage:processes`.
    ///
    /// Admin must reach at least one control on an eligible row and must
    /// still see none on a strategy row (those are excluded by routing,
    /// not by permission). Viewer must see no control anywhere — the
    /// query is on the stable `processes.control.*` identifiers, so an
    /// absent match is an absent affordance rather than an unopened view.
    private func verifyProcessLifecycleControls(app: XCUIApplication, role: String) {
        let controls = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "processes.control.")
        )
        let strategyControls = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS %@", "processes.control.start.strategy_")
        )

        if role != "viewer" {
            let processScroll = app.scrollViews.firstMatch
            var attempts = 0
            while !controls.firstMatch.exists && attempts < 6 {
                if processScroll.exists {
                    processScroll.swipeUp()
                }
                attempts += 1
            }
            XCTAssertTrue(
                controls.firstMatch.waitForExistence(timeout: 10),
                "\(role) did not expose any process lifecycle control"
            )
            sleep(1)
            attach(code: "us", screen: "uat-\(role)-processes-controls")
            XCTAssertFalse(
                strategyControls.firstMatch.exists,
                "\(role) must not expose lifecycle controls on a strategy row"
            )
        } else {
            XCTAssertFalse(
                controls.firstMatch.waitForExistence(timeout: 3),
                "\(role) must not expose any process lifecycle control"
            )
            let processScroll = app.scrollViews.firstMatch
            for _ in 0..<4 where processScroll.exists {
                processScroll.swipeUp()
            }
            XCTAssertFalse(
                controls.firstMatch.exists,
                "\(role) must not expose a process lifecycle control further down the list"
            )
            sleep(1)
            attach(code: "us", screen: "uat-\(role)-processes-no-controls")
        }
    }

    /// Prove the 3.1 desk surface renders the exact server-filtered catalogue
    /// and the expected membership controls for this named fixture session.
    /// Unit tests separately pin the effective-permission decision independently
    /// of role; this live sweep does not claim to distinguish that implementation.
    private func captureDeskSurface(
        app: XCUIApplication,
        role: String,
        expectedDeskLabels: [String],
        expectedDeskPublicIds: [String],
        expectedFixtureMarker: String?,
        attachmentExpectation: DeskAttachmentExpectation
    ) -> Bool {
        guard openDeskFromSettings(app: app, role: role) else { return false }
        let fixtureIsConsistent = expectedDeskLabels.count == expectedDeskPublicIds.count
        XCTAssertTrue(
            fixtureIsConsistent,
            "\(role) UAT expectation must pair every desk label with a public id"
        )
        guard fixtureIsConsistent else { return false }
        guard waitForSuccessfulDeskLoad(
            app: app,
            evidence: role,
            expectedDeskPublicIds: expectedDeskPublicIds
        ) else { return false }
        let deskRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "desk.row.")
        )
        let exactRowsMatch = waitForExactDeskIdentifiers(
            expectedDeskPublicIds,
            in: app
        )
        XCTAssertTrue(
            exactRowsMatch,
            "\(role) received desk identifiers other than \(expectedDeskPublicIds)"
        )
        guard exactRowsMatch else { return false }
        let renderedLabels = deskRows.allElementsBoundByIndex.map(\.label)
        var labelsMatch = true
        for expectedLabel in expectedDeskLabels {
            let containsLabel = renderedLabels.contains {
                $0.localizedCaseInsensitiveContains(expectedLabel)
            }
            XCTAssertTrue(
                containsLabel,
                "\(role) did not receive expected desk \(expectedLabel)"
            )
            labelsMatch = labelsMatch && containsLabel
        }
        var fixtureMarkerMatches = true
        if let expectedFixtureMarker {
            fixtureMarkerMatches = renderedLabels.contains {
                $0.localizedCaseInsensitiveContains(expectedFixtureMarker)
            }
            XCTAssertTrue(
                fixtureMarkerMatches,
                "\(role) is not connected to the recorded disposable desk fixture"
            )
        }
        guard labelsMatch,
              fixtureMarkerMatches else { return false }
        attach(code: "us", screen: "uat-\(role)-desk")

        let username = app.textFields["desk.attach.username"]
        let submit = app.buttons["desk.attach.submit"]
        switch attachmentExpectation {
        case .attachViewer(let targetPublicId, let evidence):
            let deskSurface = app.descendants(matching: .any).matching(
                identifier: "desk.state.loaded.content"
            ).firstMatch
            let usernameHittable = waitUntilHittable(
                username,
                byScrolling: deskSurface
            )
            XCTAssertTrue(
                usernameHittable,
                "\(role) did not expose the viewer attachment form"
            )
            let submitExists = submit.waitForExistence(timeout: 5)
            XCTAssertTrue(
                submitExists,
                "\(role) did not expose the viewer attachment action"
            )
            let selector = app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    "desk.attach.selector."
                )
            ).firstMatch
            let selectorExists = selector.waitForExistence(timeout: 5)
            XCTAssertTrue(
                selectorExists,
                "\(role) did not expose the desk selector"
            )
            guard usernameHittable, submitExists, selectorExists else { return false }
            let expectedSelectorIdentifier = "desk.attach.selector.\(targetPublicId)"
            XCTAssertEqual(
                selector.identifier,
                expectedSelectorIdentifier,
                "\(role) \(evidence) targeted a different desk public id"
            )
            guard selector.identifier == expectedSelectorIdentifier else { return false }
            username.tap()
            username.typeText("deskviewer")
            let submitHittable = waitUntilHittable(
                submit,
                byScrolling: deskSurface
            )
            XCTAssertTrue(submitHittable, "\(role) attachment action was not hittable")
            XCTAssertTrue(submit.isEnabled, "\(role) attachment action stayed disabled")
            guard submitHittable, submit.isEnabled else { return false }
            submit.tap()

            let success = app.descendants(matching: .any).matching(
                identifier: "desk.attach.success"
            ).firstMatch
            let successExists = success.waitForExistence(timeout: 15)
            XCTAssertTrue(
                successExists,
                "\(role) could not complete \(evidence)"
            )
            attach(code: "us", screen: "uat-\(role)-desk-attach-success")
            return successExists
        case .hidden:
            let usernameHidden = !username.waitForExistence(timeout: 3)
            XCTAssertTrue(
                usernameHidden,
                "\(role) must not expose the viewer attachment form"
            )
            let submitHidden = !submit.exists
            XCTAssertTrue(
                submitHidden,
                "\(role) must not expose the viewer attachment action"
            )
            let selectorHidden = !app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    "desk.attach.selector."
                )
            ).firstMatch.exists
            XCTAssertTrue(
                selectorHidden,
                "\(role) must not expose the desk selector"
            )
            return usernameHidden && submitHidden && selectorHidden
        }
    }

    private func waitForSuccessfulDeskLoad(
        app: XCUIApplication,
        evidence: String,
        expectedDeskPublicIds: [String],
        timeout: TimeInterval = 15
    ) -> Bool {
        let stateIdentifier = expectedDeskPublicIds.isEmpty
            ? "desk.state.loaded.empty"
            : "desk.state.loaded.content"
        let loaded = app.descendants(matching: .any).matching(
            identifier: stateIdentifier
        ).firstMatch
        let loadedExists = loaded.waitForExistence(timeout: timeout)
        XCTAssertTrue(
            loadedExists,
            "\(evidence) desk catalogue did not reach a successful loaded state"
        )
        return loadedExists
    }

    /// Require the same exact identifier set across consecutive accessibility
    /// snapshots so transient collection counts cannot satisfy the UAT gate.
    private func waitForExactDeskIdentifiers(
        _ expectedPublicIds: [String],
        in app: XCUIApplication,
        timeout: TimeInterval = 15
    ) -> Bool {
        let expected = Set(expectedPublicIds.map { "desk.row.\($0)" })
        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "desk.row.")
        )
        let deadline = Date().addingTimeInterval(timeout)
        var consecutiveMatches = 0
        repeat {
            let identifiers = rows.allElementsBoundByIndex.map(\.identifier)
            let isExact = identifiers.count == expected.count
                && Set(identifiers) == expected
            consecutiveMatches = isExact ? consecutiveMatches + 1 : 0
            if consecutiveMatches == 3 {
                return true
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }

    private func waitUntilHittable(
        _ element: XCUIElement,
        timeout: TimeInterval = 8
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists && element.isHittable {
                return true
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return element.exists && element.isHittable
    }

    private func waitUntilHittable(
        _ element: XCUIElement,
        byScrolling scrollContainer: XCUIElement,
        timeout: TimeInterval = 8,
        maximumSwipes: Int = 8
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var swipeCount = 0
        repeat {
            if element.exists && element.isHittable {
                return true
            }
            if scrollContainer.exists && swipeCount < maximumSwipes {
                scrollContainer.swipeUp()
                swipeCount += 1
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return element.exists && element.isHittable
    }

    private func openDeskFromSettings(app: XCUIApplication, role: String) -> Bool {
        let deskLink = app.descendants(matching: .any).matching(
            identifier: "settings.desk"
        ).firstMatch
        let settingsForm = app.descendants(matching: .any).matching(
            identifier: "settings.form"
        ).firstMatch
        let deskLinkHittable = waitUntilHittable(
            deskLink,
            byScrolling: settingsForm
        )
        XCTAssertTrue(
            deskLinkHittable,
            "\(role) did not expose a hittable My desks link in Settings"
        )
        guard deskLinkHittable else { return false }
        deskLink.tap()
        XCTAssertTrue(
            app.navigationBars["My desks"].waitForExistence(timeout: 15),
            "\(role) could not open My desks"
        )
        return app.navigationBars["My desks"].exists
    }

    /// Establish the negative half of the membership activation boundary.
    /// The successful-loaded signal prevents the initial empty SwiftUI frame
    /// from satisfying this assertion before the API requests have settled.
    private func verifyUnattachedViewerBeforeAttach(username: String) -> Bool {
        let app = launchApp(
            spec: LocaleSpec(code: "us", appleLanguageTag: "en-US"),
            resetSession: true,
            useDemoWallet: false
        )
        guard performLogin(
            in: app,
            usernameValue: username,
            passwordValue: "change-me-after-first-login"
        ) else {
            XCTFail("unattached viewer could not log in before desk attachment")
            app.terminate()
            return false
        }
        dismissSavePasswordDialog(app: app)
        captureRootTab(
            app: app,
            role: "unattached-viewer",
            tabTitle: "Settings",
            navigationTitle: "Settings",
            screen: "settings-before-attach"
        )
        guard openDeskFromSettings(app: app, role: "unattached-viewer") else {
            app.terminate()
            return false
        }
        let loaded = waitForSuccessfulDeskLoad(
            app: app,
            evidence: "unattached viewer",
            expectedDeskPublicIds: []
        )
        let exactZeroDesks = loaded && waitForExactDeskIdentifiers([], in: app)
        XCTAssertTrue(
            exactZeroDesks,
            "unattached viewer must see the honest zero-desk state"
        )
        let hasDeskRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "desk.row.")
        ).firstMatch.exists
        XCTAssertFalse(
            hasDeskRow,
            "unattached viewer must not receive a desk before attachment"
        )
        let formHidden = !app.textFields["desk.attach.username"].exists
            && !app.buttons["desk.attach.submit"].exists
            && !app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    "desk.attach.selector."
                )
            ).firstMatch.exists
        XCTAssertTrue(formHidden, "unattached viewer must not expose the attach form")
        attach(code: "us", screen: "uat-viewer-desk-before-attach")
        app.terminate()
        return exactZeroDesks && !hasDeskRow && formHidden
    }

    /// Observe one exact membership in a fresh viewer session. The caller runs
    /// this once after admin's write and again after operator's idempotent repeat.
    private func verifyViewerDeskMembership(
        username: String,
        phase: String
    ) -> Bool {
        let evidence = phase.replacingOccurrences(of: "-", with: " ")
        let app = launchApp(
            spec: LocaleSpec(code: "us", appleLanguageTag: "en-US"),
            resetSession: true,
            useDemoWallet: false
        )
        guard performLogin(
            in: app,
            usernameValue: username,
            passwordValue: "change-me-after-first-login"
        ) else {
            XCTFail("viewer could not log in \(evidence)")
            app.terminate()
            return false
        }
        dismissSavePasswordDialog(app: app)
        captureRootTab(
            app: app,
            role: "viewer-\(phase)",
            tabTitle: "Settings",
            navigationTitle: "Settings",
            screen: "settings"
        )
        guard openDeskFromSettings(app: app, role: "viewer \(evidence)") else {
            app.terminate()
            return false
        }
        let loaded = waitForSuccessfulDeskLoad(
            app: app,
            evidence: "viewer \(evidence)",
            expectedDeskPublicIds: [deskUATDefaultPublicId]
        )
        let exactDesk = loaded && waitForExactDeskIdentifiers(
            [deskUATDefaultPublicId],
            in: app
        )
        let formHidden = !app.textFields["desk.attach.username"].exists
            && !app.buttons["desk.attach.submit"].exists
            && !app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    "desk.attach.selector."
                )
            ).firstMatch.exists
        XCTAssertTrue(exactDesk, "viewer must have exactly the recorded default desk \(evidence)")
        XCTAssertTrue(formHidden, "viewer must not expose membership controls \(evidence)")
        attach(code: "us", screen: "uat-viewer-desk-\(phase)")
        app.terminate()
        return exactDesk && formHidden
    }

    /// Prove the AI-review delegate inbox stays hidden for both roles.
    ///
    /// Neither session carries a `delegate_public_id`, so the
    /// `Pending reviews | AI Decisions` segment — and with it every
    /// approve / reject affordance — must be absent. That absence IS the
    /// gating proof for these two roles; the delegate-positive path is
    /// pinned by the unit suite.
    private func verifyAiReviewDelegateSegmentAbsent(app: XCUIApplication, role: String) {
        for title in ["Pending reviews", "AI Decisions"] {
            XCTAssertFalse(
                segment(in: app, title: title).waitForExistence(timeout: 2),
                "\(role) must not see the \(title) AI-review segment without a delegate identity"
            )
        }
        for decision in ["Approve", "Reject"] {
            XCTAssertFalse(
                app.buttons[decision].exists,
                "\(role) must not expose the \(decision) AI-review decision action"
            )
        }
    }

    /// Retain the Signals strategy filter and CSV export affordances.
    ///
    /// Both are read-side tools rather than mutations, so both roles must
    /// reach them; the menu is opened so the retained screenshot shows the
    /// seeded strategy options rather than just the toolbar glyph.
    private func captureSignalsToolbar(app: XCUIApplication, role: String) {
        let exportButton = app.buttons["Export"]
        XCTAssertTrue(
            exportButton.waitForExistence(timeout: 10),
            "\(role) did not expose the Signals CSV export action"
        )
        XCTAssertTrue(
            exportButton.isEnabled,
            "\(role) Signals export is disabled despite seeded signals"
        )

        let filterButton = app.buttons["Filter by strategy"]
        XCTAssertTrue(
            filterButton.waitForExistence(timeout: 10),
            "\(role) did not expose the Signals strategy filter"
        )
        guard filterButton.exists else { return }
        filterButton.tap()
        sleep(2)
        attach(code: "us", screen: "uat-\(role)-signals-strategy-filter")

        let allStrategies = app.buttons["All Strategies"]
        if allStrategies.waitForExistence(timeout: 3), allStrategies.exists {
            allStrategies.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap()
        }
        sleep(1)
    }

    /// Retain one empty state mid-pull, proving refresh stayed reachable.
    ///
    /// Venue Accounts is empty in this fixture and keeps its
    /// `ContentUnavailableView` inside the refreshable list, which is
    /// exactly the regression the build-29 empty-state work fixed: a
    /// whole-screen placeholder outside the scroll view cannot be pulled.
    private func captureRefreshableEmptyState(app: XCUIApplication, role: String) {
        XCTAssertTrue(
            app.staticTexts["No venue accounts"].waitForExistence(timeout: 15),
            "\(role) did not reach the Venue Accounts empty state"
        )
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: end)
        attach(code: "us", screen: "uat-\(role)-accounts-empty-pull-to-refresh")
        sleep(3)
        XCTAssertTrue(
            app.staticTexts["No venue accounts"].waitForExistence(timeout: 15),
            "\(role) lost the Venue Accounts empty state after pull-to-refresh"
        )
    }

    private func captureHomeSurface(
        app: XCUIApplication,
        role: String,
        title: String,
        screen: String,
        inspection: UatSurfaceInspection = .none
    ) {
        selectRootTab(app: app, title: "Home")
        let homeNavigationBar = app.navigationBars["Home"]
        let homeIsActive = waitUntilHittable(homeNavigationBar, timeout: 10)
        XCTAssertTrue(
            homeIsActive,
            "\(role) could not return to Home before opening \(title)"
        )
        guard homeIsActive else { return }

        let homeScroll = app.scrollViews.firstMatch
        for _ in 0..<8 where homeScroll.exists {
            homeScroll.swipeDown()
        }

        let titleElement = app.staticTexts[title]
        let titleIsHittable = waitUntilHittable(
            titleElement,
            byScrolling: homeScroll,
            timeout: 15,
            maximumSwipes: 12
        )
        XCTAssertTrue(
            titleIsHittable,
            "\(role) cannot reach the \(title) Home card"
        )
        guard titleIsHittable else { return }

        titleElement.tap()
        XCTAssertTrue(
            app.navigationBars[title].waitForExistence(timeout: 15),
            "\(role) could not open \(title)"
        )
        if title == "Market data" {
            waitForMarketDataReady(app: app, role: role)
        }
        sleep(2)
        attach(code: "us", screen: screen)

        switch inspection {
        case .none:
            break
        case .processLifecycleControls:
            verifyProcessLifecycleControls(app: app, role: role)
        case .aiReviewDelegateSegment:
            verifyAiReviewDelegateSegmentAbsent(app: app, role: role)
        }

        let destinationNavigationBar = app.navigationBars[title]
        let backButton = destinationNavigationBar.buttons.firstMatch
        let backButtonIsHittable = waitUntilHittable(backButton, timeout: 5)
        XCTAssertTrue(
            backButtonIsHittable,
            "\(title) did not expose a navigation-back button"
        )
        if backButtonIsHittable {
            backButton.tap()
            var returnedHome = waitUntilHittable(homeNavigationBar, timeout: 10)
            if !returnedHome && waitUntilHittable(backButton, timeout: 2) {
                backButton.tap()
                returnedHome = waitUntilHittable(homeNavigationBar, timeout: 10)
            }
            XCTAssertTrue(
                returnedHome,
                "\(role) did not finish returning Home after \(title)"
            )
        }
    }

    private func waitForMarketDataReady(app: XCUIApplication, role: String) {
        let selectedInstrument = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "BTC-USD")
        ).firstMatch
        XCTAssertTrue(
            selectedInstrument.waitForExistence(timeout: 30),
            "\(role) did not auto-select BTC-USD on Market data"
        )
        XCTAssertTrue(
            app.staticTexts["Live"].waitForExistence(timeout: 30),
            "\(role) Market data did not reach the Live state"
        )
        XCTAssertFalse(
            app.staticTexts["No candles yet"].exists,
            "\(role) Market data rendered without candles"
        )
    }

    private func selectWallet(
        app: XCUIApplication,
        role: String,
        displayName: String
    ) {
        let picker = app.buttons["wallet.picker"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 10),
            "\(role) could not reach the wallet picker"
        )
        guard picker.exists else { return }
        if picker.label.localizedCaseInsensitiveContains(displayName) {
            return
        }
        picker.tap()

        let option = app.buttons.matching(
            NSPredicate(
                format: "label == %@ AND identifier != %@",
                displayName,
                "wallet.picker"
            )
        ).firstMatch
        XCTAssertTrue(
            option.waitForExistence(timeout: 5),
            "\(role) could not reach the \(displayName) wallet"
        )
        guard option.exists else { return }
        option.tap()

        let selectedPredicate = NSPredicate(
            format: "label CONTAINS[c] %@",
            displayName
        )
        let selectedExpectation = XCTNSPredicateExpectation(
            predicate: selectedPredicate,
            object: picker
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [selectedExpectation], timeout: 10),
            .completed,
            "\(role) could not select the \(displayName) wallet"
        )
    }

    private func captureRootTab(
        app: XCUIApplication,
        role: String,
        tabTitle: String,
        navigationTitle: String,
        screen: String
    ) {
        selectRootTab(app: app, title: tabTitle)
        XCTAssertTrue(
            app.navigationBars[navigationTitle].waitForExistence(timeout: 15),
            "\(role) could not open the \(tabTitle) root surface"
        )
        sleep(2)
        attach(code: "us", screen: "uat-\(role)-tab-\(screen)")
    }

    private func selectRootTab(app: XCUIApplication, title: String) {
        let directTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", title)
        ).firstMatch
        if directTab.exists {
            directTab.tap()
            return
        }

        let moreTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "More")
        ).firstMatch
        XCTAssertTrue(
            moreTab.waitForExistence(timeout: 5),
            "Neither \(title) nor the More tab is reachable"
        )
        guard moreTab.exists else { return }
        moreTab.tap()

        let destination = app.staticTexts[title]
        XCTAssertTrue(
            destination.waitForExistence(timeout: 5),
            "\(title) is missing from the More tab"
        )
        if destination.exists {
            destination.tap()
        }
    }

    private func captureTabSequence(app: XCUIApplication, code: String) {
        // Try the native tabBar path first, then fall back to descriptors.
        var buttons: XCUIElementQuery? = nil
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            buttons = tabBar.buttons
        }
        let labels = ["04-positions", "05-orders", "06-alerts", "07-settings"]
        // SwiftUI TabView bridges to a `tabBar` accessibility role; if our
        // search above didn't find one, we attempt button taps by index in
        // the bottom-of-screen "Tab" elements query as a fallback.
        for (index, label) in labels.enumerated() {
            let tabIndex = index + 1
            var tapped = false
            if let bb = buttons {
                let count = bb.count
                if tabIndex < count {
                    bb.element(boundBy: tabIndex).tap()
                    tapped = true
                }
            }
            if !tapped {
                let normalized = CGVector(dx: 0.1 + 0.2 * CGFloat(tabIndex), dy: 0.96)
                app.coordinate(withNormalizedOffset: normalized).tap()
                tapped = true
            }
            sleep(3)
            attach(code: code, screen: label)
        }
    }

    private func attach(code: String, screen: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.lifetime = .keepAlways
        attachment.name = "locale-\(code)__\(screen).png"
        add(attachment)
    }

    private func dismissSavePasswordDialog(app: XCUIApplication) {
        sleep(2)
        app.tap()
        sleep(1)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Not Now", "Never for This App", "Cancel"] {
            let candidate = springboard.buttons[label]
            if candidate.waitForExistence(timeout: 2) {
                candidate.tap()
                sleep(1)
                return
            }
        }
        for label in ["Not Now", "Never for This App", "Cancel"] {
            let candidate = app.buttons[label]
            if candidate.waitForExistence(timeout: 1) {
                candidate.tap()
                sleep(1)
                return
            }
        }
        let notNowCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.51))
        notNowCoord.tap()
        sleep(1)
    }
}
