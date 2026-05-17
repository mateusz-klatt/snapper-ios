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

    private func performLogin(in app: XCUIApplication) -> Bool {
        // Cached session may auto-log-us-in. If no login text field appears
        // within a short window, assume we're already logged in.
        let username = app.textFields["login.username"]
        if !username.waitForExistence(timeout: 5) {
            // No login form → already logged in. Give the app a moment to settle.
            sleep(3)
            return true
        }
        // Race guard (id-ID and other cached-session locales): the
        // auto-login can complete between `waitForExistence` and `tap`,
        // tearing down the login form. Re-check `.exists` right before
        // each interaction so we don't crash trying to tap an element
        // that's already gone.
        if !username.exists {
            sleep(3)
            return true
        }
        username.tap()
        username.typeText(demoUsername)

        let password = app.secureTextFields["login.password"]
        if !password.waitForExistence(timeout: 5) { return false }
        if !password.exists {
            sleep(3)
            return true
        }
        password.tap()
        password.typeText(demoPassword)

        let signInButton = app.buttons["login.signIn"]
        if !signInButton.waitForExistence(timeout: 5) { return false }
        if !signInButton.exists {
            sleep(3)
            return true
        }
        signInButton.tap()

        // Brute force: give the app 15s for login + navigation, then
        // assume we're in post-login state.
        sleep(15)
        return true
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
