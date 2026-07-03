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

    func insert(_ log: FoodLog) async throws {
        try await supabase.from("food_logs").insert(log).execute()
    }

    func delete(id: UUID) async throws {
        try await supabase.from("food_logs").delete().eq("id", value: id).execute()
    }
}
