import Foundation
import Supabase

// Proxies the parse-food Edge Function — Claude decomposes the sentence and
// resolves each component against FatSecret server-side. Neither the Anthropic
// nor FatSecret key ever reaches the app; it sends the user's JWT and a sentence.
//
// Setup (one-time): supabase functions deploy parse-food
struct TalkToLogClient {
    func parse(text: String) async throws -> [ParsedFoodItem] {
        struct Payload: Encodable { let text: String }
        struct Response: Decodable { let items: [ParsedFoodItem] }
        let response: Response = try await supabase.functions.invoke(
            "parse-food",
            options: .init(body: Payload(text: text))
        )
        return response.items
    }
}
