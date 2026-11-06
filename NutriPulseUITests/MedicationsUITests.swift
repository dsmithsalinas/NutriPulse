import XCTest

final class MedicationsUITests: XCTestCase {
    private let root = URL(fileURLWithPath: "/private/tmp/footing-medications-e2e")
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }
    private func openSettings(_ app: XCUIApplication) {
        let profile = app.buttons["mainTab-profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10)); profile.tap()
        let entry = app.buttons["profileMedications"]
        reveal(entry, in: app); entry.tap()
        XCTAssertTrue(app.switches["medicationsEnabled"].waitForExistence(timeout: 10))
    }
    private func addItem(_ app: XCUIApplication, name: String, amount: String, weekdays: Bool = false) {
        let add = app.buttons["medicationsAdd"]; reveal(add, in: app); add.tap()
        let nameField = app.textFields["medicationName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5)); nameField.tap(); nameField.typeText(name)
        let amountField = app.textFields["medicationAmount"]; amountField.tap(); amountField.typeText(amount)
        app.buttons["medicationKeyboardDone"].tap()
        if weekdays {
            let selected = app.buttons["Selected days"]; reveal(selected, in: app); selected.tap()
            app.buttons["Sun"].tap(); app.buttons["Sat"].tap()
        }
        let addTime = app.buttons["medicationAddTime"]; reveal(addTime, in: app); addTime.tap()
        capture("medications-setup-\(name.replacingOccurrences(of: " ", with: "-"))")
        let save = app.buttons["medicationSave"]; reveal(save, in: app); save.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        XCTAssertTrue(app.buttons["medicationsAdd"].waitForExistence(timeout: 10))
    }
    func testProfileSetupTodayHistoryPersistenceAndNotificationAction() throws {
        let credentials = root.appendingPathComponent("ios-credentials.json")
        guard FileManager.default.fileExists(atPath: credentials.path) else { throw XCTSkip("Requires disposable medication fixture") }
        struct User: Decodable { var email: String; var password: String }
        struct Fixture: Decodable { var projectRef: String; var ui: User }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: credentials))
        guard fixture.projectRef == "dcabdzuhuixlcgwavtsc", fixture.ui.email.hasPrefix("footing-medications-e2e-")
        else { XCTFail("Invalid fixture"); return }
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "Expected test sign-in and notification prompts") { alert in
            if alert.buttons["Not Now"].exists { alert.buttons["Not Now"].tap(); return true }
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        let app = XCUIApplication(); app.launch()
        let email = app.textFields["Email"]
        XCTAssertTrue(email.waitForExistence(timeout: 15), "Use a clean simulator; never replace a personal session")
        email.tap(); email.typeText(fixture.ui.email)
        let password = app.secureTextFields["Password"]; password.tap(); password.typeText(fixture.ui.password)
        app.buttons["Sign In"].tap()
        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 20))
        if app.buttons["Not Now"].waitForExistence(timeout: 3) { app.buttons["Not Now"].tap() }
        let notNow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Not Now"]
        if notNow.exists { notNow.tap() }
        capture("medications-after-sign-in")
        XCTAssertFalse(app.otherElements["medicationsToday"].exists)
        openSettings(app)
        XCTAssertEqual(app.switches["medicationsEnabled"].value as? String, "0")
        app.switches["medicationsEnabled"].tap()
        addItem(app, name: "Vitamin D", amount: "1 capsule")
        addItem(app, name: "Magnesium", amount: "2 capsules", weekdays: true)
        capture("medications-profile-enabled")
        app.buttons["Done"].tap(); app.buttons["mainTab-today"].tap()
        let taken = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mark Vitamin D taken")).firstMatch
        reveal(taken, in: app); taken.tap()
        let skip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Skip Magnesium,")).firstMatch
        reveal(skip, in: app); skip.tap()
        capture("medications-today-complete-with-skip")
        let history = app.buttons["View history"]; reveal(history, in: app); history.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        capture("medications-history")
        let magnesium = app.buttons.containing(.staticText, identifier: "Magnesium").firstMatch
        reveal(magnesium, in: app); magnesium.tap()
        XCTAssertTrue(app.navigationBars["Correct entry"].waitForExistence(timeout: 5))
        app.buttons["medicationCorrectionStatus"].tap(); app.buttons["Taken"].tap()
        app.buttons["Save changes"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let manage = app.buttons["Manage"]; reveal(manage, in: app); manage.tap()
        XCTAssertTrue(app.switches["medicationsEnabled"].waitForExistence(timeout: 5))
        app.switches["medicationsEnabled"].tap(); capture("medications-profile-off")
        app.buttons["Done"].tap()
        XCTAssertFalse(app.otherElements["medicationsToday"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 15))
        openSettings(app)
        XCTAssertEqual(app.switches["medicationsEnabled"].value as? String, "0")
        XCTAssertTrue(app.staticTexts["Vitamin D"].exists); XCTAssertTrue(app.staticTexts["Magnesium"].exists)
        app.switches["medicationsEnabled"].tap()
        addItem(app, name: "Notification vitamin", amount: "1 capsule")
        app.buttons["Done"].tap(); app.buttons["mainTab-today"].tap()
        // An external simctl watcher injects a correctly identified notification only
        // after this file exists. This exercises the real OS category/action callback.
        XCUIDevice.shared.press(.home)
        try Data("ready".utf8).write(to: root.appendingPathComponent("notification-ready"), options: .atomic)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.staticTexts["Time for Notification vitamin"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 25))
        banner.press(forDuration: 1.2)
        let mark = springboard.buttons["Mark taken"]
        XCTAssertTrue(mark.waitForExistence(timeout: 10)); capture("medications-notification-actions"); mark.tap()
        app.activate()
        let completed = app.buttons.containing(.staticText, identifier: "All taken today").firstMatch
        reveal(completed, in: app)
        XCTAssertTrue(completed.waitForExistence(timeout: 10))
        capture("medications-notification-taken")
        try Data("passed".utf8).write(to: root.appendingPathComponent("ui-passed"), options: .atomic)
    }
}
