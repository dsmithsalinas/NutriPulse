import Foundation
import Supabase

// Stub — proxies FatSecret food search through a Supabase Edge Function.
// Same pattern as CoachService: API keys stay server-side.
struct FatSecretClient {
    func search(query: String) async throws -> [FoodItem] {
        // TODO: invoke supabase.functions.invoke("food-search", body: ...)
        return []
    }

    func lookup(barcode: String) async throws -> FoodItem? {
        // TODO: invoke supabase.functions.invoke("food-barcode", body: ...)
        return nil
    }
}
