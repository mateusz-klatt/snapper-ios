import XCTest

/// XCUITest coverage for the ``LocaleSwitcher`` — Phase I rolls out the
/// ``SnapperUITests`` target alongside the iPad device-family bump
/// (``TARGETED_DEVICE_FAMILY: "1,2"``) and the accessibility identifiers
/// under the ``localeSwitcher.*`` namespace.
///
/// Production identifiers exposed:
/// - ``localeSwitcher.trigger`` — the flag-emoji button that opens the
///   popover.
/// - ``localeSwitcher.flag.<code>`` — each of the 45 flag buttons,
///   keyed by ``AppLocale.rawValue``.
///
/// **Known gap (covered by ``XCTSkip``):** SwiftUI's ``@FocusState``
/// + ``.focused(_:equals:)`` propagation does NOT surface to XCUITest's
/// ``XCUIElementAttributes.hasFocus`` predicate. Apple has not bridged
/// the SwiftUI focus system with the UIAccessibility focus that
/// ``hasFocus`` reads. Arrow-key navigation through
/// ``LocaleSwitcherFocus.next(from:by:vertical:)`` works in manual
/// smoke but cannot be asserted at the XCUI layer until either:
/// (a) Apple bridges ``@FocusState`` into ``hasFocus`` accessibility,
/// (b) we add a ``focusedCode`` mirror to ``AppState`` and assert via a
///     hidden ``debug.appState.locale`` ``staticText`` probe, or
/// (c) snapshot tests replace XCUI for the focus-ring visual.
///
/// The single live test below is a smoke check that the popover opens
/// when the trigger is tapped — sufficient to catch a regression that
/// breaks the trigger button's identifier or the popover/sheet host.
final class LocaleSwitcherKeyboardFocusUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    /// Smoke test: tapping the LocaleSwitcher trigger opens the
    /// switcher and the current-locale flag button becomes
    /// queryable. This confirms the trigger identifier + flag
    /// identifier wiring on both iPhone (sheet adaptation) and
    /// iPad (true popover).
    func testTapTriggerExposesFlagButtons() throws {
        let trigger = app.buttons["localeSwitcher.trigger"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 5),
                      "LocaleSwitcher trigger must exist on launch")
        trigger.tap()

        let firstFlag = app.buttons["localeSwitcher.flag.ie"]
        XCTAssertTrue(firstFlag.waitForExistence(timeout: 5),
                      "Flag button must be queryable after switcher opens")
    }

    /// Keyboard-driven focus navigation through the 3×15 flag grid.
    /// Skipped — see class docstring for the SwiftUI ``@FocusState``
    /// vs XCUI ``hasFocus`` propagation gap.
    func testRightArrowMovesFocusToNextFlag() throws {
        throw XCTSkip(
            "SwiftUI @FocusState does not surface to XCUI hasFocus; assert in unit tests via LocaleSwitcherFocus.next(from:by:vertical:) or add a debug.appState.focusedCode staticText probe."
        )
    }

    /// Escape-key dismissal of the switcher. Skipped — XCUI key
    /// events do not always reach SwiftUI ``onKeyPress`` handlers on
    /// the simulator (focus is required, see related gap above).
    func testEscapeKeyDismissesSwitcher() throws {
        throw XCTSkip(
            "XCUI escape-key delivery to SwiftUI onKeyPress is unreliable on simulator; cover manually or via UIKit-bridged keyboard shortcut."
        )
    }
}
