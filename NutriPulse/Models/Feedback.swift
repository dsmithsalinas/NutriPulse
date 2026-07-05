import Foundation

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug
    case idea
    case general

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bug:     "Bug"
        case .idea:    "Idea"
        case .general: "General"
        }
    }
}

struct NewFeedback: Encodable {
    let userId: UUID
    let category: String
    let message: String
    let appVersion: String?

    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case category
        case message
        case appVersion = "app_version"
    }
}

struct Feedback: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let category: String
    let message: String
    let appVersion: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case category
        case message
        case appVersion = "app_version"
        case createdAt  = "created_at"
    }
}
