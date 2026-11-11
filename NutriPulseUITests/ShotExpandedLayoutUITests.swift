import XCTest

/// Edits only the unsaved preview draft. Never confirms or records a dose.
final class ShotExpandedLayoutUITests: XCTestCase {
    func testExpandedControlsFitAndDraftSurvivesRotation() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--shot-preview"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Shot day"].waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        let hold = app.buttons["Log dose"]
        XCTAssertTrue(hold.isHittable)
        for label in ["Raise dose", "Lower dose", "Left Abdomen", "Right Thigh", "Right Arm", "Close"] {
            XCTAssertTrue(app.buttons[label].isHittable, label)
        }
        XCTAssertGreaterThan(hold.frame.minX, app.buttons["Right Thigh"].frame.maxX)
        XCTAssertLessThanOrEqual(hold.frame.maxY, app.frame.maxY - 20)
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "shot-logging-expanded"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Right Thigh"].tap()
        app.buttons["Raise dose"].tap()
        XCTAssertTrue(app.staticTexts["Zepbound · 7.5 mg"].exists)
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate { _, _ in app.frame.height > app.frame.width }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["Right Thigh"].isSelected)
        XCTAssertTrue(app.staticTexts["Zepbound · 7.5 mg"].exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["Right Thigh"].isSelected)
        XCTAssertTrue(app.staticTexts["Zepbound · 7.5 mg"].exists)
        XCTAssertTrue(hold.isHittable)
    }

    func testLargeTextCanReachDoseControlWithoutSaving() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--shot-preview", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Close"].isHittable)
        let hold = app.buttons["Log dose"]
        for _ in 0..<5 {
            if hold.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(hold.isHittable)
    }
}
