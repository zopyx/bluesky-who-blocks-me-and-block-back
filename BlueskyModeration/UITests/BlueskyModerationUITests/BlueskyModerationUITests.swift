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
        let tabBar = app.tabBars.firstMatch
        let tabNames = tabBar.buttons.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(tabNames.contains("Moderation"), "Got: \(tabNames)")
        XCTAssertTrue(tabNames.contains("Settings"), "Got: \(tabNames)")
        XCTAssertTrue(tabNames.contains("Info"), "Got: \(tabNames)")
        XCTAssertTrue(tabNames.contains("Accounts"), "Got: \(tabNames)")

        tabBar.buttons["Settings"].tap()
        tabBar.buttons["Info"].tap()
        tabBar.buttons["Accounts"].tap()
        tabBar.buttons["Moderation"].tap()
    }

    func testModerationTabShowsContent() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Moderation"].exists)
    }

    func testAccountsTabShowsPreviewAccounts() {
        app.tabBars.firstMatch.buttons["Accounts"].tap()

        let teamAlpha = app.staticTexts["team-alpha.bsky.social"]
        XCTAssertTrue(teamAlpha.waitForExistence(timeout: 3))
    }

    func testSettingsTabShowsPreferences() {
        app.tabBars.firstMatch.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }

    func testInfoTabShowsSegmentedControl() {
        app.tabBars.firstMatch.buttons["Info"].tap()

        let overviewButton = app.buttons["Overview"]
        XCTAssertTrue(overviewButton.waitForExistence(timeout: 3))
    }

    func testInfoTabSectionSwitching() {
        app.tabBars.firstMatch.buttons["Info"].tap()

        let featuresButton = app.buttons["Features"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 3))
        featuresButton.tap()

        let legalButton = app.buttons["Legal"]
        XCTAssertTrue(legalButton.waitForExistence(timeout: 1))
    }
}
