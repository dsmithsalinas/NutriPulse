import XCTest

/// Uses fixture conversations only. Never sends a message or starts microphone capture.
final class PulseExpandedLayoutUITests: XCTestCase {
    private func launch(conversation: Bool) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--tour", "--pulse-preview"]
        if conversation { app.launchArguments.append("--ring-chat-preview") }
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Message Pulse").firstMatch.waitForExistence(timeout: 10))
        return app
    }

    private func expand(_ app: XCUIApplication) {
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        let sidebar = app.descendants(matching: .any).matching(identifier: "pulseSuggestionsPane").firstMatch
        let workspace = app.descendants(matching: .any).matching(identifier: "pulseConversationPane").firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(sidebar.frame.maxX, workspace.frame.minX + 1)
        XCTAssertGreaterThan(sidebar.frame.width, 200)
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testExpandedStartHasSuggestionsBesideComposer() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(conversation: false)
        expand(app)
        XCTAssertTrue(app.staticTexts["Explore with Pulse"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Message Pulse").firstMatch.isHittable)
        capture("pulse-expanded-start")
    }

    func testConversationAndDraftSurviveCollapseAndExpansion() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(conversation: true)
        expand(app)
        XCTAssertTrue(app.buttons["New topic"].exists)
        // Scroll the transcript without moving the independently scrolling suggestions.
        let transcript = app.scrollViews.containing(.staticText, identifier: "Not very hungry tonight. What's easy?").firstMatch
        transcript.swipeDown()
        transcript.swipeDown()
        XCTAssertTrue(app.staticTexts["Not very hungry tonight. What's easy?"].exists)
        capture("pulse-expanded-conversation")
        let field = app.descendants(matching: .any).matching(identifier: "Message Pulse").firstMatch
        field.tap()
        field.typeText("Keep this draft")
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate { _, _ in app.frame.height > app.frame.width }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(field.value as? String, "Keep this draft")
        XCTAssertTrue(app.buttons["New topic"].exists)
        app.buttons["Hide keyboard"].tap()
        expand(app)
        XCTAssertEqual(field.value as? String, "Keep this draft")
        XCTAssertTrue(app.buttons["New topic"].exists)
        capture("pulse-expanded-draft")
    }
}
