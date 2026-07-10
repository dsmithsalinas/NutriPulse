import Foundation
import Supabase

struct GLP1Repository {
    // Inserts one injection and returns the saved row. Weekly cadence (nextDue = +7 days) is
    // computed by the caller so the ritual and the classic sheet stay consistent.
    func logInjection(medication: String, doseMg: Double, site: String,
                      injectedAt: Date, nextDueAt: Date) async throws -> GLP1Log {
        let userId = try await supabase.auth.session.user.id
        let new = NewGLP1Log(
            userId: userId, injectedAt: injectedAt, medication: medication,
            doseMg: doseMg, site: site, nextDueAt: nextDueAt
        )
        return try await supabase
            .from("glp1_logs")
            .insert(new)
            .select()
            .single()
            .execute()
            .value
    }

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
