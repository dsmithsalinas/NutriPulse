import Foundation
import Supabase

// supabase-swift surfaces a non-2xx Edge Function response as FunctionsError.httpError(code:data:),
// whose default description is a generic "non-2xx status code". Our functions put a human-readable
// reason in the body as {"error": "..."} — including the friendly rate-limit (429) copy — so pull
// that out for display instead. Falls back to the caller's message for transport errors or bodies
// without an `error` field.
enum EdgeFunctionError {
    static func message(from error: Error, fallback: String) -> String {
        guard case let FunctionsError.httpError(_, data) = error else { return fallback }
        struct Body: Decodable { let error: String? }
        if let body = try? JSONDecoder().decode(Body.self, from: data),
           let msg = body.error, !msg.isEmpty {
            return msg
        }
        return fallback
    }

    /// coach-chat's 403 for an account whose Pulse setting is off on the server (turned off on
    /// another device, say) while this one still had it on.
    static func isPulseOff(_ error: Error) -> Bool {
        guard case let FunctionsError.httpError(code, data) = error, code == 403 else { return false }
        struct Body: Decodable { let code: String? }
        return (try? JSONDecoder().decode(Body.self, from: data))?.code == "pulse_off"
    }
}
