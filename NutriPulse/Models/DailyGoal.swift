import Foundation

// Insert-only struct — omits id and created_at which the database generates.
struct NewDailyGoal: Encodable {
    let userId: UUID
    let effectiveDate: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let waterMlTarget: Double

    enum CodingKeys: String, CodingKey {
        case userId        = "user_id"
        case effectiveDate = "effective_date"
        case calories
        case proteinG      = "protein_g"
        case carbsG        = "carbs_g"
        case fatG          = "fat_g"
        case fiberG        = "fiber_g"
        case waterMlTarget = "water_ml_target"
    }
}

struct DailyGoal: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let effectiveDate: String   // "YYYY-MM-DD" — goals apply from this date forward
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let waterMlTarget: Double

    // How far under the calorie goal still counts as hitting it. Below this the day was
    // under-eaten, which isn't a win — Pulse's own system prompt pushes back on it.
    static let calorieBandFloor = 0.90

    // The single definition of a closed-rings day, shared by the Today screen's
    // celebration haptic and by CelebrationEngine's `recentWins` (which Claude is
    // instructed to treat as real, already-detected accomplishments and weave into its
    // reply).
    //
    // Both used to test `>=` on every macro, which treats the calorie and carb goals as
    // floors. They are ceilings — going over is the thing to avoid. So a user 1,400 kcal over budget earned a
    // success haptic and a compliment from their coach. Two components, one threshold,
    // opposite meanings.
    //
    // Ceilings must not be exceeded, floors must be met, and calories additionally have to
    // land inside a band so a 900-kcal day against an 1,800-kcal goal isn't celebrated.
    func ringsClosed(calories: Double, proteinG: Double, carbsG: Double, fiberG: Double) -> Bool {
        guard self.calories > 0 else { return false }
        return calories >= self.calories * Self.calorieBandFloor
            && calories <= self.calories
            && carbsG   <= self.carbsG
            && proteinG >= self.proteinG
            && fiberG   >= self.fiberG
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId          = "user_id"
        case effectiveDate   = "effective_date"
        case calories
        case proteinG        = "protein_g"
        case carbsG          = "carbs_g"
        case fatG            = "fat_g"
        case fiberG          = "fiber_g"
        case waterMlTarget   = "water_ml_target"
    }
}
