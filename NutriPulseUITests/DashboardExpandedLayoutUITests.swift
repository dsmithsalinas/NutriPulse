import XCTest

/// Read-only fixtures; no food, health or account mutations.
final class DashboardExpandedLayoutUITests: XCTestCase {
    private func launch(progress: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--tour"]
        if progress { app.launchArguments.append("--progress-preview") }
        app.launch()
        XCTAssertTrue(app.buttons["mainTab-today"].waitForExistence(timeout: 10))
        return app
    }

    private func orient(_ orientation: UIDeviceOrientation, app: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        let landscape = orientation == .landscapeLeft
        expectation(for: NSPredicate { _, _ in
            landscape ? app.frame.width > app.frame.height : app.frame.height > app.frame.width
        }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testTodayColumnsAndOpenLoggerSurviveRotation() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch()
        orient(.landscapeLeft, app: app)
        let overview = app.staticTexts["Daily overview"]
        let meals = app.staticTexts["Meals & notes"]
        XCTAssertTrue(overview.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(meals.frame.minX, overview.frame.maxX)
        XCTAssertEqual(meals.frame.minY, overview.frame.minY, accuracy: 2)
        capture("today-dedicated-expanded")
        app.buttons["Log food"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        orient(.portrait, app: app)
        XCTAssertTrue(app.buttons["Close"].isHittable)
        app.buttons["Close"].tap()
        XCTAssertTrue(overview.waitForExistence(timeout: 5))
        XCTAssertLessThan(overview.frame.minY, meals.frame.minY)
        XCTAssertEqual(overview.frame.minX, meals.frame.minX, accuracy: 2)
    }

    func testProgressColumnsAndSelectedRangeSurviveRotation() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(progress: true)
        orient(.landscapeLeft, app: app)
        let hero = app.descendants(matching: .any).matching(identifier: "progress-floorDays").firstMatch
        let stats = app.descendants(matching: .any).matching(identifier: "progress-statistics").firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(stats.frame.minX, hero.frame.minX + 200)
        capture("progress-dedicated-expanded")
        app.buttons["Week"].tap()
        XCTAssertTrue(app.buttons["Week"].isSelected)
        orient(.portrait, app: app)
        XCTAssertTrue(app.buttons["Week"].isSelected)
        orient(.landscapeLeft, app: app)
        XCTAssertTrue(app.buttons["Week"].isSelected)
        capture("progress-expanded-week")
    }
}
