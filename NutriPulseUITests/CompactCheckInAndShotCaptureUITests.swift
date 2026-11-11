import XCTest

final class CompactCheckInAndShotCaptureUITests: XCTestCase {
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testMetricsVisibleAtTopAndCaptureShotLogger() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--tour"]
        app.launch()
        XCTAssertTrue(app.buttons["mainTab-today"].waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        let protein = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Protein 85 grams logged.")).firstMatch
        let calories = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Calories ", "kilocalories logged.")).firstMatch
        XCTAssertTrue(protein.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(protein.frame.maxY, app.frame.maxY - 20)
        XCTAssertLessThanOrEqual(calories.frame.maxY, app.frame.maxY - 20)
        XCTAssertEqual(protein.frame.minY, calories.frame.minY, accuracy: 2)
        capture("today-compact-pulse-checkin")
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["--shot-preview"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Shot day"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Log dose"].exists)
        capture("shot-logging-portrait")
    }
}
