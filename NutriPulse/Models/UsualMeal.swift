import Foundation

struct UsualMeal: Codable, Identifiable, Equatable {
    var id = UUID()
    let userId: UUID
    var name: String
    let meal: Meal
    let items: [FoodLog]
    enum CodingKeys: String, CodingKey { case id, name, meal, items; case userId = "user_id" }
    var isValid: Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.unicodeScalars.count <= 80 && (1...40).contains(items.count)
            && Set(items.map(\.id)).count == items.count
            && items.allSatisfy { $0.userId == userId && $0.quantity.isFinite && $0.quantity > 0 }
    }
}
