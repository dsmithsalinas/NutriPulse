import XCTest

/// Screenshot authoring only: production views populated with fictional, local fixtures.
/// Never signs in, grants permissions, purchases, or saves health/medication records.
final class AppStoreCaptureUITests: XCTestCase {
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSubmissionScreens() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--tour", "--progress-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["mainTab-today"].waitForExistence(timeout: 15))
        for (tab, name) in [("today", "01-today"), ("progress", "04-progress"), ("pulse", "03-pulse"), ("profile", "07-profile")] {
            app.buttons["mainTab-\(tab)"].tap()
            XCTAssertTrue(app.buttons["mainTab-\(tab)"].isSelected)
            Thread.sleep(forTimeInterval: 1)
            capture(name)
        }
        app.terminate()
        for (arguments, name) in [
            (["--log-preview", "--search-preview"], "02-food-search"),
            (["--shot-preview"], "05-shot-routine"),
            (["--water-preview"], "06-water")
        ] {
            app.launchArguments = arguments
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
            Thread.sleep(forTimeInterval: 2)
            capture(name)
            app.terminate()
        }
    }

    func testFoodAndCoachingAlternates() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        for (arguments, name) in [
            (["--store-today"], "01-today-simple"),
            (["--store-food"], "02-ai-food-review"),
            (["--log-preview", "--food-review-preview"], "08-food-detail"),
            (["--tour", "--pulse-preview", "--ring-chat-preview"], "03-pulse-conversation")
        ] {
            app.launchArguments = arguments
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
            Thread.sleep(forTimeInterval: 3)
            capture(name)
            app.terminate()
        }
    }
}
