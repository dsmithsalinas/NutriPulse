import Foundation

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
