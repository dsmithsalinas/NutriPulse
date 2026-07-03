import Foundation

// SWIFT CONCEPT — Codable = Encodable + Decodable. A struct conforming to Codable
// gets automatic JSON encode/decode. It's like a Zod schema that also handles
// serialization — you define the shape once and get everything for free.
//
// CodingKeys maps Swift camelCase property names to Postgres snake_case column names.
// Without it, the decoder would look for "userId" in JSON and fail to find "user_id".

struct FoodItem: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID?           // nil for shared catalog rows
    let source: String          // "fatsecret" | "manual"
    let externalId: String?
    let name: String
    let brand: String?
    let servingDesc: String
    let servingGrams: Double
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double

    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case source
        case externalId    = "external_id"
        case name
        case brand
        case servingDesc   = "serving_desc"
        case servingGrams  = "serving_grams"
        case calories
        case proteinG      = "protein_g"
        case carbsG        = "carbs_g"
        case fatG          = "fat_g"
        case fiberG        = "fiber_g"
    }
}

// Insert-only struct — omits `id` and `created_at` which the database generates.
// SWIFT CONCEPT — we use a separate Encodable struct for inserts rather than making
// `id` optional on FoodItem. This makes it impossible to accidentally insert a row
// with a nil id — the types enforce the right shape at each call site.
struct NewFoodItem: Encodable {
    let userId: UUID
    let source: String = "manual"
    let externalId: String? = nil
    let name: String
    let brand: String?
    let servingDesc: String
    let servingGrams: Double
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double

    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case source
        case externalId   = "external_id"
        case name
        case brand
        case servingDesc  = "serving_desc"
        case servingGrams = "serving_grams"
        case calories
        case proteinG     = "protein_g"
        case carbsG       = "carbs_g"
        case fatG         = "fat_g"
        case fiberG       = "fiber_g"
    }
}

// Lightweight projection used when food_items is joined inside a food_logs query.
struct FoodItemSummary: Codable, Hashable {
    let name: String
    let brand: String?
    let servingDesc: String?

    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case servingDesc = "serving_desc"
    }
}
