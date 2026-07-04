import Foundation
import Supabase

struct CoachRepository {
    func fetchHistory(limit: Int = 30) async throws -> [CoachMessage] {
        let results: [CoachMessage] = try await supabase
            .from("coach_messages")
            .select()
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
