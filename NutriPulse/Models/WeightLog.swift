import Foundation

struct WeightLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let loggedAt: Date
    let weightKg: Double
    let source: String          // "manual" | "healthkit"

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case loggedAt  = "logged_at"
        case weightKg  = "weight_kg"
        case source
    }
}
