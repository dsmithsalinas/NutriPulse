import Foundation
import Supabase

struct GoalRepository {
    // Returns the most-recently-effective goal on or before `date`.
    // This lets users update their goals over time without rewriting history.
    func fetchGoal(for date: Date) async throws -> DailyGoal? {
        let dateStr = date.isoDateString
        let results: [DailyGoal] = try await supabase
            .from("daily_goals")
            .select()
            .lte("effective_date", value: dateStr)   // lte = less than or equal
            .order("effective_date", ascending: false)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func upsert(_ goal: DailyGoal) async throws {
        try await supabase.from("daily_goals").upsert(goal).execute()
    }
}
