import Foundation
import Supabase

// Module-level singleton — one SupabaseClient shared across the whole app,
// the same pattern you'd use for a singleton API client in TypeScript/React.
// Repositories and services import this file and use `supabase` directly.
let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseAnonKey,
    options: .init(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )
)
