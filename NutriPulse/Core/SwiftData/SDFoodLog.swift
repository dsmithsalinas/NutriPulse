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
    var syncState: String  // "pendingCreate" | "pendingUpdate" | "pendingDelete" | "synced"

    // Bumped on every local mutation. SyncEngine captures it before a push and
    // refuses to mark the row "synced" if it changed while the request was in
    // flight — otherwise an edit or delete made during those few hundred
    // milliseconds gets silently stamped over. See LocalStore.markFoodLogCreated.
    var revision: Int

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
        syncState: String = "pendingCreate",
        revision: Int = 0
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
        self.revision          = revision
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
