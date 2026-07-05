import Foundation

// One food component returned by the parse-food Edge Function — Claude's
// decomposition of a sentence, resolved against FatSecret where possible.
// All fields are per-serving (quantity = 1); `quantity` is a separate
// multiplier, same convention as FoodLog's snapshot + quantity split.
struct ParsedFoodItem: Codable {
    let query: String
    let name: String
    let brand: String?
    let servingDesc: String
    let grams: Double
    let quantity: Double
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let source: String        // "fatsecret" | "estimated"
    let externalId: String?
}
