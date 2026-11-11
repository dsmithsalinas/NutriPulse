import XCTest

/// Read-only portrait captures using local tour fixtures.
final class PortraitReviewCaptureUITests: XCTestCase {
    func testMainScreensInPortrait() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--tour", "--progress-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["mainTab-today"].waitForExistence(timeout: 15))
        XCTAssertGreaterThan(app.frame.height, app.frame.width)
        for screen in ["today", "progress", "pulse", "profile"] {
            app.buttons["mainTab-\(screen)"].tap()
            XCTAssertTrue(app.buttons["mainTab-\(screen)"].isSelected)
            Thread.sleep(forTimeInterval: 2)
            let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            capture.name = "portrait-\(screen)"
            capture.lifetime = .keepAlways
            add(capture)
        }
    }
}
