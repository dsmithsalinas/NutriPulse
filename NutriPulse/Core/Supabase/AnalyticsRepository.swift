import Foundation
import Supabase

struct AnalyticsRepository {

    // Fetch daily nutrition totals for the last `days` days, including zeros for
    // days with no food logged so the chart always shows a full continuous x-axis.
    func fetchDailySummaries(days: Int) async throws -> [DailySummary] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today)!

        struct LogRow: Decodable {
            let logDate: String
            let caloriesSnapshot: Double
            let proteinGSnapshot: Double
            let carbsGSnapshot: Double
            let fatGSnapshot: Double
            let fiberGSnapshot: Double
            let quantity: Double

            enum CodingKeys: String, CodingKey {
                case logDate           = "log_date"
                case caloriesSnapshot  = "calories_snapshot"
                case proteinGSnapshot  = "protein_g_snapshot"
                case carbsGSnapshot    = "carbs_g_snapshot"
                case fatGSnapshot      = "fat_g_snapshot"
                case fiberGSnapshot    = "fiber_g_snapshot"
                case quantity
            }
        }

        let rows: [LogRow] = try await supabase
            .from("food_logs")
            .select("log_date, calories_snapshot, protein_g_snapshot, carbs_g_snapshot, fat_g_snapshot, fiber_g_snapshot, quantity")
            .gte("log_date", value: startDate.isoDateString)
            .lte("log_date", value: today.isoDateString)
            .execute()
            .value

        let grouped = Dictionary(grouping: rows, by: \.logDate)

        return (0..<days).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: startDate)!
            let dayRows = grouped[date.isoDateString] ?? []
            return DailySummary(
                date: date,
                calories: dayRows.reduce(0) { $0 + $1.caloriesSnapshot * $1.quantity },
                proteinG: dayRows.reduce(0) { $0 + $1.proteinGSnapshot * $1.quantity },
                carbsG:   dayRows.reduce(0) { $0 + $1.carbsGSnapshot   * $1.quantity },
                fatG:     dayRows.reduce(0) { $0 + $1.fatGSnapshot      * $1.quantity },
                fiberG:   dayRows.reduce(0) { $0 + $1.fiberGSnapshot    * $1.quantity }
            )
        }
    }

    // Per-day workout rollup, zeros included — same full-axis contract as
    // fetchDailySummaries so the movement chart never has gaps in its x-axis.
    func fetchDailyMovement(days: Int) async throws -> [DailyMovement] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today)!

        struct WorkoutRow: Decodable {
            let logDate: String
            let durationMinutes: Double

            enum CodingKeys: String, CodingKey {
                case logDate         = "log_date"
                case durationMinutes = "duration_minutes"
            }
        }

        let rows: [WorkoutRow] = try await supabase
            .from("workout_logs")
            .select("log_date, duration_minutes")
            .gte("log_date", value: startDate.isoDateString)
            .lte("log_date", value: today.isoDateString)
            .execute()
            .value

        let grouped = Dictionary(grouping: rows, by: \.logDate)

        return (0..<days).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: startDate)!
            let dayRows = grouped[date.isoDateString] ?? []
            return DailyMovement(
                date: date,
                sessions: dayRows.count,
                minutes: dayRows.reduce(0) { $0 + $1.durationMinutes }
            )
        }
    }

    func fetchGLP1History() async throws -> [GLP1Log] {
        try await GLP1Repository().fetchHistory()
    }

    func fetchBodyCompositionHistory(days: Int) async throws -> [BodyCompositionLog] {
        try await BodyCompositionRepository().fetchHistory(days: days)
    }

    func fetchWeightLogs(days: Int) async throws -> [WeightLog] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today)!

        // logged_at is a timestamptz, not a date. Sending "2026-06-29" made Postgres cast it
        // to 2026-06-29 00:00:00+00 — UTC midnight — so a user in California (UTC-7) pulled in
        // weigh-ins from 5pm the previous evening, and users east of UTC lost the first hours
        // of the window. food_logs and body_composition_logs escape this because they filter
        // on real `date` columns; weight_logs has only the timestamp.
        //
        // Send a full ISO-8601 instant for local midnight instead.
        return try await supabase
            .from("weight_logs")
            .select()
            .gte("logged_at", value: startDate.ISO8601Format())
            .order("logged_at", ascending: true)
            .execute()
            .value
    }
}
