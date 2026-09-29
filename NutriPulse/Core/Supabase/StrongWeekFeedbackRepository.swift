import Foundation
import Supabase

struct StrongWeekFeedbackRepository {
    func fetch(for week: StrongWeek) async throws -> StrongWeekFeedback? {
        guard let generatedAt = week.generatedAt else { return nil }
        let rows: [StrongWeekFeedback] = try await supabase.from("strong_week_feedback").select()
            .eq("user_id", value: week.userId).eq("strong_week_id", value: week.id)
            .eq("generated_at", value: generatedAt.ISO8601Format(.init(includingFractionalSeconds: true)))
            .limit(1).execute().value
        return rows.first
    }

    func save(for week: StrongWeek, rating: OutlookRating, reasons: Set<OutlookFeedbackReason>) async throws -> StrongWeekFeedback {
        guard let outlook = week.outlook, let generatedAt = week.generatedAt,
              try await supabase.auth.session.user.id == week.userId else { throw URLError(.userAuthenticationRequired) }
        let feedback = StrongWeekFeedback(userId: week.userId, strongWeekId: week.id,
            contextRevision: week.contextRevision, generatedAt: generatedAt, outlook: outlook,
            rating: rating, reasons: reasons.sorted { $0.rawValue < $1.rawValue }, updatedAt: .now)
        return try await supabase.from("strong_week_feedback")
            .upsert(feedback, onConflict: "user_id,strong_week_id,generated_at")
            .select().single().execute().value
    }
}
