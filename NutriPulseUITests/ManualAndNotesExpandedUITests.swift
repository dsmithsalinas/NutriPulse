import XCTest

/// Read-only launch routes; these tests never invoke a save.
final class ManualAndNotesExpandedUITests: XCTestCase {
    private func launch(notes: Bool, large: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = notes ? ["--log-preview", "--meal-note-preview", "--notes-layout-preview"] : ["--log-preview", "--manual-layout-preview"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }
    private func rotate(_ orientation: UIDeviceOrientation, _ app: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        expectation(for: NSPredicate { _, _ in orientation == .portrait ? app.frame.height > app.frame.width : app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func dismissKeyboard(_ app: XCUIApplication, id: String) {
        app.buttons[id].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
        waitForExpectations(timeout: 5)
    }
    func testManualExpandedFieldsKeyboardAndDraftRetention() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(notes: false)
        let name = app.textFields["Food name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap(); name.typeText("Homemade chicken bowl")
        dismissKeyboard(app, id: "manualKeyboardDone")
        rotate(.landscapeLeft, app)
        let calories = app.textFields["manualCalories"]
        XCTAssertTrue(calories.isHittable)
        XCTAssertGreaterThan(calories.frame.minX, name.frame.maxX)
        calories.tap(); calories.typeText("420")
        XCTAssertTrue(app.buttons["manualKeyboardDone"].isHittable)
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        XCTAssertLessThanOrEqual(calories.frame.maxY, app.buttons["Log 1 × Homemade chicken bowl"].frame.minY + 1)
        capture("manual-expanded-keyboard")
        dismissKeyboard(app, id: "manualKeyboardDone")
        capture("manual-expanded")
        rotate(.portrait, app)
        XCTAssertEqual(name.value as? String, "Homemade chicken bowl")
        rotate(.landscapeLeft, app)
        XCTAssertEqual(calories.value as? String, "420")
        XCTAssertTrue(app.buttons["Log 1 × Homemade chicken bowl"].isHittable)
    }
    func testMealNoteExpandedEditorKeyboardAndDraftRetention() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(notes: true)
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        rotate(.landscapeLeft, app)
        editor.tap(); editor.typeText("Lunch out with friends. I kept it simple.")
        XCTAssertTrue(app.buttons["mealNoteKeyboardDone"].isHittable)
        XCTAssertTrue(editor.isHittable)
        XCTAssertLessThanOrEqual(editor.frame.maxY, app.keyboards.firstMatch.frame.minY)
        let typingArea = app.scrollViews["mealNoteContent"]
        XCTAssertGreaterThanOrEqual(editor.frame.minY + 1, typingArea.frame.minY)
        XCTAssertLessThanOrEqual(editor.frame.maxY, typingArea.frame.maxY + 1)
        capture("meal-note-expanded-keyboard")
        dismissKeyboard(app, id: "mealNoteKeyboardDone")
        let content = app.scrollViews["mealNoteContent"]
        content.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.25))
            .press(forDuration: 0.1, thenDragTo: content.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.85)), withVelocity: .slow, thenHoldForDuration: 0.2)
        capture("meal-note-expanded")
        rotate(.portrait, app)
        XCTAssertEqual(editor.value as? String, "Lunch out with friends. I kept it simple.")
        rotate(.landscapeLeft, app)
        XCTAssertEqual(editor.value as? String, "Lunch out with friends. I kept it simple.")
        XCTAssertTrue(app.buttons["Save meal note"].isHittable)
    }
    func testLargestTextKeepsManualAndNoteActionsReachable() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let manual = launch(notes: false, large: true)
        XCTAssertTrue(manual.buttons["Cancel"].waitForExistence(timeout: 10))
        rotate(.landscapeLeft, manual)
        XCTAssertTrue(manual.buttons["Cancel"].isHittable)
        XCTAssertTrue(manual.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Log 1 ×")).firstMatch.isHittable)
        manual.terminate()
        let notes = launch(notes: true, large: true)
        XCTAssertTrue(notes.buttons["Save meal note"].waitForExistence(timeout: 10))
        rotate(.landscapeLeft, notes)
        XCTAssertTrue(notes.buttons["Save meal note"].isHittable)
    }
}
