import Foundation

struct FavoriteQuickAdd: Codable, Identifiable {
    let foodItemId: UUID
    let name: String
    let brand: String?
    let servingDesc: String?
    let quantity: Double
    let caloriesSnapshot: Double
    let proteinGSnapshot: Double
    let carbsGSnapshot: Double
    let fatGSnapshot: Double
    let fiberGSnapshot: Double

    var id: UUID { foodItemId }
    var totalCalories: Double { caloriesSnapshot * quantity }

    enum CodingKeys: String, CodingKey {
        case foodItemId       = "food_item_id"
        case name, brand
        case servingDesc      = "serving_desc"
        case quantity
        case caloriesSnapshot = "calories_snapshot"
        case proteinGSnapshot = "protein_g_snapshot"
        case carbsGSnapshot   = "carbs_g_snapshot"
        case fatGSnapshot     = "fat_g_snapshot"
        case fiberGSnapshot   = "fiber_g_snapshot"
    }
}
