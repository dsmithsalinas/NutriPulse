import XCTest

final class ExpandedNavigationRailUITests: XCTestCase {
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testRailReservesSpaceAndPortraitRestoresBottomNavigation() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--tour", "--ring-chat-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["mainTab-today"].waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        let rail = app.scrollViews.containing(.button, identifier: "mainTab-today").firstMatch
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        XCTAssertLessThan(rail.frame.width, 80)
        for name in ["today", "progress", "pulse", "profile"] {
            let tab = app.buttons["mainTab-\(name)"]
            XCTAssertTrue(tab.isHittable)
            XCTAssertGreaterThanOrEqual(tab.frame.width, 44)
            XCTAssertGreaterThanOrEqual(tab.frame.height, 44)
        }
        for name in ["today", "progress", "pulse"] {
            app.buttons["mainTab-\(name)"].tap()
            XCTAssertTrue(app.buttons["mainTab-\(name)"].isSelected)
            if name == "today" {
                XCTAssertGreaterThan(app.staticTexts["Daily overview"].frame.minX, rail.frame.maxX)
            }
            capture("rail-\(name)")
        }
        app.buttons["Log food"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate { _, _ in app.frame.height > app.frame.width }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(rail.exists)
        XCTAssertTrue(app.buttons["mainTab-pulse"].isSelected)
        let today = app.buttons["mainTab-today"]
        XCTAssertTrue(today.isHittable)
        XCTAssertGreaterThan(today.frame.minY, app.frame.height * 0.75)
        today.tap()
        capture("portrait-bottom-navigation")
    }
}
