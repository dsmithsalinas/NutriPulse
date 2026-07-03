import Foundation
import Supabase

// Stub — proxies Claude API calls through a Supabase Edge Function.
// The Claude API key lives only in the Edge Function environment, never in the app binary.
struct CoachService {
    func sendMessage(_ text: String) async throws -> String {
        // TODO: invoke supabase.functions.invoke("coach-chat", body: ...)
        return "Coach feature coming soon."
    }
}
