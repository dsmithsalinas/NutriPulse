import Foundation
import Supabase

struct GLP1Repository {
    func fetchRecentLogs(limit: Int = 5) async throws -> [GLP1Log] {
        try await supabase
            .from("glp1_logs")
            .select()
            .order("injected_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
}
