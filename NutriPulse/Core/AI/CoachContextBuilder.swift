import Foundation

// MARK: - Context bundle

// Encodable snapshot of all user data sent to Pulse on each message.
// Structured as JSON so Claude can read it naturally as part of the system prompt.
struct CoachContextBundle: Encodable {
    let currentDateTime: String
    let user: UserContext
    let dailyGoals: GoalContext?
    let today: TodayContext
    let sevenDayHistory: WeekHistoryContext
    let recentWins: [String]
    let weightTrend: WeightTrendContext?
    let healthKit: HealthKitContext?
    let glp1: GLP1Context?

    struct UserContext: Encodable {
        let name: String
        let sex: String?
        let activityLevel: String?
    }

    struct GoalContext: Encodable {
        let calories: Int
        let proteinG: Int
        let carbsG: Int
        let fatG: Int
        let fiberG: Int
    }

    struct TodayContext: Encodable {
        let foodLog: [MealContext]
        let totals: MacroTotals
        let goalProgress: GoalProgress
        let activeCaloriesBurned: Int?
        // Formatted like foodLog items — "Traditional Strength Training (32 min, 208 cal)".
        // nil (not empty) when nothing is logged, so Pulse can't read absence as rest.
        let workouts: [String]?

        struct MealContext: Encodable {
            let meal: String
            let items: [String]
            let calories: Int
            let proteinG: Int
        }

        struct MacroTotals: Encodable {
            let calories: Int
            let proteinG: Int
            let carbsG: Int
            let fatG: Int
            let fiberG: Int
        }

        struct GoalProgress: Encodable {
            let caloriesPct: String
            let proteinPct: String
            let carbsPct: String
            let fatPct: String
        }
    }

    struct WeekHistoryContext: Encodable {
        let daysLogged: Int
        let avgCalories: Int
        let avgProteinG: Int
        let avgCarbsG: Int
        let avgFatG: Int
        let caloriesVsGoal: String?
        let proteinVsGoal: String?
        // Movement across the window — sessions and total minutes, both sources.
        let workoutSessions: Int
        let workoutMinutes: Int
    }

    struct WeightTrendContext: Encodable {
        let mostRecent: String
        let sevenDayChange: String
        let trend: String
    }

    struct HealthKitContext: Encodable {
        let sleepLastNight: String?
        let restingHRBpm: Int?
        let hrv: String?
    }

    struct GLP1Context: Encodable {
        let medication: String
        let doseMg: Double
        let lastInjected: String
        // nil when the log carries no next_due_at. Pulse must not infer a schedule
        // from a missing one — it isn't allowed to advise on dosing or timing anyway.
        let nextDue: String?
        let overdue: Bool
    }
}

// MARK: - Builder

struct CoachContextBuilder {
    private let foodLogRepo = FoodLogRepository()
    private let analyticsRepo = AnalyticsRepository()
    private let goalRepo = GoalRepository()
    private let glp1Repo = GLP1Repository()

    func build(profile: UserProfile?) async -> CoachContextBundle {
        // HealthKitManager.shared is @MainActor — capture it on main actor first
        let hk = await MainActor.run { HealthKitManager.shared }

        async let logsTask = foodLogRepo.fetchLogs(for: .now)
        // 30 days so CelebrationEngine can see streaks longer than a week;
        // the "7-day history" narrative below just slices the tail of this.
        async let summariesTask = analyticsRepo.fetchDailySummaries(days: 30)
        async let goalTask = goalRepo.fetchGoal(for: .now)
        async let glp1Task = glp1Repo.fetchRecentLogs(limit: 1)
        async let weightTask = analyticsRepo.fetchWeightLogs(days: 7)
        async let activeCalTask = hk.fetchActiveCalories(for: .now)
        async let sleepTask = hk.fetchSleepHours(for: .now)
        async let hrTask = hk.fetchRestingHeartRate(for: .now)
        async let hrvTask = hk.fetchHRV(for: .now)

        let logs = (try? await logsTask) ?? []
        let summaries = (try? await summariesTask) ?? []
        let goal: DailyGoal? = (try? await goalTask) ?? nil
        let glp1Logs = (try? await glp1Task) ?? []
        let weightLogs = (try? await weightTask) ?? []
        let activeCal = await activeCalTask
        let sleep = await sleepTask
        let hr = await hrTask
        let hrv = await hrvTask

        // Workouts come from LocalStore, not Supabase: a HealthKit import made seconds
        // ago is still pendingCreate locally, and the coach should know about the
        // session the user just finished. LocalStore is @MainActor, hence the hop.
        var workouts: [WorkoutLog] = []
        if let userId = try? await supabase.auth.session.user.id {
            workouts = await MainActor.run {
                (try? LocalStore.shared.fetchRecentWorkoutLogs(days: 7, userId: userId)) ?? []
            }
        }

        return assemble(
            profile: profile,
            logs: logs,
            summaries: summaries,
            goal: goal,
            glp1Log: glp1Logs.first,
            weightLogs: weightLogs,
            workouts: workouts,
            activeCal: activeCal,
            sleep: sleep,
            hr: hr,
            hrv: hrv
        )
    }

    // MARK: - Private assembly

    private func assemble(
        profile: UserProfile?,
        logs: [FoodLog],
        summaries: [DailySummary],
        goal: DailyGoal?,
        glp1Log: GLP1Log?,
        weightLogs: [WeightLog],
        workouts: [WorkoutLog],
        activeCal: Double?,
        sleep: Double?,
        hr: Double?,
        hrv: Double?
    ) -> CoachContextBundle {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy, h:mm a"
        let dateStr = formatter.string(from: .now)

        // User
        let userCtx = CoachContextBundle.UserContext(
            name: profile?.fullName?.components(separatedBy: " ").first ?? "there",
            sex: profile?.sex,
            activityLevel: profile?.activityLevel
        )

        // Goals
        let goalCtx = goal.map {
            CoachContextBundle.GoalContext(
                calories: Int($0.calories),
                proteinG: Int($0.proteinG),
                carbsG: Int($0.carbsG),
                fatG: Int($0.fatG),
                fiberG: Int($0.fiberG)
            )
        }

        // Today food log grouped by meal
        let grouped = Dictionary(grouping: logs, by: \.meal)
        let mealCtxs: [CoachContextBundle.TodayContext.MealContext] = Meal.allCases.compactMap { meal in
            guard let mealLogs = grouped[meal], !mealLogs.isEmpty else { return nil }
            let items = mealLogs.map { log in
                let cal  = Int(log.totalCalories)
                let pro  = Int(log.totalProteinG)
                let carb = Int(log.totalCarbsG)
                let fat  = Int(log.totalFatG)
                return "\(log.displayName) (\(cal) cal, \(pro)g pro, \(carb)g carbs, \(fat)g fat)"
            }
            return CoachContextBundle.TodayContext.MealContext(
                meal: meal.displayName,
                items: items,
                calories: Int(mealLogs.reduce(0) { $0 + $1.totalCalories }),
                proteinG: Int(mealLogs.reduce(0) { $0 + $1.totalProteinG })
            )
        }

        let totalCal  = logs.reduce(0) { $0 + $1.totalCalories }
        let totalPro  = logs.reduce(0) { $0 + $1.totalProteinG }
        let totalCarb = logs.reduce(0) { $0 + $1.totalCarbsG }
        let totalFat  = logs.reduce(0) { $0 + $1.totalFatG }
        let totalFib  = logs.reduce(0) { $0 + $1.totalFiberG }

        func pct(_ val: Double, _ target: Double?) -> String {
            guard let t = target, t > 0 else { return "N/A" }
            return "\(Int(val / t * 100))%"
        }

        let todayCtx = CoachContextBundle.TodayContext(
            foodLog: mealCtxs,
            totals: .init(
                calories: Int(totalCal),
                proteinG: Int(totalPro),
                carbsG: Int(totalCarb),
                fatG: Int(totalFat),
                fiberG: Int(totalFib)
            ),
            goalProgress: .init(
                caloriesPct: pct(totalCal,  goal?.calories),
                proteinPct:  pct(totalPro,  goal?.proteinG),
                carbsPct:    pct(totalCarb, goal?.carbsG),
                fatPct:      pct(totalFat,  goal?.fatG)
            ),
            // nil when HealthKit reported nothing — don't tell Pulse the user burned zero.
            activeCaloriesBurned: activeCal.map { Int($0.rounded()) },
            workouts: {
                let todayStr = Date.now.isoDateString
                let todays = workouts.filter { $0.logDate == todayStr }.map { w -> String in
                    let minutes = Int(w.durationMinutes.rounded())
                    if let kcal = w.activeCalories, kcal > 0 {
                        return "\(w.displayName) (\(minutes) min, \(Int(kcal.rounded())) cal)"
                    }
                    return "\(w.displayName) (\(minutes) min)"
                }
                return todays.isEmpty ? nil : todays
            }()
        )

        // 7-day history — tail of the wider window fetched above
        let recentSummaries = Array(summaries.suffix(7))
        let loggedDays = recentSummaries.filter { $0.hasData }
        let count = Double(max(loggedDays.count, 1))
        let avgCal  = loggedDays.reduce(0) { $0 + $1.calories  } / count
        let avgPro  = loggedDays.reduce(0) { $0 + $1.proteinG  } / count
        let avgCarb = loggedDays.reduce(0) { $0 + $1.carbsG    } / count
        let avgFat  = loggedDays.reduce(0) { $0 + $1.fatG      } / count

        let weekCtx = CoachContextBundle.WeekHistoryContext(
            daysLogged: loggedDays.count,
            avgCalories: Int(avgCal),
            avgProteinG: Int(avgPro),
            avgCarbsG: Int(avgCarb),
            avgFatG: Int(avgFat),
            caloriesVsGoal: loggedDays.isEmpty ? nil : pct(avgCal, goal?.calories),
            proteinVsGoal:  loggedDays.isEmpty ? nil : pct(avgPro, goal?.proteinG),
            workoutSessions: workouts.count,
            workoutMinutes: Int(workouts.reduce(0) { $0 + $1.durationMinutes }.rounded())
        )

        // Weight trend
        let weightTrend: CoachContextBundle.WeightTrendContext?
        if let latest = weightLogs.last {
            let df = DateFormatter()
            df.dateFormat = "MMMM d"
            let latestStr = "\(String(format: "%.1f", latest.weightKg)) kg (\(df.string(from: latest.loggedAt)))"
            if weightLogs.count > 1, let first = weightLogs.first {
                let delta = latest.weightKg - first.weightKg
                let dir = delta < -0.05 ? "down" : delta > 0.05 ? "up" : "stable"
                weightTrend = .init(
                    mostRecent: latestStr,
                    sevenDayChange: "\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta)) kg",
                    trend: dir
                )
            } else {
                weightTrend = .init(mostRecent: latestStr, sevenDayChange: "only one reading this week", trend: "unknown")
            }
        } else {
            weightTrend = nil
        }

        // HealthKit
        let hkCtx: CoachContextBundle.HealthKitContext?
        if sleep != nil || hr != nil || hrv != nil {
            func formatSleep(_ h: Double) -> String {
                "\(Int(h))h \(Int((h - Double(Int(h))) * 60))m"
            }
            hkCtx = .init(
                sleepLastNight: sleep.map(formatSleep),
                restingHRBpm: hr.map { Int($0) },
                hrv: hrv.map { "\(Int($0))ms" }
            )
        } else {
            hkCtx = nil
        }

        // GLP-1
        let glp1Ctx: CoachContextBundle.GLP1Context?
        if let log = glp1Log {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .full
            let df = DateFormatter()
            df.dateFormat = "MMMM d"
            let lastStr = "\(rel.localizedString(for: log.injectedAt, relativeTo: .now)) (\(df.string(from: log.injectedAt)))"
            // next_due_at is nullable. Absent means "we don't know when the next dose is" —
            // which is emphatically not "overdue".
            let isOverdue = log.nextDueAt.map { $0 < .now } ?? false
            let nextStr = log.nextDueAt.map { due in
                isOverdue
                    ? "overdue since \(df.string(from: due))"
                    : "\(rel.localizedString(for: due, relativeTo: .now)) (\(df.string(from: due)))"
            }
            glp1Ctx = .init(
                medication: log.medication,
                doseMg: log.doseMg,
                lastInjected: lastStr,
                nextDue: nextStr,
                overdue: isOverdue
            )
        } else {
            glp1Ctx = nil
        }

        return CoachContextBundle(
            currentDateTime: dateStr,
            user: userCtx,
            dailyGoals: goalCtx,
            today: todayCtx,
            sevenDayHistory: weekCtx,
            recentWins: CelebrationEngine.detectWins(goal: goal, history: summaries),
            weightTrend: weightTrend,
            healthKit: hkCtx,
            glp1: glp1Ctx
        )
    }
}
