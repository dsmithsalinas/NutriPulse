import XCTest

final class RestaurantLoggingUITests: XCTestCase {
    private func launch(_ flags: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--log-preview"] + flags
        app.launch()
        return app
    }
    private func dismissKeyboardTip(_ app: XCUIApplication) {
        let tip = app.buttons["Continue"]
        if tip.waitForExistence(timeout: 1) { tip.tap() }
    }
    private func aboveKeyboard(_ element: XCUIElement, app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.keyboards.keys["space"].exists, "Actual typing keyboard must be visible", file: file, line: line)
        XCTAssertTrue(element.exists && element.isHittable, file: file, line: line)
        XCTAssertLessThanOrEqual(element.frame.maxY, app.keyboards.firstMatch.frame.minY + 1, file: file, line: line)
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testRestaurantPickerKeyboardAndSharedContext() {
        let app = launch(["--search-preview"])
        app.buttons["restaurantPickerOpen"].tap()
        let name = app.textFields["restaurantName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); dismissKeyboardTip(app); name.typeText("Chipotle")
        aboveKeyboard(name, app: app)
        aboveKeyboard(app.buttons["restaurantUse"], app: app)
        capture("restaurant-picker-keyboard")
        app.buttons["restaurantUse"].tap()
        XCTAssertTrue(app.buttons["restaurantPickerOpen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["restaurantClear"].exists)
        app.buttons["Talk"].tap()
        XCTAssertTrue(app.buttons["restaurantClear"].exists)
        let description = app.textFields["Describe what you ate"]
        XCTAssertTrue(description.waitForExistence(timeout: 5)); description.tap(); dismissKeyboardTip(app); description.typeText("A chicken bowl with rice")
        aboveKeyboard(description, app: app)
        let submit = app.buttons["Add from text"]
        if !submit.isHittable { app.swipeUp() }
        aboveKeyboard(submit, app: app)
        capture("restaurant-talk-keyboard")
        app.buttons["talkKeyboardDone"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }
    func testCustomIngredientKeyboardKeepsReviewAvailable() {
        let app = launch(["--restaurant-checklist-preview"])
        let other = app.buttons["ingredientSomethingElse"]
        XCTAssertTrue(other.waitForExistence(timeout: 8))
        for _ in 0..<5 { if other.isHittable { break }; app.swipeUp() }
        other.tap()
        let custom = app.textFields["ingredientCustomName"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5)); custom.tap(); dismissKeyboardTip(app); custom.typeText("Roasted vegetables")
        aboveKeyboard(custom, app: app)
        let add = app.buttons["ingredientCustomAdd"]
        if !add.isHittable { app.swipeUp() }
        aboveKeyboard(add, app: app)
        aboveKeyboard(app.buttons["ingredientReview"], app: app)
        capture("restaurant-checklist-keyboard")
        add.tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertTrue(app.buttons["ingredient-Roasted vegetables"].exists)
    }
}
