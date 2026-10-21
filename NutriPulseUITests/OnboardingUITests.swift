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
}
