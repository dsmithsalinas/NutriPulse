import XCTest

final class HealthExperienceActionsUITests: XCTestCase {
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ button: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 { if button.isHittable { return }; app.swipeUp() }
    }
    func testTodayFeedbackAndRecipeRequireExplicitApproval() {
        let app = XCUIApplication()
        app.launchArguments = ["--pulse-health-preview", "--pulse-preview"]
        app.launch()
        let cycle = app.buttons["health-summary-Your shot-cycle picture"]
        XCTAssertTrue(cycle.waitForExistence(timeout: 10)); reveal(cycle, in: app); cycle.tap()
        XCTAssertTrue(app.staticTexts["Does this fit today?"].waitForExistence(timeout: 5))
        app.buttons["Today feels different"].tap()
        XCTAssertTrue(app.staticTexts["Today comes first. Earlier observations are only background."].exists)
        capture("01-today-feedback")
        app.buttons["Change my answer"].tap()
        app.buttons["Sounds familiar"].tap()
        let keep = app.buttons["Keep what helps on days like this"]
        reveal(keep, in: app); keep.tap()
        XCTAssertTrue(app.staticTexts["Your easier-day recipe"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Review recipe"].isEnabled)
        let food = app.textFields["Something to eat"]
        food.tap(); food.typeText("My usual yogurt and fruit")
        let review = app.buttons["Review recipe"]
        reveal(review, in: app)
        XCTAssertTrue(review.isEnabled)
        capture("02-easier-day-recipe")
        review.tap()
        XCTAssertTrue(app.buttons["Approve and remember"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textFields["Memory for Pulse"].value as? String)?.contains("Food: My usual yogurt and fruit") == true)
        XCTAssertFalse(app.buttons["Approve and remember"].isEnabled, "The fixture must never save a memory.")
        capture("03-exact-memory-review")
    }
    func testExperimentNextStepsAreOptionalAndEasierNeedsAChange() {
        let app = XCUIApplication()
        app.launchArguments = ["--everyday-tools-preview", "--tools-experiment", "--tools-health"]
        app.launch()
        let reflect = app.buttons["Reflect on this experiment"].firstMatch
        XCTAssertTrue(reflect.waitForExistence(timeout: 10)); reveal(reflect, in: app); reflect.tap()
        XCTAssertTrue(app.staticTexts["What would you like to do next?"].waitForExistence(timeout: 5))
        app.buttons["Make it easier"].tap()
        XCTAssertFalse(app.buttons["Save my next step"].isEnabled)
        let field = app.textFields["Easier experiment"]
        for _ in 0..<5 { if field.isHittable { break }; app.swipeUp() }
        field.tap(); field.typeText("A five-minute wind-down")
        let save = app.buttons["Save my next step"]
        reveal(save, in: app)
        XCTAssertTrue(save.isEnabled)
        capture("04-make-experiment-easier")
        save.tap()
        XCTAssertTrue(app.staticTexts["Preview only — no experiment changed."].waitForExistence(timeout: 3))
    }
}
