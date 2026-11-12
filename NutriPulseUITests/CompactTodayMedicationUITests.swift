import XCTest

final class CompactTodayMedicationUITests: XCTestCase {
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testTodayHasNoProteinGapAndShowsCompactRoutine() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--tour", "--compact-medication-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["mainTab-today"].waitForExistence(timeout: 10))
        let protein = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Protein 85 grams logged.")).firstMatch
        let calories = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Calories ")).firstMatch
        XCTAssertTrue(protein.waitForExistence(timeout: 5))
        XCTAssertEqual(protein.frame.maxY, calories.frame.maxY, accuracy: 2)
        capture("today-compact-portrait")
        let section = app.descendants(matching: .any).matching(identifier: "medicationsToday").firstMatch
        for _ in 0..<5 { if section.isHittable && app.staticTexts["Stress Reset"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Stress Reset"].isHittable)
        XCTAssertLessThan(section.frame.height, 300)
        capture("today-medications-compact-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        app.swipeDown(); app.swipeDown()
        XCTAssertEqual(protein.frame.maxY, calories.frame.maxY, accuracy: 2)
        capture("today-compact-expanded")
    }
    func testCompactDoseActionsRemainIndependentAndUndoable() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--duo-audit-screen", "medications-compact"]
        app.launch()
        XCTAssertTrue(app.staticTexts["2 of 4 taken"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts.matching(identifier: "NAC").count, 1)
        capture("medications-two-items-four-doses")
        func dose(_ name: String, _ status: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@ AND label ENDSWITH %@", "compactMedicationDose-", name + ",", status)).firstMatch
        }
        dose("NAC", "Not logged").tap()
        app.buttons["compactMedicationTaken"].tap()
        XCTAssertTrue(app.staticTexts["3 of 4 taken"].exists)
        XCTAssertTrue(dose("Stress Reset", "Not logged").exists)
        dose("Stress Reset", "Not logged").tap()
        app.buttons["compactMedicationSkip"].tap()
        XCTAssertTrue(app.staticTexts["Today complete · 3 taken, 1 skipped"].exists)
        app.buttons["Review doses"].tap()
        dose("Stress Reset", "Skipped").tap()
        app.buttons["compactMedicationUndo"].tap()
        XCTAssertTrue(app.staticTexts["3 of 4 taken"].exists)
        XCTAssertTrue(dose("Stress Reset", "Not logged").exists)
    }
    func testCompactRoutineLargeTextAndRotation() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--duo-audit-screen", "medications-compact", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let dose = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "compactMedicationDose-")).firstMatch
        XCTAssertTrue(dose.waitForExistence(timeout: 10))
        for _ in 0..<10 { if dose.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(dose.isHittable)
        XCTAssertGreaterThanOrEqual(dose.frame.height, 43.9)
        capture("medications-compact-large-text")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.staticTexts["2 of 4 taken"].exists)
    }
}
