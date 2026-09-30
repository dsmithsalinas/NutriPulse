import Foundation

// Structured Pulse replies (docs/daylight-redesign.md, supabase/functions/_shared/pulse-context.ts
// `parsePulseReply`): the extras that ride alongside an assistant message's text — one-tap food
// cards, follow-up chips, and the weekly recap card. Mirrors the `coach_messages.payload` jsonb
// column added in supabase/migrations/20260929200000_coach_message_payload.sql, which is NOT yet
// applied to production — every field here is optional, and a missing `payload` key (or a save
// against a database without the column) must decode to `nil`, not throw.
struct CoachMessagePayload: Codable, Equatable {
    struct FoodSuggestion: Codable, Equatable, Identifiable, Hashable {
        let name: String
        let why: String
        var id: String { name }
    }

    struct Recap: Codable, Equatable {
        let story: String
        let wentWell: String
        let pattern: String
        let focus: String
    }

    var foods: [FoodSuggestion]? = nil
    var followUps: [String]? = nil
    var recap: Recap? = nil
}

struct CoachMessage: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let role: String        // "user" | "assistant"
    let content: String
    let messageType: String // "chat" | "checkin" | "weekly_summary"
    let createdAt: Date
    // Absent on every row saved before the payload column existed, and on any row saved while
    // it doesn't exist in this environment — a missing key decodes to nil rather than failing
    // the whole message.
    var payload: CoachMessagePayload? = nil

    var isUser: Bool { role == "user" }
    var isAutomatic: Bool {
        messageType == "checkin" || messageType == "weekly_summary"
    }

    var automaticContextLabel: String? {
        guard isAutomatic else { return nil }
        let title = messageType == "weekly_summary" ? "Weekly recap" : "Check-in"
        let date = createdAt.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
        )
        return "\(title) · \(date)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case role
        case content
        case messageType = "message_type"
        case createdAt   = "created_at"
        case payload
    }

    // Memberwise init isn't synthesized once a custom CodingKeys/default value mixes with
    // call sites that predate `payload` (previews, tests) — keep it explicit and default the
    // new field so every existing call site keeps compiling.
    init(
        id: UUID, userId: UUID, role: String, content: String, messageType: String,
        createdAt: Date, payload: CoachMessagePayload? = nil
    ) {
        self.id = id
        self.userId = userId
        self.role = role
        self.content = content
        self.messageType = messageType
        self.createdAt = createdAt
        self.payload = payload
    }
}

struct NewCoachMessage: Encodable {
    let userId: UUID
    let role: String
    let content: String
    let messageType: String
    // `encodeIfPresent`-style: nil sends no key at all, so an insert against a database that
    // hasn't run the payload migration yet looks exactly like it did before this field existed.
    var payload: CoachMessagePayload? = nil

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case role
        case content
        case messageType = "message_type"
        case payload
    }

    init(userId: UUID, role: String, content: String, messageType: String, payload: CoachMessagePayload? = nil) {
        self.userId = userId
        self.role = role
        self.content = content
        self.messageType = messageType
        self.payload = payload
    }
}
