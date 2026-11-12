import XCTest

final class NutritionImportUITests: XCTestCase {
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testSourceSelectionAndExpandedSettings() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--duo-audit-screen", "nutrition"]
        app.launch()
        let carbs = app.buttons["nutrition-source-carbs"]
        XCTAssertTrue(carbs.waitForExistence(timeout: 10))
        XCTAssertTrue(carbs.label.contains("Diabetes tracker"))
        capture("nutrition-sources-portrait")
        carbs.tap()
        app.buttons["nutrition-choice-carbs-footing"].tap()
        XCTAssertTrue(carbs.label.contains("Footing"))
        carbs.tap()
        app.buttons["nutrition-choice-carbs-demo.diabetes"].tap()
        XCTAssertTrue(carbs.label.contains("Diabetes tracker"))
        XCTAssertTrue(app.staticTexts["142g today · via Apple Health"].exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(carbs.isHittable)
        XCTAssertTrue(carbs.label.contains("Diabetes tracker"))
        capture("nutrition-sources-expanded")
    }
    func testLargestTextKeepsSourceAndDoneReachable() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--duo-audit-screen", "nutrition", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let carbs = app.buttons["nutrition-source-carbs"]
        XCTAssertTrue(carbs.waitForExistence(timeout: 10))
        let scroll = app.scrollViews["nutritionChoices"]
        for _ in 0..<24 {
            if carbs.isHittable { break }
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.78))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.4)), withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        XCTAssertTrue(carbs.isHittable)
        XCTAssertGreaterThanOrEqual(carbs.frame.height, 44)
        XCTAssertTrue(app.buttons["Done"].isHittable)
        capture("nutrition-sources-large-text")
    }
    func testUnavailableSelectedSourceStaysUnknown() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--duo-audit-screen", "nutrition", "--nutrition-missing-preview"]
        app.launch()
        XCTAssertTrue(app.staticTexts["No data today from Diabetes tracker"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["nutrition-source-carbs"].label.contains("Diabetes tracker"))
        capture("nutrition-no-data-portrait")
    }
    func testTodayUsesImportedCarbsWithoutAddingMealCarbs() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--tour", "--nutrition-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["mainTab-today"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "142g")).firstMatch.exists)
        let macros = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Carbs 142 grams logged")).firstMatch
        XCTAssertTrue(macros.exists)
        capture("nutrition-today-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1)
        capture("nutrition-today-expanded")
    }
}
