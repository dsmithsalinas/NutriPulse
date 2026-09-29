import Foundation
import Supabase

struct AnalyticsRepository {

    // Fetch daily nutrition totals for the last `days` days, including zeros for
    // days with no food logged so the chart always shows a full continuous x-axis.
    func fetchDailySummaries(days: Int) async throws -> [DailySummary] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today)!
        return try await fetchDailySummaries(from: startDate, through: today)
    }

    func fetchDailySummaries(from startDate: Date, through endDate: Date) async throws -> [DailySummary] {
        let cal = Calendar.current
        let startDate = cal.startOfDay(for: startDate)
        let endDate = cal.startOfDay(for: endDate)
        guard startDate <= endDate else { return [] }
        let days = (cal.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1

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
            .lte("log_date", value: endDate.isoDateString)
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

    // Food names only, one per log row, for Pulse's "what does this person actually eat"
    // context. Server-side rather than LocalStore because the local cache only reliably holds
    // days the user has opened on this device.
    func fetchLoggedFoodNames(from startDate: Date, through endDate: Date) async throws -> [String] {
        struct Row: Decodable {
            struct Item: Decodable { let name: String }
            let foodItems: Item?
            enum CodingKeys: String, CodingKey { case foodItems = "food_items" }
        }
        let cal = Calendar.current
        let rows: [Row] = try await supabase
            .from("food_logs")
            .select("food_items(name)")
            .gte("log_date", value: cal.startOfDay(for: startDate).isoDateString)
            .lte("log_date", value: cal.startOfDay(for: endDate).isoDateString)
            .execute()
            .value
        return rows.compactMap { $0.foodItems?.name }
    }

    // Per-day workout rollup, zeros included — same full-axis contract as
    // fetchDailySummaries so the movement chart never has gaps in its x-axis.
    func fetchDailyMovement(days: Int) async throws -> [DailyMovement] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today)!
        return try await fetchDailyMovement(from: startDate, through: today)
    }

    func fetchDailyMovement(from startDate: Date, through endDate: Date) async throws -> [DailyMovement] {
        let cal = Calendar.current
        let startDate = cal.startOfDay(for: startDate)
        let endDate = cal.startOfDay(for: endDate)
        guard startDate <= endDate else { return [] }
        let days = (cal.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1

        let fetched: [WorkoutLog] = try await supabase
            .from("workout_logs")
            .select()
            .gte("log_date", value: startDate.isoDateString)
            .lte("log_date", value: endDate.isoDateString)
            .execute()
            .value
        let rows = WorkoutLog.deduplicated(fetched)

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

    func fetchDailyHydration(days: Int) async throws -> [DailyHydration] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today)!
        return try await fetchDailyHydration(from: startDate, through: today)
    }

    func fetchDailyHydration(from startDate: Date, through endDate: Date) async throws -> [DailyHydration] {
        let cal = Calendar.current
        let startDate = cal.startOfDay(for: startDate)
        let endDate = cal.startOfDay(for: endDate)
        guard startDate <= endDate else { return [] }
        let days = (cal.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
        let rows: [WaterLog] = try await supabase
            .from("water_logs")
            .select()
            .gte("log_date", value: startDate.isoDateString)
            .lte("log_date", value: endDate.isoDateString)
            .execute()
            .value
        let grouped = Dictionary(grouping: rows, by: \.logDate)
        return (0..<days).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: startDate)!
            return DailyHydration(
                date: date,
                amountMl: (grouped[date.isoDateString] ?? []).reduce(0) { $0 + $1.amountMl }
            )
        }
    }

    func fetchBodyCompositionHistory(days: Int) async throws -> [BodyCompositionLog] {
        try await BodyCompositionRepository().fetchHistory(days: days)
    }

    func fetchWeightLogs(days: Int) async throws -> [WeightLog] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today)!
        return try await fetchWeightLogs(from: startDate, through: today)
    }

    func fetchWeightLogs(from startDate: Date, through endDate: Date) async throws -> [WeightLog] {
        let cal = Calendar.current
        let startDate = cal.startOfDay(for: startDate)
        let endDate = cal.startOfDay(for: endDate)
        guard startDate <= endDate else { return [] }
        let endExclusive = cal.date(byAdding: .day, value: 1, to: endDate)!

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
            .lt("logged_at", value: endExclusive.ISO8601Format())
            .order("logged_at", ascending: true)
            .execute()
            .value
    }
}
