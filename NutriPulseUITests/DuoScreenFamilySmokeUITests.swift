import XCTest

/// Fixture-only coverage of secondary screen families. Does not save, grant permissions,
/// contact the coach, or submit authentication forms.
final class DuoScreenFamilySmokeUITests: XCTestCase {
    func testSecondaryFamiliesRotateWithoutLosingTheirScreen() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let cases: [([String], String)] = [
            (["--onboarding-preview", "--onboarding-step", "0"], "What would feel easier?"),
            (["--onboarding-preview", "--onboarding-step", "1"], "Your goal, in your words."),
            (["--onboarding-preview", "--onboarding-step", "2"], "Set a starting point."),
            (["--onboarding-preview", "--onboarding-step", "3"], "Choose Pulse’s help."),
            (["--onboarding-preview", "--onboarding-step", "4"], "A starting point that’s yours."),
            (["--goals-preview"], "Goals"),
            (["--water-preview"], "Add water"),
            (["--strong-week-preview"], "Your strong week"),
            (["--everyday-tools-preview"], "What would help right now?")
        ]
        for (arguments, title) in cases {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication()
            app.launchArguments = arguments
            app.launch()
            let heading = app.staticTexts[title].firstMatch
            XCTAssertTrue(heading.waitForExistence(timeout: 10), title)
            XCUIDevice.shared.orientation = .landscapeLeft
            expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
            waitForExpectations(timeout: 5)
            XCTAssertTrue(heading.exists, title)
            XCTAssertGreaterThanOrEqual(heading.frame.minX, 0, title)
            XCTAssertLessThanOrEqual(heading.frame.maxX, app.frame.maxX, title)
            let close = app.buttons["Close"].firstMatch
            if close.exists { XCTAssertTrue(close.isHittable, title) }
            app.terminate()
        }
    }
}
