import Foundation

// Denormalized snapshot pattern: macros are copied from the food_item at log time.
// This means editing a food definition later won't silently rewrite your history —
// the same reason financial ledgers use snapshot rows rather than foreign keys to prices.
struct FoodLog: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let loggedAt: Date
    let logDate: String         // "YYYY-MM-DD" — plain string, no timezone ambiguity
    let meal: Meal
    let foodItemId: UUID
    let quantity: Double        // number of servings

    // Snapshot of per-serving macros at log time
    let caloriesSnapshot: Double
    let proteinGSnapshot: Double
    let carbsGSnapshot: Double
    let fatGSnapshot: Double
    let fiberGSnapshot: Double

    // Joined from food_items via select("*, food_items(name, brand, serving_desc)")
    let foodItems: FoodItemSummary?

    enum CodingKeys: String, CodingKey {
        case id
        case userId             = "user_id"
        case loggedAt           = "logged_at"
        case logDate            = "log_date"
        case meal
        case foodItemId         = "food_item_id"
        case quantity
        case caloriesSnapshot   = "calories_snapshot"
        case proteinGSnapshot   = "protein_g_snapshot"
        case carbsGSnapshot     = "carbs_g_snapshot"
        case fatGSnapshot       = "fat_g_snapshot"
        case fiberGSnapshot     = "fiber_g_snapshot"
        case foodItems          = "food_items"
    }

    // Computed totals — quantity multiplies the per-serving snapshot
    var totalCalories:  Double { caloriesSnapshot  * quantity }
    var totalProteinG:  Double { proteinGSnapshot  * quantity }
    var totalCarbsG:    Double { carbsGSnapshot    * quantity }
    var totalFatG:      Double { fatGSnapshot      * quantity }
    var totalFiberG:    Double { fiberGSnapshot    * quantity }

    var displayName: String { foodItems?.name ?? "Unknown food" }
}

// Insert-only struct for food_logs — id and created_at are database-generated.
struct NewFoodLog: Encodable {
    let userId: UUID
    let loggedAt: Date
    let logDate: String
    let meal: Meal
    let foodItemId: UUID
    let quantity: Double
    let caloriesSnapshot: Double
    let proteinGSnapshot: Double
    let carbsGSnapshot: Double
    let fatGSnapshot: Double
    let fiberGSnapshot: Double

    enum CodingKeys: String, CodingKey {
        case userId            = "user_id"
        case loggedAt          = "logged_at"
        case logDate           = "log_date"
        case meal
        case foodItemId        = "food_item_id"
        case quantity
        case caloriesSnapshot  = "calories_snapshot"
        case proteinGSnapshot  = "protein_g_snapshot"
        case carbsGSnapshot    = "carbs_g_snapshot"
        case fatGSnapshot      = "fat_g_snapshot"
        case fiberGSnapshot    = "fiber_g_snapshot"
    }
}
