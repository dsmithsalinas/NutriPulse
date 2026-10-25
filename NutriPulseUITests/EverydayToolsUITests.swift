import XCTest

final class EverydayToolsUITests: XCTestCase {
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testChooserAndEditableExamples() {
        let app = XCUIApplication()
        app.launchArguments = ["--everyday-tools-preview"]
        app.launch()
        XCTAssertTrue(app.staticTexts["What would help right now?"].waitForExistence(timeout: 10))
        capture("01-tools")
        app.buttons.containing(.staticText, identifier: "Try a small change").firstMatch.tap()
        XCTAssertFalse(app.buttons["Start experiment"].isEnabled)
        app.buttons["After-lunch walk"].tap()
        XCTAssertTrue(app.buttons["Start experiment"].isEnabled)
        XCTAssertEqual(app.textFields["Try"].value as? String, "A short walk after lunch")
        capture("02-experiment")
        app.buttons["Back to tools"].tap()
        app.buttons.containing(.staticText, identifier: "Remember what helps").firstMatch.tap()
        XCTAssertFalse(app.buttons["Review memory"].isEnabled)
        app.buttons["Busy mornings"].tap()
        XCTAssertFalse(app.buttons["Review memory"].isEnabled)
        capture("03-memory")
        app.buttons["Back to tools"].tap()
        app.buttons.containing(.staticText, identifier: "Save leftovers").firstMatch.tap()
        XCTAssertFalse(app.buttons["Save leftovers"].isEnabled)
        app.buttons["Half a wrap"].tap()
        XCTAssertTrue(app.buttons["Save leftovers"].isEnabled)
        capture("04-leftovers")
        app.buttons["Back to tools"].tap()
        app.buttons.containing(.staticText, identifier: "Get one idea").firstMatch.tap()
        XCTAssertFalse(app.buttons["Ask Pulse for one idea"].isEnabled)
        app.buttons["Short on time"].tap()
        XCTAssertTrue(app.buttons["Ask Pulse for one idea"].isEnabled)
        capture("05-decision")
    }
    func testLargeTextTaskRemainsScrollable() {
        let app = XCUIApplication()
        app.launchArguments = ["--everyday-tools-preview", "--tools-leftovers", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Save a little for later."].waitForExistence(timeout: 10))
        app.buttons["Half a wrap"].tap()
        for _ in 0..<5 {
            if app.buttons["Save leftovers"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["Save leftovers"].isHittable)
        XCTAssertTrue(app.buttons["Save leftovers"].isEnabled)
        capture("06-large-text")
        app.buttons["Back to tools"].tap()
        XCTAssertTrue(app.staticTexts["What would help right now?"].exists)
    }

}
