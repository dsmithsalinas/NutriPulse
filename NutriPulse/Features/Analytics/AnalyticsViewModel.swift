import Observation
import Foundation

@Observable
@MainActor
final class AnalyticsViewModel {

    enum TimeRange: Int, CaseIterable, Identifiable, Hashable {
        case week     = 7
        case twoWeeks = 14
        case month    = 30

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .week:     return "7 days"
            case .twoWeeks: return "14 days"
            case .month:    return "30 days"
            }
        }
    }

    var selectedRange: TimeRange = .week
    var summaries: [DailySummary]             = []
    var weightLogs: [WeightLog]               = []
    var bodyCompHistory: [BodyCompositionLog] = []
    var glp1History: [GLP1Log]               = []
    var goalCalories: Double?                 = nil

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

    private let repo     = AnalyticsRepository()
    private let goalRepo = GoalRepository()

    // Only count days where the user actually logged something
    var loggedDays: [DailySummary] { summaries.filter(\.hasData) }

    var averageCalories: Double {
        guard !loggedDays.isEmpty else { return 0 }
        return loggedDays.reduce(0) { $0 + $1.calories } / Double(loggedDays.count)
    }

    var weightChange: Double? {
        guard weightLogs.count >= 2 else { return nil }
        return weightLogs.last!.weightKg - weightLogs.first!.weightKg
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let summariesTask  = repo.fetchDailySummaries(days: selectedRange.rawValue)
            async let weightTask     = repo.fetchWeightLogs(days: selectedRange.rawValue)
            async let bodyCompTask   = repo.fetchBodyCompositionHistory(days: selectedRange.rawValue)
            async let glp1Task       = repo.fetchGLP1History()
            async let goalTask       = goalRepo.fetchGoal(for: .now)
            let (s, w, bc, glp1, g)  = try await (summariesTask, weightTask, bodyCompTask, glp1Task, goalTask)
            summaries        = s
            weightLogs       = w
            bodyCompHistory  = bc
            glp1History      = glp1
            goalCalories     = g?.calories
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
