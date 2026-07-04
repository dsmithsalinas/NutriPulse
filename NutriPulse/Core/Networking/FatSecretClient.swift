import Foundation
import Supabase

// Proxies FatSecret API calls through Supabase Edge Functions.
// API keys never leave the server — the app sends only the user's JWT.
//
// Setup (one-time):
//   supabase secrets set FATSECRET_CLIENT_ID=<id> FATSECRET_CLIENT_SECRET=<secret>
//   supabase functions deploy search-food
//   supabase functions deploy get-food
struct FatSecretClient {
    func search(query: String, page: Int = 0) async throws -> [FoodSearchResult] {
        struct Payload: Encodable { let query: String; let page: Int }
        struct Response: Decodable { let results: [FoodSearchResult] }
        let response: Response = try await supabase.functions.invoke(
            "search-food",
            options: .init(body: Payload(query: query, page: page))
        )
        return response.results
    }

    func getFood(id: String) async throws -> FoodDetail {
        struct Payload: Encodable { let foodId: String }
        return try await supabase.functions.invoke(
            "get-food",
            options: .init(body: Payload(foodId: id))
        )
    }

    func getFood(barcode: String) async throws -> FoodDetail {
        struct Payload: Encodable { let barcode: String }
        return try await supabase.functions.invoke(
            "get-food",
            options: .init(body: Payload(barcode: barcode))
        )
    }
}
