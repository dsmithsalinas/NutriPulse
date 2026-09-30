import Foundation

struct StrongWeekEvidence: Encodable {
    struct NutritionPeriod: Encodable {
        let expectedDays: Int
        let loggedDays: Int
        let averageLoggedCalories: Double?
        let averageLoggedProteinG: Double?
        let daysAtCurrentProteinTarget: Int?
    }
    struct MovementPeriod: Encodable {
        struct Activity: Encodable { let activity: String; let sessions: Int; let minutes: Int }
        let expectedDays: Int
        let daysWithLoggedActivity: Int
        let activities: [Activity]
    }
    struct MetricComparison: Encodable {
        let metric: String
        let recentAverage: Double?
        let recentObservedDays: Int
        let baselineAverage: Double?
        let baselineObservedDays: Int
        let comparisonAvailable: Bool
    }
    struct Experience: Encodable { let date: String; let appetite: Int; let energy: Int }
    let windowEndExclusive: String
    let nutritionAvailable: Bool
    let recentNutrition: NutritionPeriod
    let baselineNutrition: NutritionPeriod
    let movementAvailable: Bool
    let recentMovement: MovementPeriod
    let baselineMovement: MovementPeriod
    let recovery: [MetricComparison]
    let experiences: [Experience]

    static func nutrition(_ days: [DailySummary], expectedDays: Int, target: Double?) -> NutritionPeriod {
        let logged = days.filter { $0.hasData && $0.calories.isFinite && $0.proteinG.isFinite }
        return .init(expectedDays: expectedDays, loggedDays: logged.count,
            averageLoggedCalories: average(logged.map(\.calories)),
            averageLoggedProteinG: average(logged.map(\.proteinG)),
            daysAtCurrentProteinTarget: target.flatMap { threshold in
                threshold > 0 ? logged.filter { $0.proteinG >= threshold }.count : nil
            })
    }
    static func movement(_ workouts: [WorkoutLog], expectedDays: Int) -> MovementPeriod {
        let valid = WorkoutLog.deduplicated(workouts).filter { $0.durationMinutes.isFinite && $0.durationMinutes > 0 }
        let grouped = Dictionary(grouping: valid, by: \.displayName)
        return .init(expectedDays: expectedDays, daysWithLoggedActivity: Set(valid.map(\.logDate)).count,
            activities: grouped.keys.sorted().prefix(10).map { key in
                let rows = grouped[key] ?? []
                return .init(activity: key, sessions: rows.count, minutes: Int(rows.reduce(0) { $0 + $1.durationMinutes }.rounded()))
            })
    }
    static func comparison(metric: String, recent: [Double], baseline: [Double]) -> MetricComparison {
        let recent = recent.filter(\.isFinite), baseline = baseline.filter(\.isFinite)
        return .init(metric: metric, recentAverage: average(recent), recentObservedDays: recent.count,
                     baselineAverage: average(baseline), baselineObservedDays: baseline.count,
                     comparisonAvailable: recent.count >= 3 && baseline.count >= 7)
    }
    private static func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : (values.reduce(0, +) / Double(values.count) * 10).rounded() / 10
    }
}

struct StrongWeekEvidenceBuilder {
    func build(proteinTarget: Double?) async -> StrongWeekEvidence {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        let recentStart = calendar.date(byAdding: .day, value: -7, to: end)!
        let baselineStart = calendar.date(byAdding: .day, value: -28, to: end)!
        let lastDay = calendar.date(byAdding: .day, value: -1, to: end)!
        async let nutritionTask = AnalyticsRepository().fetchDailySummaries(from: baselineStart, through: lastDay)
        async let experiencesTask = ShotCycleRepository().fetchRecent(days: 7)
        async let recoveryTask = recovery(end: end, calendar: calendar)
        let userId = try? await supabase.auth.session.user.id
        let workouts: [WorkoutLog]? = if let userId {
            await MainActor.run { try? LocalStore.shared.fetchRecentWorkoutLogs(days: 29, userId: userId) }
        } else { nil }
        let nutrition = try? await nutritionTask
        // Shot-cycle check-ins are shot information: left out while tracking is paused or stopped.
        let tracking = await MainActor.run { GLP1TrackingStore.shared.isTracking }
        let experiences = tracking ? ((try? await experiencesTask) ?? []) : []
        let recentWorkouts = (workouts ?? []).filter { $0.logDate >= recentStart.isoDateString && $0.logDate < end.isoDateString }
        let baselineWorkouts = (workouts ?? []).filter { $0.logDate >= baselineStart.isoDateString && $0.logDate < recentStart.isoDateString }
        return .init(windowEndExclusive: end.isoDateString, nutritionAvailable: nutrition != nil,
            recentNutrition: StrongWeekEvidence.nutrition((nutrition ?? []).filter { $0.date >= recentStart }, expectedDays: 7, target: proteinTarget),
            baselineNutrition: StrongWeekEvidence.nutrition((nutrition ?? []).filter { $0.date < recentStart }, expectedDays: 21, target: proteinTarget),
            movementAvailable: workouts != nil,
            recentMovement: StrongWeekEvidence.movement(recentWorkouts, expectedDays: 7),
            baselineMovement: StrongWeekEvidence.movement(baselineWorkouts, expectedDays: 21),
            recovery: await recoveryTask,
            experiences: experiences.prefix(7).map { .init(date: $0.checkinDate, appetite: $0.appetite, energy: $0.energy) })
    }

    private func recovery(end: Date, calendar: Calendar) async -> [StrongWeekEvidence.MetricComparison] {
        let hk = await MainActor.run { HealthKitManager.shared }
        var recent: [String: [Double]] = [:], baseline: [String: [Double]] = [:]
        // Sleep's day is its wake date. Include today's sleep but use completed calendar
        // days for movement/nutrition, so a half-finished day cannot look like a decline.
        for offset in 0..<28 {
            let day = calendar.date(byAdding: .day, value: -offset, to: end)!
            let movementDay = calendar.date(byAdding: .day, value: -offset - 1, to: end)!
            async let sleep = hk.fetchSleepHours(for: day)
            async let hr = hk.fetchRestingHeartRate(for: day)
            async let hrv = hk.fetchHRV(for: day)
            async let steps = hk.fetchSteps(for: movementDay)
            let samples: [(String, Double?, ClosedRange<Double>)] = await [
                ("sleepHours", sleep, 0.5...16), ("restingHeartRate", hr, 25...240),
                ("hrvMs", hrv, 1...500), ("steps", steps, 0...100_000)
            ]
            for (name, value, range) in samples {
                guard let value, value.isFinite, range.contains(value) else { continue }
                if offset < 7 { recent[name, default: []].append(value) }
                else { baseline[name, default: []].append(value) }
            }
        }
        return ["sleepHours", "restingHeartRate", "hrvMs", "steps"].map {
            StrongWeekEvidence.comparison(metric: $0, recent: recent[$0] ?? [], baseline: baseline[$0] ?? [])
        }
    }
}
