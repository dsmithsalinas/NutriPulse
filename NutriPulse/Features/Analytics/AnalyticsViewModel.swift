import Observation
import Foundation

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
        if ProcessInfo.processInfo.arguments.contains("--progress-preview") {
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
            glp1History      = glp1
            goalCalories     = g?.calories
            goalProteinG     = g?.proteinG
            shotCycleCheckIns = checks
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
        movement = []
        let latestShotOffset = min(4, max(totalDays - 1, 0))
        let latestShotDate = calendar.date(byAdding: .day, value: -latestShotOffset, to: today)!
        hydration = summaries.map { summary in
            let distance = calendar.dateComponents([.day], from: latestShotDate, to: summary.date).day ?? 0
            let cycleDay = (distance % 7 + 7) % 7
            return DailyHydration(date: summary.date, amountMl: [2, 3].contains(cycleDay) ? 1_150 : 1_850)
        }
        weightLogs = []
        bodyCompHistory = []
        let oldestShotOffset = latestShotOffset + ((max(totalDays - 1, latestShotOffset) - latestShotOffset) / 7) * 7
        glp1History = stride(from: oldestShotOffset, through: latestShotOffset, by: -7).map { offset in
            let injectedAt = calendar.date(byAdding: .day, value: -offset, to: today)!
            return GLP1Log(
                id: UUID(), userId: UUID(), injectedAt: injectedAt,
                medication: "Zepbound", doseMg: 5, site: "Left Abdomen",
                nextDueAt: calendar.date(byAdding: .day, value: 7, to: injectedAt)
            )
        }
        shotCycleCheckIns = []
        goalCalories = 1_600
        goalProteinG = 130
        errorMessage = nil
        isLoading = false
    }
    #endif
}
