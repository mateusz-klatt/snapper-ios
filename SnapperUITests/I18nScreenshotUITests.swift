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

    /// Release UAT for the permission-derived admin, operator, and viewer surfaces.
    ///
    /// The isolated fixture gives admin and operator the default desk, creates
    /// `deskviewer` without a membership, adds an instrument scope grant for
    /// the paper wallet, and creates one additional unscoped desk. Admin must
    /// see both desks and attach `deskviewer`; operator then sees only default
    /// and repeats that attach idempotently; the viewer's next login must see
    /// only default. Viewer retains zero mutation affordances; admin also sees
    /// Users.
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
        guard verifyViewerDeskAfterAdminAttachment(username: "deskviewer") else { return }
        guard capturePermissionUAT(
            role: "operator",
            username: "operator",
            expectedDeskLabels: ["default"],
            expectedDeskPublicIds: [deskUATDefaultPublicId],
            expectedFixtureMarker: nil,
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
        guard capturePermissionUAT(
            role: "viewer",
            username: "deskviewer",
            expectedDeskLabels: ["default"],
            expectedDeskPublicIds: [deskUATDefaultPublicId],
            expectedFixtureMarker: nil,
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

    private func capturePermissionUAT(
        role: String,
        username: String,
        expectedDeskLabels: [String],
        expectedDeskPublicIds: [String],
        expectedFixtureMarker: String?,
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
                shouldExposeAttachment: role != "viewer"
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

    /// Prove the 3.1 desk surface renders the server-filtered catalogue and
    /// the deployed capability matrix. Unit tests separately pin the exact
    /// effective-permission decision independently of role.
    private func captureDeskSurface(
        app: XCUIApplication,
        role: String,
        expectedDeskLabels: [String],
        expectedDeskPublicIds: [String],
        expectedFixtureMarker: String?,
        shouldExposeAttachment: Bool
    ) -> Bool {
        guard openDeskFromSettings(app: app, role: role) else { return false }
        let deskRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "desk.row.")
        )
        let firstRowExists = deskRows.firstMatch.waitForExistence(timeout: 15)
        XCTAssertTrue(
            firstRowExists,
            "\(role) did not render an attached desk"
        )
        guard firstRowExists else { return false }
        var countAttempts = 0
        while deskRows.count != expectedDeskLabels.count && countAttempts < 10 {
            sleep(1)
            countAttempts += 1
        }
        let countMatches = deskRows.count == expectedDeskLabels.count
        XCTAssertTrue(
            countMatches,
            "\(role) received an unexpected server-filtered desk catalogue"
        )
        let renderedLabels = deskRows.allElementsBoundByIndex.map(\.label)
        var publicIdsMatch = expectedDeskPublicIds.count == expectedDeskLabels.count
        for publicId in expectedDeskPublicIds {
            let rowExists = app.descendants(matching: .any).matching(
                identifier: "desk.row.\(publicId)"
            ).firstMatch.exists
            XCTAssertTrue(rowExists, "\(role) did not receive expected desk id \(publicId)")
            publicIdsMatch = publicIdsMatch && rowExists
        }
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
        var excludesSecondary = true
        if !expectedDeskLabels.contains("ios-uat-secondary") {
            excludesSecondary = !renderedLabels.contains {
                $0.localizedCaseInsensitiveContains("ios-uat-secondary")
            }
            XCTAssertTrue(
                excludesSecondary,
                "\(role) must not receive the admin-only secondary desk"
            )
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
        guard countMatches,
              publicIdsMatch,
              labelsMatch,
              excludesSecondary,
              fixtureMarkerMatches else { return false }
        attach(code: "us", screen: "uat-\(role)-desk")

        let username = app.textFields["desk.attach.username"]
        let submit = app.buttons["desk.attach.submit"]
        if shouldExposeAttachment {
            let usernameExists = username.waitForExistence(timeout: 5)
            XCTAssertTrue(
                usernameExists,
                "\(role) did not expose the viewer attachment form"
            )
            let submitExists = submit.waitForExistence(timeout: 5)
            XCTAssertTrue(
                submitExists,
                "\(role) did not expose the viewer attachment action"
            )
            let selector = app.descendants(matching: .any).matching(
                identifier: "desk.attach.selector"
            ).firstMatch
            let selectorExists = selector.waitForExistence(timeout: 5)
            XCTAssertTrue(
                selectorExists,
                "\(role) did not expose the desk selector"
            )
            guard usernameExists, submitExists, selectorExists else { return false }
            let selectedDesk = "\(selector.label) \(String(describing: selector.value))"
            let targetsDefault = selectedDesk.localizedCaseInsensitiveContains("default")
            XCTAssertTrue(
                targetsDefault,
                "\(role) must target the same primary default desk"
            )
            guard targetsDefault else { return false }
            username.tap()
            username.typeText("deskviewer")
            XCTAssertTrue(submit.isEnabled, "\(role) attachment action stayed disabled")
            guard submit.isEnabled else { return false }
            submit.tap()

            let success = app.descendants(matching: .any).matching(
                identifier: "desk.attach.success"
            ).firstMatch
            let successExists = success.waitForExistence(timeout: 15)
            XCTAssertTrue(
                successExists,
                "\(role) could not attach the UAT viewer"
            )
            attach(code: "us", screen: "uat-\(role)-desk-attach-success")
            return successExists
        } else {
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
                identifier: "desk.attach.selector"
            ).firstMatch.exists
            XCTAssertTrue(
                selectorHidden,
                "\(role) must not expose the desk selector"
            )
            return usernameHidden && submitHidden && selectorHidden
        }
    }

    private func openDeskFromSettings(app: XCUIApplication, role: String) -> Bool {
        let deskLink = app.descendants(matching: .any).matching(
            identifier: "settings.desk"
        ).firstMatch
        let settingsForm = app.collectionViews.firstMatch
        let settingsScroll = settingsForm.exists ? settingsForm : app.scrollViews.firstMatch
        var attempts = 0
        while (!deskLink.exists || !deskLink.isHittable) && attempts < 8 {
            if settingsScroll.exists {
                settingsScroll.swipeUp()
            }
            attempts += 1
        }
        XCTAssertTrue(
            deskLink.exists && deskLink.isHittable,
            "\(role) did not expose a hittable My desks link in Settings"
        )
        guard deskLink.exists, deskLink.isHittable else { return false }
        deskLink.tap()
        XCTAssertTrue(
            app.navigationBars["My desks"].waitForExistence(timeout: 15),
            "\(role) could not open My desks"
        )
        return app.navigationBars["My desks"].exists
    }

    /// Establish the negative half of the membership activation boundary.
    /// The fixture creates `deskviewer` without a membership; after this
    /// session is discarded, admin attaches it and the final viewer sweep
    /// must acquire exactly one desk on its next login.
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
        let empty = app.descendants(matching: .any).matching(
            identifier: "desk.empty"
        ).firstMatch
        let emptyExists = empty.waitForExistence(timeout: 15)
        XCTAssertTrue(
            emptyExists,
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
                identifier: "desk.attach.selector"
            ).firstMatch.exists
        XCTAssertTrue(formHidden, "unattached viewer must not expose the attach form")
        attach(code: "us", screen: "uat-viewer-desk-before-attach")
        app.terminate()
        return emptyExists && !hasDeskRow && formHidden
    }

    /// Observe the membership after admin's write and before operator's
    /// idempotent repeat, so the first 2xx cannot be a silent no-op.
    private func verifyViewerDeskAfterAdminAttachment(username: String) -> Bool {
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
            XCTFail("viewer could not log in after admin desk attachment")
            app.terminate()
            return false
        }
        dismissSavePasswordDialog(app: app)
        captureRootTab(
            app: app,
            role: "viewer-after-admin-attach",
            tabTitle: "Settings",
            navigationTitle: "Settings",
            screen: "settings-after-admin-attach"
        )
        guard openDeskFromSettings(app: app, role: "viewer-after-admin-attach") else {
            app.terminate()
            return false
        }
        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "desk.row.")
        )
        let rowExists = rows.firstMatch.waitForExistence(timeout: 15)
        let countMatches = rows.count == 1
        let expectedIdentifier = "desk.row.\(deskUATDefaultPublicId)"
        let isDefault = app.descendants(matching: .any).matching(
            identifier: expectedIdentifier
        ).firstMatch.exists
        let formHidden = !app.textFields["desk.attach.username"].exists
            && !app.buttons["desk.attach.submit"].exists
            && !app.descendants(matching: .any).matching(
                identifier: "desk.attach.selector"
            ).firstMatch.exists
        XCTAssertTrue(rowExists)
        XCTAssertTrue(countMatches)
        XCTAssertTrue(isDefault)
        XCTAssertTrue(formHidden)
        attach(code: "us", screen: "uat-viewer-desk-after-admin-attach")
        app.terminate()
        return rowExists && countMatches && isDefault && formHidden
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
        XCTAssertTrue(
            app.navigationBars["Home"].waitForExistence(timeout: 10),
            "\(role) could not return to Home before opening \(title)"
        )

        let homeScroll = app.scrollViews.firstMatch
        for _ in 0..<8 where homeScroll.exists {
            homeScroll.swipeDown()
        }

        let titleElement = app.staticTexts[title]
        var attempts = 0
        while (!titleElement.exists || !titleElement.isHittable) && attempts < 10 {
            homeScroll.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(
            titleElement.exists && titleElement.isHittable,
            "\(role) cannot reach the \(title) Home card"
        )
        guard titleElement.exists, titleElement.isHittable else { return }

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

        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(
            backButton.waitForExistence(timeout: 5),
            "\(title) did not expose a navigation-back button"
        )
        if backButton.exists {
            backButton.tap()
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
