import XCTest
import StoreKitTest

final class MembershipUITests: XCTestCase {
    func testLocalStoreKitPriceAndPurchaseTerms() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FootingPremium", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        defer { session.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["--membership-preview", "--membership-storekit-preview"]
        app.launch()
        let subscribe = app.buttons["subscribeMembership"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10))
        for _ in 0..<5 { if subscribe.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(subscribe.label.contains("$2.99"))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "renews monthly")).firstMatch.exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "monthly-price-and-terms"; shot.lifetime = .keepAlways; add(shot)
    }
    func testFoundingOfferAndFreeFeaturesRemainReadable() {
        let app = XCUIApplication()
        app.launchArguments = ["--membership-preview"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Your membership"].waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(app.buttons["claimFoundingMembership"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "No automatic billing")).firstMatch.exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "founding-offer"; shot.lifetime = .keepAlways; add(shot)
    }
    func testActiveFoundingMembershipHasNoSubscribeButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--membership-preview", "--founder-active", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["You’re a founding member"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["subscribeMembership"].exists)
        XCTAssertFalse(app.buttons["claimFoundingMembership"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "founder-largest-text"; shot.lifetime = .keepAlways; add(shot)
    }
}
