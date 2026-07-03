import Foundation

// Lightweight result row returned by the search-food Edge Function.
struct FoodSearchResult: Codable, Identifiable {
    let id: String           // FatSecret food_id
    let name: String
    let brand: String?
    let description: String  // e.g. "Per 100g - Calories: 61kcal | Fat: 3.25g | …"
}

// Full food detail returned by the get-food Edge Function.
struct FoodDetail: Codable {
    let id: String
    let name: String
    let brand: String?
    let servings: [FoodServing]
}

// One serving option with complete macro data.
struct FoodServing: Codable, Identifiable, Hashable {
    let id: String
    let description: String  // "1 cup", "100 g", etc.
    let grams: Double
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
}
