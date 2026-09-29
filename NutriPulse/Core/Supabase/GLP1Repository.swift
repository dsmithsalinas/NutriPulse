import Foundation
import Supabase

struct GLP1Repository {
    func fetchSkippedDoses() async throws -> [GLP1SkippedDose] {
        try await supabase.from("glp1_skipped_doses").select()
            .order("scheduled_at", ascending: false).execute().value
    }

    func fetchDoseSchedule() async throws -> GLP1DoseSchedule {
        async let logs = fetchRecentLogs(limit: 1)
        async let skips = fetchSkippedDoses()
        let (injections, skippedDoses) = try await (logs, skips)
        return GLP1DoseSchedule(latest: injections.first, skips: skippedDoses)
    }

    func skipDose(injection: GLP1Log, scheduledAt: Date) async throws -> GLP1SkippedDose {
        let userId = try await supabase.auth.session.user.id
        let skip = GLP1SkippedDose(
            id: UUID(), userId: userId, injectionId: injection.id,
            scheduledAt: scheduledAt,
            nextReminderAt: Calendar.current.date(byAdding: .day, value: 7, to: scheduledAt)!,
            createdAt: .now
        )
        // Return the committed row in the same request. A retry after a lost response
        // resolves the unique scheduled-dose key rather than creating another skip.
        do {
            return try await supabase.from("glp1_skipped_doses").insert(skip)
                .select().single().execute().value
        } catch let error as PostgrestError where error.code == "23505" {
            // Already recorded by this request's retry or another device.
        }
        let saved: [GLP1SkippedDose] = try await supabase.from("glp1_skipped_doses").select()
            .eq("injection_id", value: injection.id).execute().value
        guard let result = saved.first(where: { abs($0.scheduledAt.timeIntervalSince(scheduledAt)) < 1 }) else {
            throw URLError(.badServerResponse)
        }
        return result
    }

    func undoSkip(id: UUID) async throws {
        try await supabase.from("glp1_skipped_doses").delete()
            .eq("id", value: id).execute()
    }

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

    // Removes one logged dose. RLS restricts deletes to the caller's own rows. Callers must
    // recompute next-due and reschedule reminders afterward, since the most recent remaining
    // log — not this one — is what drives the schedule.
    func deleteLog(id: UUID) async throws {
        try await supabase
            .from("glp1_logs")
            .delete()
            .eq("id", value: id)
            .execute()
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
