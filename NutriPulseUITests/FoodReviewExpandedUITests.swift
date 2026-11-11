import XCTest

/// Exercises real review views with read-only local fixtures. Never taps a save action.
final class FoodReviewExpandedUITests: XCTestCase {
    private func launch(_ flag: String, largeText: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--log-preview", flag]
        if flag != "--confirmation-preview" { app.launchArguments += ["--food-review-preview"] }
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }
    private func rotate(_ orientation: UIDeviceOrientation, app: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        expectation(for: NSPredicate { _, _ in
            orientation == .portrait ? app.frame.height > app.frame.width : app.frame.width > app.frame.height
        }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testDetailExpandedNutritionAndQuantitySurviveRotation() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("--detail-preview")
        XCTAssertTrue(app.buttons["Log Food"].waitForExistence(timeout: 10))
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.buttons["Log Food"].isHittable)
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        XCTAssertGreaterThan(app.staticTexts["Calories"].frame.minX, app.staticTexts["Servings"].frame.maxX)
        XCTAssertLessThanOrEqual(app.staticTexts["Fiber"].frame.maxY, app.buttons["Log Food"].frame.minY)
        capture("food-expanded-detail")
        app.steppers.firstMatch.buttons["Increment"].tap()
        XCTAssertTrue(app.staticTexts["400.0 kcal"].exists)
        rotate(.portrait, app: app)
        XCTAssertTrue(app.staticTexts["1.25"].exists)
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.staticTexts["400.0 kcal"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
    }
    func testDetailLargestTextKeepsSaveAndCancelReachable() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("--detail-preview", largeText: true)
        XCTAssertTrue(app.buttons["Log Food"].waitForExistence(timeout: 10))
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.buttons["Log Food"].isHittable)
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        capture("food-detail-large-text")
    }
    func testParsedConfirmationRetainsQuantityAndInclusion() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("--confirmation-preview")
        XCTAssertTrue(app.staticTexts["Review your food"].waitForExistence(timeout: 10))
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.buttons["Log 3 items"].isHittable)
        let inclusion = app.buttons["Included — tap to remove Chicken breast"]
        XCTAssertGreaterThanOrEqual(inclusion.frame.height + 0.001, 44)
        capture("food-expanded-confirmation")
        inclusion.tap()
        XCTAssertTrue(app.buttons["Log 2 items"].exists)
        app.steppers.firstMatch.buttons["Increment"].tap()
        rotate(.portrait, app: app)
        XCTAssertTrue(app.buttons["Excluded — tap to include Chicken breast"].exists)
        XCTAssertTrue(app.buttons["Log 2 items"].exists)
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.buttons["Log 2 items"].isHittable)
    }
    func testFamiliarReviewExpandedAndRetainsQuantity() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("--familiar-review-preview")
        XCTAssertTrue(app.buttons["Save for this day"].waitForExistence(timeout: 10))
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.buttons["Save for this day"].isHittable)
        XCTAssertTrue(app.steppers.firstMatch.isHittable)
        capture("food-expanded-familiar-review")
        app.buttons["familiarQuantity-Increment"].tap()
        rotate(.portrait, app: app)
        XCTAssertTrue(app.staticTexts["400 kcal · 38g protein"].exists)
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.staticTexts["400 kcal · 38g protein"].exists)
    }
    func testReviewSaveControlsRemainReachableAtLargestText() {
        defer { XCUIDevice.shared.orientation = .portrait }
        for (flag, label) in [("--familiar-review-preview", "Save for this day"), ("--repeat-review-preview", "Log Lunch"), ("--confirmation-preview", "Log 3 items")] {
            let app = launch(flag, largeText: true)
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 10))
            rotate(.landscapeLeft, app: app)
            XCTAssertTrue(app.buttons[label].isHittable)
            app.terminate()
        }
    }
    func testRepeatedMealExpandedTotalsAndSaveReachable() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("--repeat-review-preview")
        XCTAssertTrue(app.buttons["Log Lunch"].waitForExistence(timeout: 10))
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.buttons["Log Lunch"].isHittable)
        XCTAssertTrue(app.buttons["Not now"].isHittable)
        capture("food-expanded-repeat-confirmation")
        rotate(.portrait, app: app)
        XCTAssertTrue(app.buttons["Log Lunch"].isHittable)
    }
}
