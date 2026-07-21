import Foundation
import Supabase

struct BodyGoalsRepository {

    func fetch() async throws -> BodyGoals? {
        let userId = try await supabase.auth.session.user.id
        let rows: [BodyGoals] = try await supabase
            .from("body_goals")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return rows.first
    }

    // user_id is the primary key, so a bare upsert resolves on it — the one table where
    // the "bare upsert resolves on the PK" behavior is exactly what we want.
    func upsert(weightKgTarget: Double?, bodyFatPctTarget: Double?, leanMassKgFloor: Double?) async throws {
        let userId = try await supabase.auth.session.user.id
        try await supabase
            .from("body_goals")
            .upsert(UpsertBodyGoals(
                userId: userId,
                weightKgTarget: weightKgTarget,
                bodyFatPctTarget: bodyFatPctTarget,
                leanMassKgFloor: leanMassKgFloor
            ))
            .execute()
    }
}
