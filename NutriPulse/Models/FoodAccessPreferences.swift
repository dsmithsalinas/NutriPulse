import Foundation

enum FoodAccessChoice: String, Codable, CaseIterable, Identifiable {
    case rarelyCook = "rarely_cook", eatOut = "eat_out", budgetFriendly = "budget_friendly"
    case limitedKitchen = "limited_kitchen", quickMeals = "quick_meals"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rarelyCook: "I rarely cook"
        case .eatOut: "I eat out often"
        case .budgetFriendly: "Keep it budget-friendly"
        case .limitedKitchen: "I have limited kitchen access"
        case .quickMeals: "I need quick meals"
        }
    }
}

struct FoodAccessDraft: Equatable {
    var choices: Set<FoodAccessChoice> = []
    var note = ""
    var normalized: Self {
        .init(choices: choices, note: String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)))
    }
}

struct FoodAccessPreferences: Codable {
    let userId: UUID
    let choices: [FoodAccessChoice]
    let note: String
    let updatedAt: Date
    var draft: FoodAccessDraft { .init(choices: Set(choices), note: note) }
    enum CodingKeys: String, CodingKey {
        case choices, note
        case userId = "user_id", updatedAt = "updated_at"
    }
}

struct FoodAccessContext: Encodable {
    let status: String
    let choices: [String]
    let note: String
    static let unavailable = Self(status: "unavailable", choices: [], note: "")
    static func make(_ preferences: FoodAccessPreferences?) -> Self {
        .init(status: preferences == nil ? "not_provided" : "saved",
              choices: preferences?.choices.map(\.rawValue) ?? [], note: preferences?.note ?? "")
    }
}

extension Notification.Name {
    static let foodAccessChanged = Notification.Name("foodAccessChanged")
}
