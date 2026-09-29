import Foundation

enum OutlookRating: String, Codable, CaseIterable, Identifiable {
    case helpful, notHelpful = "not_helpful"
    var id: String { rawValue }
    var title: String { self == .helpful ? "Helpful" : "Not helpful" }
    var symbol: String { self == .helpful ? "hand.thumbsup" : "hand.thumbsdown" }
}

enum OutlookFeedbackReason: String, Codable, CaseIterable, Identifiable {
    case tooVague = "too_vague", notRealistic = "not_realistic", moreFoodIdeas = "more_food_ideas"
    case moreMovementDetail = "more_movement_detail", tone
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tooVague: "Too vague"
        case .notRealistic: "Doesn't fit my week"
        case .moreFoodIdeas: "More food ideas"
        case .moreMovementDetail: "More movement detail"
        case .tone: "The tone could be better"
        }
    }
}

struct StrongWeekFeedback: Codable {
    let userId: UUID
    let strongWeekId: UUID
    let contextRevision: UUID
    let generatedAt: Date
    let outlook: StrongWeekOutlook
    let rating: OutlookRating
    let reasons: [OutlookFeedbackReason]
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id", strongWeekId = "strong_week_id", contextRevision = "context_revision"
        case generatedAt = "generated_at", updatedAt = "updated_at", outlook, rating, reasons
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(userId, forKey: .userId)
        try values.encode(strongWeekId, forKey: .strongWeekId)
        try values.encode(contextRevision, forKey: .contextRevision)
        // Use the exact UTC format used by the repository's generation lookup.
        try values.encode(generatedAt.ISO8601Format(.init(includingFractionalSeconds: true)), forKey: .generatedAt)
        try values.encode(outlook, forKey: .outlook)
        try values.encode(rating, forKey: .rating)
        try values.encode(reasons, forKey: .reasons)
        try values.encode(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true)), forKey: .updatedAt)
    }
}
