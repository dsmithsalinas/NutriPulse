import Foundation
import Supabase

struct FoodAccessRepository {
    func fetch() async throws -> FoodAccessPreferences? {
        let userId = try await supabase.auth.session.user.id
        let rows: [FoodAccessPreferences] = try await supabase.from("food_access_preferences").select()
            .eq("user_id", value: userId).limit(1).execute().value
        return rows.first
    }
    func save(_ draft: FoodAccessDraft, userId: UUID) async throws -> FoodAccessPreferences {
        guard try await supabase.auth.session.user.id == userId else { throw URLError(.userAuthenticationRequired) }
        let value = draft.normalized
        let row: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "choices": .array(value.choices.map(\.rawValue).sorted().map { .string($0) }),
            "note": .string(value.note), "updated_at": .string(Date.now.ISO8601Format())
        ]
        return try await supabase.from("food_access_preferences").upsert(row, onConflict: "user_id")
            .select().single().execute().value
    }
}
