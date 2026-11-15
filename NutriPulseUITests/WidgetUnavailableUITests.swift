import XCTest

final class WidgetUnavailableUITests: XCTestCase {
    func testUnavailableWidgetKeepsQuickActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--widget-preview"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Waiting for refresh"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(identifier: "Log food").count >= 3)
        XCTAssertTrue(app.buttons.matching(identifier: "Add water").count >= 3)
        XCTAssertTrue(app.buttons.matching(identifier: "Log dose").count >= 3)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "widget-refresh-and-health-unavailable"; shot.lifetime = .keepAlways; add(shot)
        app.swipeUp()
        let unavailable = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        unavailable.name = "widget-unavailable-details"; unavailable.lifetime = .keepAlways; add(unavailable)
    }
}
