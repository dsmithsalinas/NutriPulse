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

    func testSearchDraftSurvivesRotationWithKeyboardOpen() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--log-preview", "--search-preview"]
        app.launch()
        let field = app.textFields["Search foods"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(" oats")
        let draft = field.value as? String
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in app.frame.width > app.frame.height }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(field.value as? String, draft)
        XCTAssertTrue(field.isHittable)
        XCTAssertTrue(app.buttons["Close"].isHittable)
        let landscapeShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscapeShot.name = "landscape-search-draft"; landscapeShot.lifetime = .keepAlways; add(landscapeShot)
        XCUIDevice.shared.orientation = .portrait
        let portrait = NSPredicate { _, _ in app.frame.height > app.frame.width }
        expectation(for: portrait, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(field.value as? String, draft)
        app.buttons["Clear search"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(field.isHittable)
        XCTAssertTrue(app.buttons["Close"].isHittable)
    }

    func testSelectedTabAndLogActionSurviveRotation() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--tour"]
        app.launch()
        let profile = app.buttons["mainTab-profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in app.frame.width > app.frame.height }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(profile.isSelected)
        let landscapeShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscapeShot.name = "landscape-profile-navigation"; landscapeShot.lifetime = .keepAlways; add(landscapeShot)
        for name in ["today", "progress", "pulse", "profile"] {
            let button = app.buttons["mainTab-\(name)"]
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        app.buttons["Log food"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Search"].isHittable)
    }

}
