import Foundation

struct WeeklyReview: Equatable {
    let wentWell: String
    let gotDifficult: String
    let pattern: String
    let experiment: String
}

enum WeeklyReviewEngine {
    static func build(
        summaries: [DailySummary],
        movement: [DailyMovement],
        checkIns: [ShotCycleCheckIn],
        proteinGoal: Double?
    ) -> WeeklyReview? {
        let week = Array(summaries.suffix(7))
        let logged = week.filter(\.hasData)
        guard logged.count >= 3 else { return nil }

        let averageProtein = logged.reduce(0) { $0 + $1.proteinG } / Double(logged.count)
        let goal = proteinGoal ?? 0
        let proteinHits = goal > 0 ? logged.filter { $0.proteinG >= goal }.count : 0
        let activeDays = Array(movement.suffix(7)).filter(\.hasData).count

        let wentWell: String
        if proteinHits >= max(2, logged.count / 2) {
            wentWell = "You protected your protein floor on \(proteinHits) of \(logged.count) logged days."
        } else if activeDays > 0 {
            wentWell = "You paired \(logged.count) days of nutrition logging with movement on \(activeDays) days."
        } else {
            wentWell = "You showed up and logged on \(logged.count) days — enough to reveal a real pattern."
        }

        let weakest = logged.min(by: { $0.proteinG < $1.proteinG })!
        let gotDifficult = goal > 0
            ? "Protein was hardest on \(weakest.date.formatted(.dateTime.weekday(.wide))): \(Int(weakest.proteinG.rounded()))g against a \(Int(goal.rounded()))g floor."
            : "Your lightest protein day was \(weakest.date.formatted(.dateTime.weekday(.wide))) at \(Int(weakest.proteinG.rounded()))g."

        let recentChecks = checkIns.filter { check in
            guard let date = Date.fromISODateString(check.checkinDate), let first = week.first?.date else { return false }
            return date >= first
        }
        let lowAppetiteDays = recentChecks.filter { $0.appetite <= 2 }.map(\.cycleDay)
        let pattern: String
        if !lowAppetiteDays.isEmpty {
            let days = Array(Set(lowAppetiteDays)).sorted().map(String.init).joined(separator: ", ")
            pattern = "Lower appetite showed up on cycle day\(lowAppetiteDays.count == 1 ? "" : "s") \(days)."
        } else if proteinHits >= 2 {
            pattern = "Average protein held at \(Int(averageProtein.rounded()))g even as the week changed around it."
        } else {
            pattern = "The biggest opportunity is consistency, not perfection: make one meal reliably protein-forward."
        }

        let experiment: String
        if !lowAppetiteDays.isEmpty {
            experiment = "Before your next low-appetite day, stage one small 25–30g protein option you already like."
        } else if goal > 0, averageProtein < goal {
            experiment = "Add 25g of protein to the first meal you log; let the rest of the day stay flexible."
        } else {
            experiment = "Repeat the meal that made your strongest protein day easy."
        }

        return WeeklyReview(wentWell: wentWell, gotDifficult: gotDifficult, pattern: pattern, experiment: experiment)
    }
}

struct DailyHydration: Identifiable {
    let date: Date
    let amountMl: Double
    var id: String { date.isoDateString }
}

struct CycleDayInsight: Identifiable, Equatable {
    let cycleDay: Int
    let sampleCount: Int
    let averageProteinG: Double?
    let averageCalories: Double?
    let averageWaterMl: Double?
    let averageWorkoutMinutes: Double?
    let averageAppetite: Double?
    let averageEnergy: Double?
    let averageNausea: Double?
    let averageWeightKg: Double?
    let nutritionSampleCount: Int
    let hydrationSampleCount: Int
    let movementSampleCount: Int
    let checkInSampleCount: Int
    let weightSampleCount: Int
    var id: Int { cycleDay }
}

enum CycleAnalyticsEngine {
    static func build(
        summaries: [DailySummary],
        hydration: [DailyHydration],
        movement: [DailyMovement],
        weightLogs: [WeightLog],
        checkIns: [ShotCycleCheckIn],
        injections: [GLP1Log],
        calendar: Calendar = .current
    ) -> [CycleDayInsight] {
        guard !injections.isEmpty else { return [] }
        let injectionDates = injections.map { calendar.startOfDay(for: $0.injectedAt) }.sorted()

        func cycleDay(for date: Date) -> Int? {
            let day = calendar.startOfDay(for: date)
            guard let dose = injectionDates.last(where: { $0 <= day }) else { return nil }
            let distance = calendar.dateComponents([.day], from: dose, to: day).day ?? -1
            return (0...13).contains(distance) ? distance : nil
        }

        let summaryGroups = Dictionary(grouping: summaries.filter(\.hasData)) { cycleDay(for: $0.date) }
        let waterGroups = Dictionary(grouping: hydration) { cycleDay(for: $0.date) }
        let movementGroups = Dictionary(grouping: movement.filter(\.hasData)) { cycleDay(for: $0.date) }
        let weightGroups = Dictionary(grouping: weightLogs) { cycleDay(for: $0.loggedAt) }
        let checkGroups = Dictionary(grouping: checkIns) { Optional($0.cycleDay) }
        let availableDays = Set(summaryGroups.keys.compactMap { $0 })
            .union(waterGroups.keys.compactMap { $0 })
            .union(movementGroups.keys.compactMap { $0 })
            .union(checkGroups.keys.compactMap { $0 })

        func average<T>(_ values: [T], _ value: (T) -> Double) -> Double? {
            guard !values.isEmpty else { return nil }
            return values.reduce(0) { $0 + value($1) } / Double(values.count)
        }

        return availableDays.sorted().map { day in
            let nutrition = summaryGroups[day] ?? []
            let water = waterGroups[day] ?? []
            let workouts = movementGroups[day] ?? []
            let weights = weightGroups[day] ?? []
            let checks = checkGroups[day] ?? []
            return CycleDayInsight(
                cycleDay: day,
                sampleCount: max(nutrition.count, max(checks.count, water.count)),
                averageProteinG: average(nutrition, \.proteinG),
                averageCalories: average(nutrition, \.calories),
                averageWaterMl: average(water, \.amountMl),
                averageWorkoutMinutes: average(workouts, \.minutes),
                averageAppetite: average(checks) { Double($0.appetite) },
                averageEnergy: average(checks) { Double($0.energy) },
                averageNausea: average(checks) { Double($0.nausea) },
                averageWeightKg: average(weights, \.weightKg),
                nutritionSampleCount: nutrition.count,
                hydrationSampleCount: water.count,
                movementSampleCount: workouts.count,
                checkInSampleCount: checks.count,
                weightSampleCount: weights.count
            )
        }
    }
}

struct RecoveryContext: Equatable {
    let headline: String
    let signals: [String]
    let suggestion: String
}

enum RecoveryContextEngine {
    static func build(
        sleepHours: Double?, baselineSleep: Double?,
        hrv: Double?, baselineHRV: Double?,
        restingHR: Double?, baselineRestingHR: Double?,
        workoutMinutes: Double,
        proteinG: Double, proteinGoalG: Double?,
        waterMl: Double, waterGoalMl: Double?
    ) -> RecoveryContext? {
        var signals: [String] = []
        var strained = 0

        if let sleepHours, let baselineSleep, baselineSleep > 0 {
            let delta = sleepHours - baselineSleep
            if delta <= -0.75 { strained += 1; signals.append("Sleep was \(String(format: "%.1f", abs(delta)))h below your recent baseline.") }
            else if delta >= 0.5 { signals.append("Sleep was above your recent baseline.") }
            else { signals.append("Sleep was close to your recent baseline.") }
        }
        if let hrv, let baselineHRV, baselineHRV > 0 {
            let pct = (hrv - baselineHRV) / baselineHRV
            if pct <= -0.15 { strained += 1; signals.append("HRV is lower than your recent pattern.") }
            else if pct >= 0.15 { signals.append("HRV is higher than your recent pattern.") }
            else { signals.append("HRV is near your recent pattern.") }
        }
        if let restingHR, let baselineRestingHR, baselineRestingHR > 0 {
            let delta = restingHR - baselineRestingHR
            if delta >= 5 { strained += 1; signals.append("Resting heart rate is \(Int(delta.rounded())) bpm above your recent baseline.") }
            else { signals.append("Resting heart rate is within your recent range.") }
        }
        if workoutMinutes >= 45 { signals.append("You have \(Int(workoutMinutes.rounded())) workout minutes on the board today.") }
        guard signals.count >= 2 else { return nil }

        let proteinBehind = proteinGoalG.map { proteinG < $0 * 0.7 } ?? false
        let waterBehind = waterGoalMl.map { waterMl < $0 * 0.6 } ?? false
        let headline = strained >= 2 ? "Give recovery more room today" : strained == 1 ? "One recovery signal is asking for attention" : "Your signals look steady"
        let suggestion: String
        if proteinBehind && waterBehind { suggestion = "Keep today simple: fluids, an easy protein option, and a lighter pace if your body agrees." }
        else if proteinBehind { suggestion = "An easy protein-forward meal would support what your body is doing today." }
        else if waterBehind { suggestion = "Hydration is the clearest next move; build it gradually through the day." }
        else { suggestion = "No score to chase — use this context alongside how you actually feel." }
        return RecoveryContext(headline: headline, signals: signals, suggestion: suggestion)
    }
}

struct BodyMilestone: Identifiable, Equatable {
    let title: String
    let detail: String
    var id: String { title }
}

enum BodyMilestoneEngine {
    // `weight`/`leanMass` are stored kg, `waist` stored cm — `units` converts anything that
    // lands in the copy the user reads, so an imperial user never sees a stray "cm".
    static func detect(
        weight: [(date: Date, value: Double)],
        leanMass: [(date: Date, value: Double)],
        waist: [(date: Date, value: Double)],
        units: UnitSystem = .metric
    ) -> [BodyMilestone] {
        var results: [BodyMilestone] = []
        let weightDelta = BodyHubViewModel.delta(weight)
        let leanDelta = BodyHubViewModel.delta(leanMass)
        let waistDelta = BodyHubViewModel.delta(waist)

        if let weightDelta, weightDelta <= -1,
           BodyHubViewModel.leanHeldSteady(deltaKg: leanDelta, baselineKg: leanMass.first?.value) == true {
            results.append(.init(title: "Lean mass held", detail: "Your weight moved down while lean mass stayed within its steady range."))
        }
        if let waistDelta, waistDelta <= -2 {
            let magnitude = units.formatLength(abs(waistDelta))
            results.append(.init(title: "Waist trend moved", detail: "Your waist measurement is down \(magnitude) across this view."))
        }
        if let weightDelta, let baseline = weight.first?.value, baseline > 0,
           abs(weightDelta) / baseline <= 0.01, let waistDelta, waistDelta <= -1 {
            results.append(.init(title: "Progress beyond the scale", detail: "Weight held steady while your waist measurement moved down."))
        }
        return results
    }
}
