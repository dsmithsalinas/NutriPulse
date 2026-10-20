import Foundation

/// Only an explicit user save creates a row. Proposed memories live in chat payloads.
struct PulseMemory: Codable, Identifiable, Equatable {
    var id = UUID()
    let userId: UUID
    var content: String
    enum CodingKeys: String, CodingKey { case id, content; case userId = "user_id" }
    var isValid: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && content.unicodeScalars.count <= 300 }
}

enum PulseAttentionLimit: String, Codable, CaseIterable {
    case one, quiet
    var label: String { self == .one ? "One optional check-in a day" : "Keep things quiet" }
}

struct PulseAttentionPreference: Codable, Equatable {
    let userId: UUID
    var limit: PulseAttentionLimit
    enum CodingKeys: String, CodingKey { case userId = "user_id", limit = "attention_limit" }
}

struct BreakfastCheckinPreference: Codable, Equatable {
    let userId: UUID
    let usualMealId: UUID
    enum CodingKeys: String, CodingKey { case userId = "user_id", usualMealId = "usual_meal_id" }
}

struct BreakfastCheckin: Codable, Identifiable, Equatable {
    var id = UUID()
    let userId: UUID
    let localDay: String
    let usualMealId: UUID?
    let name: String
    enum CodingKeys: String, CodingKey { case id, name; case userId = "user_id", localDay = "local_day", usualMealId = "usual_meal_id" }
}
