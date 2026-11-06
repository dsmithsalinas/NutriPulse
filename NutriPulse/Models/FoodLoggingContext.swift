import Foundation
import Observation

struct RestaurantSelection: Codable, Equatable {
    var name: String
    var origin: String = "manual"
}

@Observable @MainActor
final class FoodLoggingContext {
    static let knownRestaurants = ["Chipotle", "Texas Roadhouse", "Panera Bread", "Starbucks", "Chick-fil-A", "Subway", "McDonald's", "Taco Bell"]
    private(set) var restaurant: RestaurantSelection?
    private(set) var interpretation: String?
    private(set) var revision = 0
    private(set) var draftID = UUID().uuidString
    func select(_ name: String, origin: String = "manual") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else { return }
        restaurant = .init(name: trimmed, origin: origin); interpretation = nil; revision += 1
    }
    func clear(asIngredient: Bool = false) {
        restaurant = nil; interpretation = asIngredient ? "ingredient" : "none"; revision += 1
    }
    func acceptDetected(_ selected: RestaurantSelection?) { restaurant = selected }
    func textChanged() { revision += 1 }
    func reset(keepRestaurant: Bool = false) {
        if !keepRestaurant { restaurant = nil }
        interpretation = nil; revision += 1; draftID = UUID().uuidString
    }
}

struct MealIngredient: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var state: String
    var quantity: Double
    var fromDescription: Bool
    var uncertain: Bool
}
struct GuidedMealDish: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var customizable: Bool
    var ingredients: [MealIngredient]
}
struct RestaurantClarification: Codable {
    struct Choice: Codable, Identifiable { var id: String; var label: String; var restaurant: String? }
    var message: String
    var detail: String
    var choices: [Choice]
}
struct GuidedFoodRequest: Encodable {
    var schemaVersion = 2
    var text: String
    var draftId: String
    var draftRevision: Int
    var restaurant: RestaurantSelection?
    var interpretation: String?
    var compositionConfirmed: Bool
    var dishes: [GuidedMealDish]?
}
struct GuidedFoodResponse: Decodable {
    var schemaVersion: Int
    var draftId: String
    var draftRevision: Int
    var status: String
    var restaurant: RestaurantSelection?
    var clarification: RestaurantClarification?
    var dishes: [GuidedMealDish]?
    var items: [ParsedFoodItem]
}

@MainActor
protocol GuidedFoodParsing {
    func parse(_ request: GuidedFoodRequest) async throws -> GuidedFoodResponse
}
