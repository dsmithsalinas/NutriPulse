import Foundation

/// A qualitative record; absent nutrition is unknown, never a zero-valued FoodLog.
struct MealNote: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let userId: UUID
    let logDate: String
    let meal: Meal
    var body: String
    enum Kind: String, Codable { case meal; case dayContext = "day_context" }
    var kind: Kind? = nil
    var isDayContext: Bool { kind == .dayContext }
    var displayTitle: String { isDayContext ? "Day note" : "\(meal.displayName) · Meal note" }
    var contextMeal: String { isDayContext ? "day_context" : meal.rawValue }
    enum CodingKeys: String, CodingKey {
        case id, meal, body, kind
        case userId = "user_id", logDate = "log_date"
    }
    static func validBody(_ body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.unicodeScalars.count <= 1000 ? trimmed : nil
    }
}
