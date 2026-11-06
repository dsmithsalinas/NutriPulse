import XCTest
@testable import Footing

@MainActor
final class RestaurantLoggingTests: XCTestCase {
    func testSessionResetAndExplicitContinuation() {
        let context = FoodLoggingContext()
        let draft = context.draftID
        context.select(" Chipotle ")
        XCTAssertEqual(context.restaurant?.name, "Chipotle")
        context.reset(keepRestaurant: true)
        XCTAssertEqual(context.restaurant?.name, "Chipotle")
        XCTAssertNotEqual(context.draftID, draft)
        context.reset()
        XCTAssertNil(context.restaurant)
        XCTAssertNil(context.interpretation)
    }
    func testExplicitIngredientInterpretationAndDetectionRevision() {
        let context = FoodLoggingContext()
        context.clear(asIngredient: true)
        XCTAssertEqual(context.interpretation, "ingredient")
        context.select("Texas Roadhouse")
        XCTAssertNil(context.interpretation)
        let revision = context.revision
        context.acceptDetected(.init(name: "Texas Roadhouse", origin: "detected"))
        XCTAssertEqual(context.revision, revision, "Normalizing an active response must not invalidate that response")
        context.textChanged()
        XCTAssertGreaterThan(context.revision, revision)
    }
    func testCompositionBackAndContextEditsInvalidateReadyState() {
        let vm = TalkToLogViewModel()
        vm.dishes = [.init(id: "bowl", name: "Bowl", customizable: true, ingredients: [])]
        vm.compositionConfirmed = true
        vm.acceptsEstimates = true
        vm.isParsing = true
        vm.backToComposition()
        XCTAssertTrue(vm.needsComposition)
        XCTAssertFalse(vm.isParsing)
        XCTAssertFalse(vm.acceptsEstimates)
        vm.foodContext.select("Chipotle")
        vm.contextChanged()
        XCTAssertTrue(vm.dishes.isEmpty)
        XCTAssertNil(vm.clarification)
    }
    func testRestaurantSearchInvalidatesOldPagesAndDetail() {
        let vm = FoodSearchViewModel()
        vm.searchQuery = "chicken"
        vm.results = [.init(id: "old", name: "Old match", brand: nil, description: "")]
        vm.restaurantName = "Chipotle"
        XCTAssertTrue(vm.results.isEmpty)
        XCTAssertNil(vm.selectedResult)
        XCTAssertTrue(vm.searchTaskKey.contains("Chipotle"))
        XCTAssertEqual(vm.searchQuery, "chicken")
    }
}

@MainActor
private final class GuidedParserFixture: GuidedFoodParsing {
    var count = 0
    var beforeResponse: (() -> Void)?
    func parse(_ request: GuidedFoodRequest) async throws -> GuidedFoodResponse {
        count += 1; beforeResponse?()
        return .init(schemaVersion: 2, draftId: request.draftId, draftRevision: request.draftRevision,
            status: "needs_restaurant", clarification: .init(message: "Chipotle the restaurant?", detail: "Choose", choices: []), items: [])
    }
}
extension RestaurantLoggingTests {
    func testConsentDenialNeverInvokesGuidedParser() async {
        let client = GuidedParserFixture()
        let vm = TalkToLogViewModel(client: client, currentOwner: { UUID() }, hasAIConsent: { false })
        vm.inputText = "chipotle chicken"
        await vm.parse(for: .now)
        XCTAssertEqual(client.count, 0)
        XCTAssertNotNil(vm.errorMessage)
    }
    func testLateResponseCannotRestoreClarificationAfterRestaurantChanges() async {
        let client = GuidedParserFixture(); let owner = UUID()
        let vm = TalkToLogViewModel(client: client, currentOwner: { owner }, hasAIConsent: { true })
        vm.inputText = "chipotle chicken"
        client.beforeResponse = { vm.foodContext.select("Texas Roadhouse"); vm.contextChanged() }
        await vm.parse(for: .now)
        XCTAssertEqual(client.count, 1)
        XCTAssertNil(vm.clarification)
        XCTAssertFalse(vm.isParsing)
        XCTAssertTrue(vm.rows.isEmpty)
    }
}
