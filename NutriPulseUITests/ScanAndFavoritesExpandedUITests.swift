import XCTest

/// Read-only fixtures: never requests camera permission, opens Settings or logs food.
final class ScanAndFavoritesExpandedUITests: XCTestCase {
    private func launch(_ flag: String, largeText: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--log-preview", flag]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10))
        return app
    }
    private func rotate(_ orientation: UIDeviceOrientation, app: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        expectation(for: NSPredicate { _, _ in
            orientation == .portrait ? app.frame.height > app.frame.width : app.frame.width > app.frame.height
        }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
    }
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testScanPreviewFitsBesideMethodsAndRetainsMeal() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("--scan-preview")
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.staticTexts["Simulated camera preview"].exists)
        let instruction = app.staticTexts["Align barcode within the frame"]
        XCTAssertGreaterThan(instruction.frame.minX, app.buttons["Scan"].frame.maxX)
        XCTAssertLessThanOrEqual(instruction.frame.maxY, app.frame.maxY - 20)
        XCTAssertTrue(app.buttons["Close"].isHittable)
        capture("food-expanded-scan")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Meal: ")).firstMatch.tap()
        app.buttons["Dinner"].tap()
        rotate(.portrait, app: app)
        XCTAssertTrue(app.buttons["Meal: Dinner"].exists)
        XCTAssertTrue(instruction.exists)
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.buttons["Meal: Dinner"].exists)
        XCTAssertTrue(app.buttons["Scan"].isSelected)
    }
    func testScanPermissionFallbackRemainsReachable() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("--scan-denied-preview")
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(app.staticTexts["Camera Access Required"].exists)
        XCTAssertTrue(app.buttons["Open Settings"].isHittable)
        XCTAssertTrue(app.buttons["Close"].isHittable)
        capture("food-expanded-scan-permission")
    }
    func testFavoritesGridAndMethodSelectionSurviveRotation() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("--favorites-preview")
        rotate(.landscapeLeft, app: app)
        let shake = app.buttons["Log Protein shake"]
        let yogurt = app.buttons["Log Greek yogurt, berries & granola"]
        XCTAssertTrue(shake.waitForExistence(timeout: 5))
        XCTAssertTrue(shake.isHittable)
        XCTAssertTrue(yogurt.isHittable)
        XCTAssertGreaterThan(yogurt.frame.minX, shake.frame.maxX)
        XCTAssertGreaterThanOrEqual(shake.frame.height + 0.001, 44)
        capture("food-expanded-favorites")
        app.buttons["Talk"].tap()
        app.buttons["Favorites"].tap()
        XCTAssertTrue(shake.waitForExistence(timeout: 5))
        rotate(.portrait, app: app)
        XCTAssertTrue(app.buttons["Favorites"].isSelected)
        XCTAssertTrue(shake.exists)
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(shake.isHittable)
        XCTAssertTrue(app.buttons["Close"].isHittable)
    }
    func testFavoritesLargeTextUsesReachableFullWidthCards() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("--favorites-preview", largeText: true)
        rotate(.landscapeLeft, app: app)
        let shake = app.buttons["Log Protein shake"]
        let yogurt = app.buttons["Log Greek yogurt, berries & granola"]
        XCTAssertTrue(shake.waitForExistence(timeout: 5))
        let shakeX = shake.frame.minX
        let content = app.scrollViews.containing(.button, identifier: "Log Protein shake").firstMatch
        for _ in 0..<5 {
            if yogurt.isHittable { break }
            content.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.75))
                .press(forDuration: 0.1, thenDragTo: content.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.45)), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(yogurt.isHittable)
        XCTAssertGreaterThanOrEqual(yogurt.frame.height + 0.001, 44)
        XCTAssertEqual(yogurt.frame.minX, shakeX, accuracy: 1)
        capture("food-favorites-large-text")
    }
}
