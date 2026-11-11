import XCTest

final class OverviewAndProfileExpandedUITests: XCTestCase {
    private func rotate(_ orientation: UIDeviceOrientation, app: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        expectation(for: NSPredicate { _, _ in
            orientation == .portrait ? app.frame.height > app.frame.width : app.frame.width > app.frame.height
        }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testTodayKeepsProteinBesideCaloriesAndProfileUsesColumns() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--tour"]
        app.launch()
        XCTAssertTrue(app.buttons["mainTab-today"].waitForExistence(timeout: 10))
        rotate(.landscapeLeft, app: app)
        let protein = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Protein 85 grams logged.")).firstMatch
        let calories = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Calories ", "kilocalories logged.")).firstMatch
        XCTAssertTrue(protein.waitForExistence(timeout: 5))
        XCTAssertTrue(calories.exists)
        XCTAssertLessThanOrEqual(protein.frame.maxX, calories.frame.minX)
        XCTAssertEqual(protein.frame.minY, calories.frame.minY, accuracy: 2)
        XCTAssertLessThan(protein.frame.width, 200)
        // The optional Pulse check-in can precede the metrics. Bring the paired tiles
        // into the viewport for the screenshot without changing any preferences.
        let dashboard = app.scrollViews.containing(.staticText, identifier: "Daily overview").firstMatch
        let start = dashboard.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.8))
        let end = dashboard.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.2))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        capture("today-paired-metrics-rail")
        app.buttons["mainTab-profile"].tap()
        XCTAssertTrue(app.buttons["Edit goals"].waitForExistence(timeout: 5))
        let targets = app.staticTexts["Daily targets"]
        let pulse = app.staticTexts["Pulse"].firstMatch
        XCTAssertGreaterThan(pulse.frame.minX, targets.frame.minX + 200)
        XCTAssertTrue(app.buttons["Edit goals"].isHittable)
        XCTAssertTrue(app.buttons["Recalculate"].isHittable)
        capture("profile-expanded-rail")
        rotate(.portrait, app: app)
        XCTAssertTrue(app.buttons["mainTab-profile"].isSelected)
        XCTAssertTrue(app.buttons["Edit goals"].isHittable)
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.buttons["mainTab-profile"].isSelected)
        XCTAssertTrue(app.buttons["Edit goals"].isHittable)
    }
}
