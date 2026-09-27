// That the app opens at all, and that every settings pane draws. Nothing here needs a permission.

import XCTest

/// The floor: a build that cannot open a window is broken in a way no headless test can see.
final class LaunchSmokeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTheAppLaunches() {
        let app = AppUnderTest.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20), "the app never came up")
        app.terminate()
    }

    func testEverySettingsPaneDraws() {
        let app = AppUnderTest.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))

        app.menuBars.menuBarItems["Uttrflow"].click()
        app.menuItems["Settings…"].click()

        // Settings is a page of the main window, next to its sidebar.
        let settings = app.windows["Uttrflow"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "Settings never opened")

        for pane in ["General", "Languages", "Dictation", "AI suggestions", "Privacy", "Diagnostics"] {
            let tab = settings.buttons[pane]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "there is no \(pane) tab")
            tab.click()
            XCTAssertTrue(tab.isSelected, "\(pane) did not open")
        }
        app.terminate()
    }

    func testQuittingLeavesNothingRunning() {
        let app = AppUnderTest.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 20), "the app did not quit cleanly")
    }
}
