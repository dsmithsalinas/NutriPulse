import XCTest

/// Fixture-only layout checks. Never records audio, opens the camera or saves food.
final class FoodLoggingExpandedUITests: XCTestCase {
    private func rotate(_ orientation: UIDeviceOrientation, app: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        expectation(for: NSPredicate { _, _ in
            orientation == .portrait ? app.frame.height > app.frame.width : app.frame.width > app.frame.height
        }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
    }
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testSearchMealAndQuerySurviveMethodChangesAndRotation() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--log-preview", "--search-preview"]
        app.launch()
        let field = app.textFields["Search foods"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        rotate(.landscapeLeft, app: app)
        let talk = app.buttons["Talk"]
        let search = app.buttons["Search"]
        XCTAssertGreaterThan(search.frame.minY, talk.frame.maxY)
        for name in ["Talk", "Search", "Scan", "Favorites"] {
            XCTAssertGreaterThanOrEqual(app.buttons[name].frame.height + 0.001, 44)
        }
        XCTAssertGreaterThan(field.frame.minX, search.frame.maxX)
        XCTAssertTrue(app.buttons["Close"].isHittable)
        XCTAssertTrue(app.buttons["Log Protein pancakes 1"].isHittable)
        capture("food-expanded-search")
        let meal = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Meal: ")).firstMatch
        meal.tap()
        app.buttons["Dinner"].tap()
        XCTAssertTrue(app.buttons["Meal: Dinner"].exists)
        app.buttons["Favorites"].tap()
        app.buttons["Search"].tap()
        XCTAssertEqual(field.value as? String, "Kodiak")
        XCTAssertTrue(app.buttons["Meal: Dinner"].exists)
        field.tap()
        capture("food-expanded-search-keyboard")
        rotate(.portrait, app: app)
        XCTAssertEqual(field.value as? String, "Kodiak")
        XCTAssertTrue(app.buttons["Meal: Dinner"].exists)
        XCTAssertTrue(app.buttons["Close"].isHittable)
    }
    func testActualLoggingSheetHasExpandedTalkAndRetainsTypedDraft() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--tour", "--logging-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10))
        rotate(.landscapeLeft, app: app)
        let talk = app.buttons["Talk"]
        let search = app.buttons["Search"]
        XCTAssertGreaterThan(search.frame.minY, talk.frame.maxY)
        for name in ["Talk", "Search", "Scan", "Favorites"] {
            XCTAssertGreaterThanOrEqual(app.buttons[name].frame.height + 0.001, 44)
        }
        XCTAssertTrue(app.buttons["Talk to log your food"].isHittable)
        capture("food-expanded-talk")
        let field = app.descendants(matching: .any).matching(identifier: "Describe what you ate").firstMatch
        XCTAssertTrue(field.exists)
        field.tap()
        field.typeText("Greek yogurt with berries")
        rotate(.portrait, app: app)
        XCTAssertEqual(field.value as? String, "Greek yogurt with berries")
        rotate(.landscapeLeft, app: app)
        XCTAssertEqual(field.value as? String, "Greek yogurt with berries")
        XCTAssertTrue(app.buttons["Close"].isHittable)
    }
}
