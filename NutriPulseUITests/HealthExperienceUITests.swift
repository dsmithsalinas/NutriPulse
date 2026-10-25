import XCTest

final class HealthExperienceUITests: XCTestCase {
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testHealthLinkIsOptionalAndDefaultsToManual() {
        let app = XCUIApplication()
        app.launchArguments = ["--everyday-tools-preview", "--tools-experiment"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Start with a small idea."].waitForExistence(timeout: 10))
        app.buttons["Wind-down"].tap()
        let toggle = app.switches["Use Apple Health observations"]
        for _ in 0..<4 { if toggle.isHittable { break }; app.swipeUp() }
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        XCTAssertTrue(app.buttons["Sleep after each day"].exists || app.staticTexts["Sleep after each day"].exists)
        capture("01-health-link")
    }

    func testExperimentDetailOpensFromExperiments() {
        let app = XCUIApplication()
        app.launchArguments = ["--everyday-tools-preview", "--tools-experiment", "--tools-health"]
        app.launch()
        let summary = app.buttons["health-summary-Health observations"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        for _ in 0..<4 { if summary.isHittable { break }; app.swipeUp() }
        summary.tap()
        XCTAssertTrue(app.staticTexts["Recorded sleep"].waitForExistence(timeout: 5))
        capture("02-experiment-detail")
        let confirm = app.buttons["Add how it went"]
        for _ in 0..<5 { if confirm.isHittable { break }; app.swipeUp() }
        confirm.tap()
        XCTAssertFalse(app.buttons["Save observation"].firstMatch.isEnabled)
    }
    func testPulseCardsOpenDetailsAndExperimentsWithoutStartingChat() {
        let app = XCUIApplication()
        app.launchArguments = ["--pulse-health-preview", "--pulse-preview"]
        app.launch()
        let experiment = app.buttons["health-summary-Your small experiment"]
        XCTAssertTrue(experiment.waitForExistence(timeout: 10))
        capture("01-pulse-summary-cards")
        experiment.tap()
        XCTAssertTrue(app.staticTexts["Recorded sleep"].waitForExistence(timeout: 5))
        capture("03-experiment-from-pulse")
        let manage = app.buttons["Open Experiments"]
        for _ in 0..<6 { if manage.isHittable { break }; app.swipeUp() }
        manage.tap()
        XCTAssertTrue(app.staticTexts["Personal experiments"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["health-summary-Health observations"].exists)
        app.buttons["Close"].firstMatch.tap()
        let cycle = app.buttons["health-summary-Your shot-cycle picture"]
        for _ in 0..<6 { if cycle.isHittable { break }; app.swipeUp() }
        cycle.tap()
        XCTAssertTrue(app.staticTexts["A little context for today."].waitForExistence(timeout: 5))
        capture("04-cycle-detail")
        for _ in 0..<5 { if app.staticTexts["3 earlier cycles"].exists { break }; app.swipeUp() }
        XCTAssertTrue(app.staticTexts["3 earlier cycles"].exists)
        for _ in 0..<5 { if app.buttons["Close"].firstMatch.isHittable { break }; app.swipeDown() }
        app.buttons["Close"].firstMatch.tap()
        let week = app.buttons["health-summary-Beyond the scale"]
        for _ in 0..<6 { if week.isHittable { break }; app.swipeUp() }
        week.tap()
        XCTAssertTrue(app.staticTexts["Your week is more than a number."].waitForExistence(timeout: 5))
        capture("05-week-detail")
        let how = app.buttons["How Footing worked this out"]
        for _ in 0..<5 { if how.isHittable { break }; app.swipeUp() }
        how.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "aren’t sent to Pulse")).firstMatch.exists)
    }
    func testPulseHealthCardsAndDetailAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--pulse-health-preview", "--pulse-preview", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let week = app.buttons["health-summary-Beyond the scale"]
        XCTAssertTrue(week.waitForExistence(timeout: 10))
        for _ in 0..<12 { if week.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        week.tap()
        XCTAssertTrue(app.staticTexts["Your week is more than a number."].waitForExistence(timeout: 5))
        capture("06-large-text-week")
    }

}
