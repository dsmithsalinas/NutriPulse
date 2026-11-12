import XCTest

final class PulseSupportToolsUITests: XCTestCase {
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        let scroll = app.scrollViews.containing(.any, identifier: "pulse.supportTools.toggle").firstMatch
        for _ in 0..<14 {
            if element.isHittable { return }
            if scroll.exists {
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.8)).press(forDuration: 0.1,
                    thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.4)), withVelocity: .slow, thenHoldForDuration: 0.1)
            } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }
    func testSupportToolsOpenWithoutAIConsentAndTodayIsClear() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--tour", "--pulse-preview", "--support-no-consent", "--support-tools-preview", "--compact-medication-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["mainTab-pulse"].waitForExistence(timeout: 10))
        let toggle = app.buttons["pulse.supportTools.toggle"]
        reveal(toggle, app: app)
        capture("pulse-support-collapsed-portrait")
        toggle.tap()
        let offScript = app.buttons["pulse.offScript"]
        reveal(offScript, app: app)
        capture("pulse-support-actions-portrait")
        offScript.tap()
        XCTAssertTrue(app.staticTexts["A sentence is enough."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Before Pulse replies"].exists)
        app.buttons["Close"].firstMatch.tap()
        let tools = app.buttons["pulse.everydayTools"]
        reveal(tools, app: app); tools.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Make today easier"].exists)
        app.buttons["Close"].tap()
        let lighter = app.buttons["pulse.lighterTracking"]
        reveal(lighter, app: app); lighter.tap()
        XCTAssertTrue(app.staticTexts["Goal reminders pause"].waitForExistence(timeout: 5))
        app.buttons["Close"].firstMatch.tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        reveal(tools, app: app)
        capture("pulse-support-expanded")
        app.buttons["mainTab-today"].tap()
        XCTAssertFalse(app.buttons["today.offScript"].exists)
        XCTAssertFalse(app.buttons["today.everydayTools"].exists)
        XCTAssertFalse(app.buttons["today.lighterTracking"].exists)
        XCUIDevice.shared.orientation = .portrait
        capture("today-without-support-actions")
        let meds = app.staticTexts["Stress Reset"]
        for _ in 0..<5 { if meds.isHittable { break }; app.swipeUp() }
        capture("today-medications-without-support-card")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["mainTab-pulse"].tap()
        let topic = app.buttons["Meal ideas"]
        reveal(topic, app: app); topic.tap()
        XCTAssertTrue(app.staticTexts["Before Pulse replies"].waitForExistence(timeout: 5))
        app.buttons["Close"].firstMatch.tap()
    }
    func testPulseOffKeepsNonAIToolsInProfileAndActivePauseOnToday() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--tour", "--support-pulse-off", "--support-tools-preview", "--lighter-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["mainTab-profile"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["mainTab-pulse"].exists)
        XCTAssertTrue(app.staticTexts["Lighter tracking is on"].exists)
        app.buttons["mainTab-profile"].tap()
        let toggle = app.buttons["profile.supportTools.toggle"]
        reveal(toggle, app: app); toggle.tap()
        let tools = app.buttons["profile.everydayTools"]
        reveal(tools, app: app)
        XCTAssertTrue(app.buttons["profile.offScript"].exists)
        capture("profile-support-pulse-off")
        tools.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertFalse(app.buttons["mainTab-pulse"].exists)
    }
}
