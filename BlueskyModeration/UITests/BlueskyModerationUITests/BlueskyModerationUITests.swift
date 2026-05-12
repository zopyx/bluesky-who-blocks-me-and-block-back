import XCTest

@MainActor
final class BlueskyModerationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testAppLaunches() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testTabNavigation() {
        // Verify all 4 tab bar items exist and are tappable
        XCTAssertTrue(app.buttons["Moderation"].exists)
        XCTAssertTrue(app.buttons["Profile"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
        XCTAssertTrue(app.buttons["Info"].exists)

        // Tap each tab
        app.buttons["Profile"].tap()
        app.buttons["Settings"].tap()
        app.buttons["Info"].tap()
        app.buttons["Moderation"].tap()
    }

    func testSettingsScreen() {
        app.buttons["Settings"].tap()

        // Verify Settings has expected sections
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }

    func testInfoScreen() {
        app.buttons["Info"].tap()

        // Verify Info screen has the segmented picker
        let overviewButton = app.buttons["Overview"]
        XCTAssertTrue(overviewButton.exists)

        // Switch tabs in Info view
        app.buttons["Features"].tap()
        app.buttons["Legal"].tap()
        app.buttons["Overview"].tap()
    }
}
