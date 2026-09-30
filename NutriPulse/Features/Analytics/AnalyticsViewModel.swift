import Observation
import Foundation
import Supabase

@Observable
@MainActor
final class AnalyticsViewModel {

    enum TimeRange: Int, CaseIterable, Identifiable, Hashable {
        case week     = 7
        case twoWeeks = 14
        case month    = 30
        case quarter  = 90

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .week:     return "7 days"
            case .twoWeeks: return "14 days"
            case .month:    return "30 days"
            case .quarter:  return "90 days"
            }
        }
    }

    var selectedRange: TimeRange = .week
    var summaries: [DailySummary]             = []
    var movement: [DailyMovement]             = []
    var hydration: [DailyHydration]           = []
    var weightLogs: [WeightLog]               = []
    var bodyCompHistory: [BodyCompositionLog] = []
    var glp1History: [GLP1Log]               = []
    var shotCycleCheckIns: [ShotCycleCheckIn] = []
    var goalCalories: Double?                 = nil
    var goalProteinG: Double?                 = nil
    // Local-only, for the "Where does my protein come from?" question — see AnalyticsQuestions.
    // Loaded once per range change alongside everything else, never per chip tap.
    var foodLogs: [FoodLog]                   = []

    // `log_date` is written with the LOCAL calendar (Date.isoDateString) and must be read back
    // the same way. Parsing it as UTC midnight — `logDate + "T00:00:00Z"` — put a US Pacific
    // user's body-fat point at 5pm the previous day, one column to the left of the calories
    // and weight charts built from the very same log. It also allocated a fresh
    // ISO8601DateFormatter per element, on every SwiftUI body evaluation, since this is a
    // computed property read directly from `body`.
    var bodyFatLogs: [(date: Date, pct: Double)] {
        bodyCompHistory.compactMap { log in
            guard let pct = log.bodyFatPct,
                  let date = Date.fromISODateString(log.logDate) else { return nil }
            return (date, pct)
        }
    }
    var isLoading                 = false
    var errorMessage: String?     = nil

    private var activeLoadID = UUID()

    private let repo     = AnalyticsRepository()
    private let goalRepo = GoalRepository()
    private let shotCycleRepo = ShotCycleRepository()

    init(selectedRange: TimeRange = .week) {
        self.selectedRange = selectedRange
    }

    // Only count days where the user actually logged something
    var loggedDays: [DailySummary] { summaries.filter(\.hasData) }

    var averageCalories: Double {
        guard !loggedDays.isEmpty else { return 0 }
        return loggedDays.reduce(0) { $0 + $1.calories } / Double(loggedDays.count)
    }

    var averageProteinG: Double {
        guard !loggedDays.isEmpty else { return 0 }
        return loggedDays.reduce(0) { $0 + $1.proteinG } / Double(loggedDays.count)
    }

    var weightChange: Double? {
        guard weightLogs.count >= 2 else { return nil }
        return weightLogs.last!.weightKg - weightLogs.first!.weightKg
    }

    // Movement rollups — active days only, so a rest day doesn't drag the average.
    var activeDays: [DailyMovement] { movement.filter(\.hasData) }
    var totalWorkoutSessions: Int { activeDays.reduce(0) { $0 + $1.sessions } }
    var avgMinutesPerActiveDay: Double {
        guard !activeDays.isEmpty else { return 0 }
        return activeDays.reduce(0) { $0 + $1.minutes } / Double(activeDays.count)
    }

    var weeklyReview: WeeklyReview? {
        WeeklyReviewEngine.build(
            summaries: summaries,
            movement: movement,
            checkIns: shotCycleCheckIns,
            proteinGoal: goalProteinG
        )
    }

    // MARK: - Question data

    var proteinSources: [ProteinSource] {
        ProteinSourceAggregator.topSources(from: foodLogs)
    }

    var doseChanges: [DoseChangeMark] {
        GLP1DoseChangeDetector.changes(in: glp1History)
    }

    var cycleInsights: [CycleDayInsight] {
        CycleAnalyticsEngine.build(
            summaries: summaries,
            hydration: hydration,
            movement: movement,
            weightLogs: weightLogs,
            checkIns: shotCycleCheckIns,
            injections: glp1History
        )
    }

    func loadData() async {
        let loadID = UUID()
        activeLoadID = loadID
        #if DEBUG
        if DebugLaunch.has("--progress-preview") {
            loadProgressPreview()
            return
        }
        #endif
        isLoading = true
        errorMessage = nil
        do {
            async let summariesTask  = repo.fetchDailySummaries(days: selectedRange.rawValue)
            async let movementTask   = repo.fetchDailyMovement(days: selectedRange.rawValue)
            async let hydrationTask  = repo.fetchDailyHydration(days: selectedRange.rawValue)
            async let weightTask     = repo.fetchWeightLogs(days: selectedRange.rawValue)
            async let bodyCompTask   = repo.fetchBodyCompositionHistory(days: selectedRange.rawValue)
            async let glp1Task       = repo.fetchGLP1History()
            async let goalTask       = goalRepo.fetchGoal(for: .now)
            async let checkInTask    = shotCycleRepo.fetchRecent(days: max(selectedRange.rawValue, 42))
            let (s, m, water, w, bc, glp1, g, checks) = try await (summariesTask, movementTask, hydrationTask, weightTask, bodyCompTask, glp1Task, goalTask, checkInTask)
            guard activeLoadID == loadID, !Task.isCancelled else { return }
            summaries        = s
            movement         = m
            hydration        = water
            weightLogs       = w
            bodyCompHistory  = bc
            // Paused or stopped: no shot-cycle questions, dose tags or cycle insights.
            let tracking = GLP1TrackingStore.shared.isTracking
            glp1History      = tracking ? glp1 : []
            goalCalories     = g?.calories
            goalProteinG     = g?.proteinG
            shotCycleCheckIns = tracking ? checks : []
            // LocalStore only, no network — safe to run after the guard above without racing
            // a second range switch. userId failing just means "no protein sources", not an error.
            if let userId = try? await supabase.auth.session.user.id {
                let cal = Calendar.current
                let since = cal.date(byAdding: .day, value: -(selectedRange.rawValue - 1), to: cal.startOfDay(for: .now)) ?? .now
                foodLogs = (try? LocalStore.shared.fetchFoodLogs(since: since, userId: userId)) ?? []
            } else {
                foodLogs = []
            }
        } catch {
            guard activeLoadID == loadID, !Task.isCancelled else { return }
            errorMessage = "Progress couldn’t refresh. Check your connection and try again."
        }
        if activeLoadID == loadID { isLoading = false }
    }

    #if DEBUG
    private func loadProgressPreview() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let totalDays = selectedRange.rawValue
        summaries = (0..<totalDays).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - (totalDays - 1), to: today)!
            let recentIndex = offset - max(totalDays - 30, 0)
            let isMissing = recentIndex >= 0 && [3, 8, 14, 20, 26, 29].contains(recentIndex)
            let isBelow = recentIndex >= 0 && [1, 6, 11, 16, 22, 27].contains(recentIndex)
            return DailySummary(
                date: date,
                calories: isMissing ? 0 : (isBelow ? 1_180 : 1_460),
                proteinG: isMissing ? 0 : (isBelow ? 94 : 138),
                carbsG: isMissing ? 0 : 122,
                fatG: isMissing ? 0 : 48,
                fiberG: isMissing ? 0 : 22
            )
        }
        // Active roughly two days in three, so "Am I moving more?" has a real pattern to show.
        movement = summaries.map { day in
            let offsetFromToday = calendar.dateComponents([.day], from: day.date, to: today).day ?? 0
            let active = offsetFromToday % 3 != 0
            return DailyMovement(date: day.date, sessions: active ? 1 : 0, minutes: active ? Double(25 + (offsetFromToday % 4) * 5) : 0)
        }
        let latestShotOffset = min(4, max(totalDays - 1, 0))
        let latestShotDate = calendar.date(byAdding: .day, value: -latestShotOffset, to: today)!
        hydration = summaries.map { summary in
            let distance = calendar.dateComponents([.day], from: latestShotDate, to: summary.date).day ?? 0
            let cycleDay = (distance % 7 + 7) % 7
            return DailyHydration(date: summary.date, amountMl: [2, 3].contains(cycleDay) ? 1_150 : 1_850)
        }
        // A weigh-in roughly every other day with a gentle downward trend, so "Is my weight
        // trend real?" has a smoothed line and a takeaway to compute rather than an empty chart.
        weightLogs = stride(from: totalDays - 1, through: 0, by: -2).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let daysIn = Double(totalDays - 1 - offset)
            let noise = [0.4, -0.2, 0.1][offset % 3]
            return WeightLog(id: UUID(), userId: UUID(), loggedAt: date, weightKg: 84.0 - daysIn * 0.03 + noise, source: "manual")
        }
        // A scan roughly every week, trending down slightly — sparse on short ranges (honestly
        // "too early to see a trend" there), a real trend on longer ones.
        bodyCompHistory = stride(from: totalDays - 1, through: 0, by: -7).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let progress = Double(totalDays - 1 - offset) / Double(max(totalDays - 1, 1))
            return BodyCompositionLog(
                id: UUID(), userId: UUID(), logDate: date.isoDateString,
                weightKg: nil, bodyFatPct: 29.0 - progress * 2.5, bmi: nil, leanBodyMassKg: nil,
                source: "manual", createdAt: date
            )
        }
        // Titrates 2.5 → 5.0 → 7.5 mg over the shots in range, so "How do shot days change my
        // eating?" gets its cycle chart AND the weight chart gets a couple of real dose changes
        // to mark, not just repeated shots at one dose.
        let doseSteps: [Double] = [2.5, 2.5, 5.0, 5.0, 5.0, 7.5, 7.5, 7.5, 7.5, 7.5, 7.5, 7.5, 7.5]
        let oldestShotOffset = latestShotOffset + ((max(totalDays - 1, latestShotOffset) - latestShotOffset) / 7) * 7
        glp1History = stride(from: oldestShotOffset, through: latestShotOffset, by: -7).enumerated().map { index, offset in
            let injectedAt = calendar.date(byAdding: .day, value: -offset, to: today)!
            return GLP1Log(
                id: UUID(), userId: UUID(), injectedAt: injectedAt,
                medication: "Zepbound", doseMg: doseSteps[min(index, doseSteps.count - 1)], site: "Left Abdomen",
                nextDueAt: calendar.date(byAdding: .day, value: 7, to: injectedAt)
            )
        }
        shotCycleCheckIns = []
        goalCalories = 1_600
        goalProteinG = 130
        // A handful of protein-forward foods repeated across the range, so "Where does my
        // protein come from?" has real names, grams and counts to aggregate rather than an
        // empty state.
        let proteinFoods: [(name: String, protein: Double, calories: Double, carbs: Double, fat: Double, fiber: Double)] = [
            ("Greek Yogurt", 20, 150, 8, 4, 0),
            ("Turkey Chili", 28, 320, 22, 10, 6),
            ("Grilled Chicken Breast", 35, 250, 0, 6, 0),
            ("Protein Shake", 25, 180, 5, 3, 1),
            ("Scrambled Eggs", 18, 220, 2, 15, 0),
            ("Cottage Cheese", 14, 120, 5, 3, 0),
        ]
        foodLogs = (0..<min(totalDays, 30)).flatMap { offset -> [FoodLog] in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let first = proteinFoods[offset % proteinFoods.count]
            let second = proteinFoods[(offset + 2) % proteinFoods.count]
            return [first, second].enumerated().map { index, food in
                FoodLog(
                    id: UUID(), userId: UUID(), loggedAt: date, logDate: date.isoDateString,
                    meal: index == 0 ? .breakfast : .dinner, foodItemId: UUID(), quantity: 1,
                    caloriesSnapshot: food.calories, proteinGSnapshot: food.protein,
                    carbsGSnapshot: food.carbs, fatGSnapshot: food.fat, fiberGSnapshot: food.fiber,
                    foodItems: FoodItemSummary(name: food.name, brand: nil, servingDesc: nil)
                )
            }
        }
        errorMessage = nil
        isLoading = false
    }
    #endif
}
