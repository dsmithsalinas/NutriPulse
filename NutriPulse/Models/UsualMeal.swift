import Foundation

struct UsualMeal: Codable, Identifiable, Equatable {
    var id = UUID()
    let userId: UUID
    var name: String
    let meal: Meal
    let items: [FoodLog]
    enum CodingKeys: String, CodingKey { case id, name, meal, items; case userId = "user_id" }
    static func suggestedName(for foods: [FoodLog]) -> String {
        if foods.count == 1, let food = foods.first {
            let title = food.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if nameValidationMessage(title) == nil { return title }
        }
        return "My usual \(foods.first?.meal.displayName.lowercased() ?? "meal")"
    }

    static func nameValidationMessage(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Enter a meal name to save." }
        if trimmed.unicodeScalars.count > 80 { return "Use a meal name of 80 characters or fewer." }
        return nil
    }

    var isValid: Bool {
        return Self.nameValidationMessage(name) == nil && (1...40).contains(items.count)
            && Set(items.map(\.id)).count == items.count
            && items.allSatisfy { $0.userId == userId && $0.quantity.isFinite && $0.quantity > 0 }
    }
}
