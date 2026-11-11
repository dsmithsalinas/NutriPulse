import XCTest

/// Gallery coverage is read-only. It never submits authentication, permission,
/// notification, dose, deletion, consent, or save actions.
final class DuoCompleteAuditUITests: XCTestCase {
    private let screens = ["auth", "password-help", "password-reset", "profile-recovery", "calendar", "body", "weight-history", "fat-history", "lean-history", "body-goals", "body-entry", "workout", "edit-food", "analytics", "experiments", "about-you", "food-access", "feedback", "notifications", "notification-history", "dose-history", "medications", "medication-editor", "medication-history", "food-consent", "pulse-consent", "memory-editor", "offline-notes", "usual-save", "lighter-tracking", "shot-check-in", "protein-rescue", "recipe"]
    private func launch(_ screen: String, large: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--duo-audit-screen", screen]
        if screen == "analytics" { app.launchArguments += ["--progress-preview"] }
        if ["weight-history", "fat-history", "lean-history", "waist-history"].contains(screen) { app.launchArguments += ["--duo-audit-populated"] }
        if screen == "experiments" { app.launchArguments += ["--goals-preview"] }
        if screen.hasPrefix("tools-") { app.launchArguments += ["--everyday-tools-preview", "--" + screen] }
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }
    private func landscape(_ app: XCUIApplication) {
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
    }
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 0.5)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testAllSecondaryScreensExpanded() {
        defer { XCUIDevice.shared.orientation = .portrait }
        for screen in screens {
            let app = launch(screen)
            landscape(app)
            if app.alerts.firstMatch.exists {
                capture("audit-error-" + screen)
                if app.alerts.buttons["Not Now"].exists { app.alerts.buttons["Not Now"].tap() }
                else if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
            }
            capture("audit-" + screen)
            XCTAssertFalse(app.staticTexts["Unknown audit screen: \(screen)"].exists)
            let cancel = app.buttons["Cancel"].firstMatch
            if cancel.exists { XCTAssertTrue(cancel.isHittable, screen) }
            app.terminate()
        }
    }
    func testNestedScreensExpanded() {
        defer { XCUIDevice.shared.orientation = .portrait }
        for screen in ["health-link", "observation", "experiment-wrap", "goal-builder", "tools-data", "tools-memories", "tools-experiment", "tools-library", "tools-leftovers", "tools-decision", "experiment-create", "loading", "profile-edit", "targets-edit", "dose-edit", "notification-explainer", "goal-completed", "goal-day", "goal-detail", "medication-conflict", "medication-correction", "usual-review", "restaurant-picker", "breakfast-settings"] {
            let app = launch(screen)
            landscape(app)
            capture("audit-" + screen)
            app.terminate()
        }
    }
    func testMedicationDraftAndFeedbackCategorySurviveRotation() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let medication = launch("medication-editor")
        let name = medication.textFields["medicationName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Vitamin D")
        medication.buttons["medicationKeyboardDone"].tap()
        landscape(medication)
        XCTAssertEqual(name.value as? String, "Vitamin D")
        capture("audit-medication-draft")
        medication.terminate()
        let feedback = launch("feedback", large: true)
        landscape(feedback)
        let category = feedback.buttons["feedbackCategorybug"]
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        category.tap()
        let editor = feedback.textViews.firstMatch
        for _ in 0..<5 {
            if editor.isHittable { break }
            feedback.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8))
                .press(forDuration: 0.1, thenDragTo: feedback.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.25)), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        editor.tap(); editor.typeText("Please keep this draft.")
        feedback.buttons["feedbackKeyboardDone"].tap()
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate { _, _ in feedback.frame.height > feedback.frame.width }, evaluatedWith: feedback)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(editor.value as? String, "Please keep this draft.")
        landscape(feedback)
        XCTAssertEqual(editor.value as? String, "Please keep this draft.")
        for _ in 0..<5 {
            if category.isHittable { break }
            feedback.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.25))
                .press(forDuration: 0.1, thenDragTo: feedback.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(category.isSelected)
        capture("audit-feedback-draft")
        capture("audit-large-feedback")
    }
    func testCalendarLastWeekAndSelectionSurviveRotation() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("calendar")
        landscape(app)
        let previous = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Previous")).firstMatch
        XCTAssertTrue(previous.waitForExistence(timeout: 5))
        previous.tap()
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let lastDay = Calendar.current.range(of: .day, in: .month, for: previousMonth)!.count
        let last = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", String(lastDay))).firstMatch
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<5 { if last.isHittable { break }; scroll.swipeUp() }
        XCTAssertTrue(last.isHittable)
        last.tap()
        capture("audit-calendar-last-week")
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate { _, _ in app.frame.height > app.frame.width }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        landscape(app)
        XCTAssertTrue(last.isSelected)
    }
    func testPopulatedChartsAndEmbeddedObservationExpanded() {
        defer { XCUIDevice.shared.orientation = .portrait }
        for screen in ["weight-history", "fat-history", "lean-history", "waist-history", "observation"] {
            let app = launch(screen)
            landscape(app)
            capture("audit-" + screen)
            app.terminate()
        }
        let app = launch("analytics")
        landscape(app)
        let questions = app.scrollViews["analyticsQuestions"]
        XCTAssertTrue(questions.waitForExistence(timeout: 5))
        capture("audit-analytics")
        let titles = ["How do shot days change my eating?", "Where does my protein come from?", "Is my weight trend real?", "Am I hitting protein and calories?", "Am I moving more?", "How's my body composition?"]
        for (index, title) in titles.enumerated() {
            let chip = app.buttons[title]
            for _ in 0..<7 { if chip.isHittable { break }; questions.swipeLeft() }
            XCTAssertTrue(chip.isHittable)
            chip.tap()
            XCTAssertTrue(chip.isSelected)
            capture("audit-analytics-\(index)")
        }
    }
    func testOnboardingFocusEditorExpanded() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--onboarding-preview", "--onboarding-step", "4"]
        app.launch()
        let edit = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Tell Pulse what matters")).firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        landscape(app)
        let editor = app.textViews["Your goal, in your words"]
        XCTAssertTrue(editor.exists)
        XCTAssertLessThanOrEqual(editor.frame.width, 600)
        XCTAssertTrue(app.buttons["Done"].isHittable)
        capture("audit-onboarding-focus")
    }
    func testFeedbackLargestTextChoicesRemainVisible() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch("feedback", large: true)
        landscape(app)
        for option in ["bug", "idea", "general"] {
            let choice = app.buttons["feedbackCategory" + option]
            XCTAssertTrue(choice.isHittable)
            XCTAssertGreaterThanOrEqual(choice.frame.height, 44)
        }
        capture("audit-large-feedback")
    }
    func testPrimaryActionsRemainReachable() {
        defer { XCUIDevice.shared.orientation = .portrait }
        for (screen, label) in [("auth", "Sign In"), ("password-help", "Send reset link"), ("password-reset", "Update password"), ("medication-editor", "Save item"), ("usual-save", "Save usual meal")] {
            let app = launch(screen)
            landscape(app)
            if screen == "medication-editor" {
                let name = app.textFields["medicationName"]
                name.tap(); name.typeText("Sample supplement")
                app.buttons["medicationKeyboardDone"].tap()
            }
            let action = app.buttons[label]
            let scroll = app.scrollViews.firstMatch
            for _ in 0..<10 {
                if action.isHittable { break }
                if screen == "medication-editor" {
                    scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                        .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)), withVelocity: .slow, thenHoldForDuration: 0.2)
                } else {
                    app.swipeUp()
                }
            }
            if action.exists { print("Audit action \(screen): frame=\(action.frame) enabled=\(action.isEnabled), scroll=\(scroll.frame)") }
            XCTAssertTrue(action.isHittable, screen)
            capture("audit-action-" + screen)
            app.terminate()
        }
    }
    func testShortWindowLargeTextRecoveryAndForms() {
        defer { XCUIDevice.shared.orientation = .portrait }
        for screen in ["loading", "profile-recovery", "calendar", "feedback", "medication-editor", "body-entry", "shot-check-in", "goal-completed", "notification-explainer", "medication-conflict", "tools-data"] {
            let app = launch(screen, large: true)
            landscape(app)
            capture("audit-large-" + screen)
            if screen == "profile-recovery" {
                let retry = app.buttons["Try Again"]
                for _ in 0..<3 { if retry.isHittable { break }; app.swipeUp() }
                XCTAssertTrue(retry.isHittable)
                let signOut = app.buttons["Sign Out"]
                for _ in 0..<5 { if signOut.isHittable { break }; app.swipeUp() }
                XCTAssertTrue(signOut.isHittable)
                capture("audit-large-recovery-actions")
            }
            app.terminate()
        }
    }
}
