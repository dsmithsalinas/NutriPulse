import Foundation
import Supabase

// SWIFT CONCEPT — struct (value type) works perfectly for a stateless repository.
// Each method call gets its own copy of the struct — no shared mutable state.
// Classes are for things that need identity or shared mutable state (ViewModels, AppState).

struct FoodLogRepository {
    // SWIFT CONCEPT — `async throws` = async function that can fail.
    // Callers use `try await`. It's equivalent to `Promise<T>` that can reject in TS.
    func fetchLogs(for date: Date) async throws -> [FoodLog] {
        try await supabase
            .from("food_logs")
            // Joins food_items so we get the display name in the same request.
            // PostgREST uses "related_table(columns)" syntax for joins.
            .select("*, food_items(name, brand, serving_desc)")
            .eq("log_date", value: date.isoDateString)
            .order("logged_at", ascending: true)
            .execute()
            .value  // .value decodes the JSON response into [FoodLog] automatically
    }

    // `insert(_ log: FoodLog)` used to live here and was a loaded trap: FoodLog's CodingKeys
    // include `case foodItems = "food_items"`, the joined object, which is not a column. Any
    // log built by SDFoodLog.asFoodLog or fetched with the join above carries a non-nil
    // foodItems and would have been rejected with PGRST204. Nothing called it. Writes go
    // through LocalStore + SyncEngine (which encodes a purpose-built FoodLogInsert), so it's
    // deleted rather than left for the next feature to reach for.

    func delete(id: UUID) async throws {
        try await supabase.from("food_logs").delete().eq("id", value: id).execute()
    }
}
