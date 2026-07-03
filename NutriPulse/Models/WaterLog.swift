import Foundation

struct WaterLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let loggedAt: Date
    let logDate: String
    let amountMl: Double
    let source: String          // "manual" | "healthkit"

    enum CodingKeys: String, CodingKey {
        case id
        case userId   = "user_id"
        case loggedAt = "logged_at"
        case logDate  = "log_date"
        case amountMl = "amount_ml"
        case source
    }
}
