import Foundation
import Supabase

struct CoachRepository {
    // `before` pages backwards through history: pass the createdAt of the oldest message
    // you already hold. Without it, anything past the newest 30 messages was unreachable
    // in the UI forever, even though it was still in the database.
    func fetchHistory(limit: Int = 30, before: Date? = nil) async throws -> [CoachMessage] {
        // Filters must be applied before .order(): PostgrestFilterBuilder narrows to a
        // PostgrestTransformBuilder, which has no .lt.
        var query = supabase.from("coach_messages").select()
        if let before {
            query = query.lt("created_at", value: before.ISO8601Format())
        }

        let results: [CoachMessage] = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return results.reversed()
    }

    func save(_ message: NewCoachMessage) async throws -> CoachMessage {
        try await supabase
            .from("coach_messages")
            .insert(message)
            .select()
            .single()
            .execute()
            .value
    }

    func clearHistory() async throws {
        let userId = try await supabase.auth.session.user.id
        try await supabase
            .from("coach_messages")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }

    func lastWeeklySummaryDate() async throws -> Date? {
        let results: [CoachMessage] = try await supabase
            .from("coach_messages")
            .select()
            .eq("message_type", value: "weekly_summary")
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return results.first?.createdAt
    }
}
