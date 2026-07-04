import Foundation

struct NewWeightLog: Encodable {
    let userId: UUID
    let weightKg: Double
    let source: String

    init(userId: UUID, weightKg: Double, source: String = "manual") {
        self.userId   = userId
        self.weightKg = weightKg
        self.source   = source
    }

    enum CodingKeys: String, CodingKey {
        case userId   = "user_id"
        case weightKg = "weight_kg"
        case source
    }
}

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
