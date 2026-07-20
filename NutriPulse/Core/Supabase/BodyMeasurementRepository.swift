import Foundation
import Supabase

// Direct-to-Supabase like BodyCompositionRepository, deliberately NOT the offline-first
// SwiftData/SyncEngine path: measurements are an every-few-weeks act, not per-meal logging,
// and their sibling body data (weight, body comp) already lives on this pattern.
struct BodyMeasurementRepository {

    func insert(
        site: MeasurementSite,
        valueCm: Double,
        date: Date = .now,
        source: String = "manual",
        healthKitUUID: String? = nil
    ) async throws {
        let userId = try await supabase.auth.session.user.id
        try await supabase
            .from("body_measurement_logs")
            .insert(NewBodyMeasurementLog(
                userId: userId,
                logDate: date.isoDateString,
                site: site.rawValue,
                valueCm: valueCm,
                source: source,
                healthKitUUID: healthKitUUID,
                loggedAt: date
            ))
            .execute()
    }

    // Most recent entry per site. Pulls a bounded window ordered newest-first and reduces
    // client-side — at this cadence a year of data is a few dozen rows.
    func fetchLatestPerSite() async throws -> [MeasurementSite: BodyMeasurementLog] {
        let rows: [BodyMeasurementLog] = try await supabase
            .from("body_measurement_logs")
            .select()
            .order("logged_at", ascending: false)
            .limit(200)
            .execute()
            .value
        var latest: [MeasurementSite: BodyMeasurementLog] = [:]
        for row in rows {
            guard let site = row.siteType else { continue }
            if latest[site] == nil { latest[site] = row }
        }
        return latest
    }

    // Every site in one query; the Body hub groups client-side.
    func fetchHistoryAll(days: Int) async throws -> [BodyMeasurementLog] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: .now))!
        return try await supabase
            .from("body_measurement_logs")
            .select()
            .gte("log_date", value: start.isoDateString)
            .order("logged_at", ascending: true)
            .execute()
            .value
    }

    func fetchHistory(site: MeasurementSite, days: Int) async throws -> [BodyMeasurementLog] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: .now))!
        return try await supabase
            .from("body_measurement_logs")
            .select()
            .eq("site", value: site.rawValue)
            .gte("log_date", value: start.isoDateString)
            .order("logged_at", ascending: true)
            .execute()
            .value
    }

    func delete(id: UUID) async throws {
        try await supabase
            .from("body_measurement_logs")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
