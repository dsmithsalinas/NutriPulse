import Foundation

struct BodyCompositionRepository {

    func fetchLatest() async throws -> BodyCompositionLog? {
        let userId = try await supabase.auth.session.user.id
        let rows: [BodyCompositionLog] = try await supabase
            .from("body_composition_logs")
            .select()
            .eq("user_id", value: userId)
            .order("log_date", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func upsert(
        date: String,
        weightKg: Double?,
        bodyFatPct: Double?,
        bmi: Double?,
        leanBodyMassKg: Double?,
        source: String
    ) async throws {
        let params = UpsertBodyCompParams(
            pLogDate: date,
            pWeightKg: weightKg,
            pBodyFatPct: bodyFatPct,
            pBmi: bmi,
            pLeanBodyMassKg: leanBodyMassKg,
            pSource: source
        )
        try await supabase.rpc("upsert_body_composition", params: params).execute()
    }

    func fetchHistory(days: Int) async throws -> [BodyCompositionLog] {
        let userId = try await supabase.auth.session.user.id
        let cal = Calendar.current
        let startDate = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: .now))!
        return try await supabase
            .from("body_composition_logs")
            .select()
            .eq("user_id", value: userId)
            .gte("log_date", value: startDate.isoDateString)
            .order("log_date", ascending: true)
            .execute()
            .value
    }
}
