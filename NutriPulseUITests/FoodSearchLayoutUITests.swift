import XCTest

final class FoodSearchLayoutUITests: XCTestCase {
    func testTypingMakesRoomForSeveralResults() {
        let app = XCUIApplication()
        app.launchArguments = ["--log-preview", "--search-preview"]
        app.launch()
        let field = app.textFields["Search foods"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Just leave a meal note"].exists)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Just leave a meal note"].exists)
        XCTAssertFalse(app.buttons["Talk"].exists)
        let keyboardTop = app.keyboards.firstMatch.frame.minY
        for index in 1...3 {
            let row = app.buttons["Log Protein pancakes \(index)"]
            XCTAssertTrue(row.exists)
            XCTAssertLessThanOrEqual(row.frame.maxY, keyboardTop)
            XCTAssertTrue(row.isHittable)
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "search-keyboard-open"; shot.lifetime = .keepAlways; add(shot)
        field.typeText("\n")
        XCTAssertTrue(app.buttons["Just leave a meal note"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Talk"].exists)
    }
}
