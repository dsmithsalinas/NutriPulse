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

    func fetchAllLogs() async throws -> [GLP1Log] {
        try await supabase
            .from("glp1_logs")
            .select()
            .order("injected_at", ascending: false)
            .execute()
            .value
    }

    // All-time history in ascending order — used for the titration chart.
    func fetchHistory() async throws -> [GLP1Log] {
        try await supabase
            .from("glp1_logs")
            .select()
            .order("injected_at", ascending: true)
            .execute()
            .value
    }
}
