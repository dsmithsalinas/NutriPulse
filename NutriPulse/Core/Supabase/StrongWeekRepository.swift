import Foundation
import Supabase

struct StrongWeekRepository {
    func fetchLatest(now: Date = .now) async throws -> [StrongWeek] {
        try await supabase.from("strong_weeks").select()
            .lte("week_start", value: StrongWeekWindow.key(for: now))
            .order("week_start", ascending: false).limit(2).execute().value
    }

    func context(now: Date = .now) async throws -> StrongWeekContext {
        let weeks = try await fetchLatest(now: now)
        let key = StrongWeekWindow.key(for: now)
        return .make(current: weeks.first { $0.weekStart == key }, previous: weeks.first { $0.weekStart < key }, now: now)
    }

    func saveContext(_ draft: StrongWeekDraft, weekStart: String, expectedRevision: UUID? = nil) async throws -> StrongWeek {
        let userId = try await supabase.auth.session.user.id
        // Explicit nulls invalidate the previous outlook in the same database write.
        let values: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString), "week_start": .string(weekStart),
            "circumstances": .array(draft.circumstances.map(\.rawValue).sorted().map { .string($0) }),
            "note": .string(draft.note), "activity_restrictions": .string(draft.activityRestrictions),
            "adjustments": .array(draft.adjustments.map(\.rawValue).sorted().map { .string($0) }),
            "ongoing": .bool(draft.ongoing), "context_revision": .string(UUID().uuidString),
            "outlook": .null, "generated_at": .null, "updated_at": .string(Date.now.ISO8601Format())
        ]
        if let expectedRevision {
            return try await supabase.from("strong_weeks").update(values)
                .eq("user_id", value: userId).eq("week_start", value: weekStart)
                .eq("context_revision", value: expectedRevision).select().single().execute().value
        }
        return try await supabase.from("strong_weeks").upsert(values, onConflict: "user_id,week_start")
            .select().single().execute().value
    }

    func saveOutlook(_ outlook: StrongWeekOutlook, for week: StrongWeek) async throws -> StrongWeek {
        struct Update: Encodable {
            let outlook: StrongWeekOutlook
            let generated_at: Date
        }
        // An old request must not replace a newer context edit from another device.
        return try await supabase.from("strong_weeks").update(Update(outlook: outlook, generated_at: .now))
            .eq("id", value: week.id).eq("context_revision", value: week.contextRevision)
            .select().single().execute().value
    }
}
