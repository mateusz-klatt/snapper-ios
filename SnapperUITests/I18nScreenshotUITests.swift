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

    private var backendURL: String {
        ProcessInfo.processInfo.environment["SNAPPER_UITEST_BACKEND_URL"]
            ?? "https://bases-regulated-kevin-spears.trycloudflare.com"
    }

    /// Skip the screenshot harness when no backend tunnel is configured.
    /// CI without ``SNAPPER_UITEST_BACKEND_URL`` set hits a dead default
    /// cloudflared tunnel and stalls on login retries for 45 locales,
    /// blowing past the workflow timeout. Local + the dedicated
    /// `i18n-screenshots.yml` workflow both set the env var explicitly.
    private func skipUnlessBackendConfigured() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SNAPPER_UITEST_BACKEND_URL"] != nil,
            "Set SNAPPER_UITEST_BACKEND_URL to a live backend tunnel to run the i18n screenshot harness. Skipping in default CI."
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
            .init(code: "th", appleLanguageTag: "th-TH"),
            .init(code: "ir", appleLanguageTag: "fa-IR"),
            .init(code: "am", appleLanguageTag: "hy-AM"),
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
        let username = app.textFields["login.username"]
        if !username.waitForExistence(timeout: 10) { return false }
        username.tap()
        username.typeText(demoUsername)

        let password = app.secureTextFields["login.password"]
        if !password.waitForExistence(timeout: 5) { return false }
        password.tap()
        password.typeText(demoPassword)

        let signInButton = app.buttons["login.signIn"]
        if !signInButton.waitForExistence(timeout: 5) { return false }
        signInButton.tap()

        let tabBar = app.tabBars.firstMatch
        return tabBar.waitForExistence(timeout: 25)
    }

    private func captureTabSequence(app: XCUIApplication, code: String) {
        let tabBar = app.tabBars.firstMatch
        let buttons = tabBar.buttons
        let count = buttons.count
        let labels = ["04-positions", "05-orders", "06-alerts", "07-settings"]
        for (index, label) in labels.enumerated() {
            let tabIndex = index + 1
            if tabIndex < count {
                buttons.element(boundBy: tabIndex).tap()
                sleep(3)
                attach(code: code, screen: label)
            }
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
