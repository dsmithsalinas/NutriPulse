import SwiftData
import Foundation

@Model
final class SDFoodLog {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var logDate: String
    var meal: String
    var foodItemId: UUID
    var foodItemName: String
    var quantity: Double
    var caloriesSnapshot: Double
    var proteinGSnapshot: Double
    var carbsGSnapshot: Double
    var fatGSnapshot: Double
    var fiberGSnapshot: Double
    var loggedAt: Date
    var syncState: String  // "pendingCreate" | "pendingDelete" | "synced"

    init(
        id: UUID = UUID(),
        userId: UUID,
        logDate: String,
        meal: String,
        foodItemId: UUID,
        foodItemName: String,
        quantity: Double,
        caloriesSnapshot: Double,
        proteinGSnapshot: Double,
        carbsGSnapshot: Double,
        fatGSnapshot: Double,
        fiberGSnapshot: Double,
        loggedAt: Date = .now,
        syncState: String = "pendingCreate"
    ) {
        self.id                = id
        self.userId            = userId
        self.logDate           = logDate
        self.meal              = meal
        self.foodItemId        = foodItemId
        self.foodItemName      = foodItemName
        self.quantity          = quantity
        self.caloriesSnapshot  = caloriesSnapshot
        self.proteinGSnapshot  = proteinGSnapshot
        self.carbsGSnapshot    = carbsGSnapshot
        self.fatGSnapshot      = fatGSnapshot
        self.fiberGSnapshot    = fiberGSnapshot
        self.loggedAt          = loggedAt
        self.syncState         = syncState
    }

    var asFoodLog: FoodLog {
        FoodLog(
            id: id,
            userId: userId,
            loggedAt: loggedAt,
            logDate: logDate,
            meal: Meal(rawValue: meal) ?? .snack,
            foodItemId: foodItemId,
            quantity: quantity,
            caloriesSnapshot: caloriesSnapshot,
            proteinGSnapshot: proteinGSnapshot,
            carbsGSnapshot: carbsGSnapshot,
            fatGSnapshot: fatGSnapshot,
            fiberGSnapshot: fiberGSnapshot,
            foodItems: FoodItemSummary(name: foodItemName, brand: nil, servingDesc: nil)
        )
    }
}
