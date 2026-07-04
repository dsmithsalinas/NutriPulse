import Foundation

struct CoachMessage: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let role: String        // "user" | "assistant"
    let content: String
    let messageType: String // "chat" | "checkin" | "weekly_summary"
    let createdAt: Date

    var isUser: Bool { role == "user" }

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case role
        case content
        case messageType = "message_type"
        case createdAt   = "created_at"
    }
}

struct NewCoachMessage: Encodable {
    let userId: UUID
    let role: String
    let content: String
    let messageType: String

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case role
        case content
        case messageType = "message_type"
    }
}
