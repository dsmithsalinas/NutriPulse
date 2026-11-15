import XCTest

/// Fixture never authenticates, saves, requests Health permissions or calls AI.
final class OnboardingUITests: XCTestCase {
    private func app(step: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--onboarding-preview", "--onboarding-step", String(step)]
        app.launch()
        return app
    }
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 0.5) // Let the native button and sheet transitions settle.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testFiveScreenFlowAndOptionalSetupShortcuts() {
        let app = app()
        XCTAssertTrue(app.staticTexts["What would feel easier?"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
        app.switches["I’m 18 or older"].tap()
        XCTAssertTrue(app.buttons["Continue"].isEnabled)
        capture("01-support")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Your goal, in your words."].exists)
        capture("02-focus")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Set a starting point."].exists)
        capture("03-basics")
        app.buttons["Review my setup"].tap()
        XCTAssertTrue(app.staticTexts["Choose Pulse’s help."].exists)
        capture("04-permission")
        app.buttons["Review & allow Pulse"].tap()
        XCTAssertTrue(app.staticTexts["A starting point that’s yours."].exists)
        capture("05-ready")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Set nutrition targets")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Nutrition targets"].waitForExistence(timeout: 3))
        capture("06-edit-targets")
        let protein = app.textFields["Protein (g)"]
        protein.doubleTap()
        protein.typeText("130")
        XCTAssertEqual(protein.value as? String, "130")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "130g protein")).firstMatch.exists)
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Tell Pulse what matters")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your goal, in your words."].waitForExistence(timeout: 3))
        app.textViews["Your goal, in your words"].tap()
        app.textViews["Your goal, in your words"].typeText(" One step at a time.")
        capture("08-focus-keyboard")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "One step at a time.")).firstMatch.exists)
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Connect Apple Health")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Preview only — no Health permissions requested."].exists)
    }
    func testFullPrivacyDisclosureAndLargeTextRemainUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["--onboarding-preview", "--onboarding-step", "3", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Review & allow Pulse"].waitForExistence(timeout: 10))
        capture("09-large-text-permission")
        app.buttons["What is shared & privacy"].tap()
        XCTAssertTrue(app.staticTexts["AI data sharing"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Anthropic")).firstMatch.exists)
        capture("10-privacy-disclosure")
    }

    func testDecliningPulseAndSkippingFocusStillReachStart() {
        let app = app(step: 1)
        app.buttons["Skip for now"].tap()
        app.buttons["Review my setup"].tap()
        app.buttons["Continue without Pulse"].tap()
        XCTAssertTrue(app.buttons["Start with today"].exists)
        XCTAssertFalse(app.buttons["Save focus & start"].exists)
        capture("07-no-pulse")
        app.buttons["Start with today"].tap()
        XCTAssertTrue(app.staticTexts["What would feel easier?"].exists)
    }
    func testBasicsUsesPillsAndFeetInchesWithUnitRoundTrip() {
        let app = app(step: 2)
        XCTAssertTrue(app.textFields["onboarding-height-feet"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["onboarding-height-feet"].value as? String, "5")
        XCTAssertEqual(app.textFields["onboarding-height-inches"].value as? String, "6.9")
        app.buttons["Metric"].tap()
        XCTAssertEqual(app.textFields["Height (cm)"].value as? String, "170")
        app.buttons["Imperial"].tap()
        XCTAssertEqual(app.textFields["onboarding-height-feet"].value as? String, "5")
        XCTAssertEqual(app.textFields["onboarding-height-inches"].value as? String, "6.9")
        func replace(_ field: XCUIElement, with text: String) {
            field.tap()
            let old = field.value as? String ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
            if !text.isEmpty { field.typeText(text) }
        }
        replace(app.textFields["onboarding-height-feet"], with: "")
        XCTAssertFalse(app.buttons["Review my setup"].isEnabled)
        replace(app.textFields["onboarding-height-feet"], with: "6")
        replace(app.textFields["onboarding-height-inches"], with: "12")
        XCTAssertFalse(app.buttons["Review my setup"].isEnabled)
        replace(app.textFields["onboarding-height-inches"], with: "2")
        XCTAssertTrue(app.buttons["Review my setup"].isEnabled)
        app.swipeDown()
        app.buttons["Metric"].tap()
        XCTAssertEqual(app.textFields["Height (cm)"].value as? String, "188")
        app.buttons["Imperial"].tap()
        XCTAssertEqual(app.textFields["onboarding-height-feet"].value as? String, "6")
        XCTAssertEqual(app.textFields["onboarding-height-inches"].value as? String, "2")
        capture("basics-feet-inches")
        for _ in 0..<5 { if app.buttons["onboarding-Activity-light"].isHittable { break }; app.swipeUp() }
        app.buttons["onboarding-Activity-light"].tap()
        XCTAssertTrue(app.buttons["onboarding-Activity-light"].isSelected)
        for _ in 0..<5 { if app.buttons["onboarding-Weight direction-maintain"].isHittable { break }; app.swipeUp() }
        app.buttons["onboarding-Weight direction-maintain"].tap()
        XCTAssertTrue(app.buttons["onboarding-Weight direction-maintain"].isSelected)
        capture("basics-selected-pills")
        XCTAssertTrue(app.buttons["Review my setup"].isEnabled)
    }

    func testBasicsPillsFitAccessibilityText() {
        let app = XCUIApplication()
        app.launchArguments = ["--onboarding-preview", "--onboarding-step", "2", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let inches = app.textFields["onboarding-height-inches"]
        for _ in 0..<30 {
            if inches.isHittable { break }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(inches.isHittable)
        XCTAssertLessThanOrEqual(inches.frame.maxX, app.frame.maxX)
        capture("basics-height-accessibility-text")
        let choice = app.buttons["onboarding-Activity-moderate"]
        for _ in 0..<12 { if choice.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(choice.isHittable)
        XCTAssertGreaterThanOrEqual(choice.frame.height, 44)
        XCTAssertLessThanOrEqual(choice.frame.maxX, app.frame.maxX)
        capture("basics-pills-accessibility-text")
    }

}
