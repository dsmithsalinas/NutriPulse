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
    var summaries: [DailySummary]          = []
    var weightLogs: [WeightLog]            = []
    var bodyCompHistory: [BodyCompositionLog] = []
    var goalCalories: Double?              = nil

    var bodyFatLogs: [(date: Date, pct: Double)] {
        bodyCompHistory.compactMap { log in
            guard let pct = log.bodyFatPct,
                  let date = ISO8601DateFormatter().date(from: log.logDate + "T00:00:00Z") else { return nil }
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
            async let goalTask       = goalRepo.fetchGoal(for: .now)
            let (s, w, bc, g)        = try await (summariesTask, weightTask, bodyCompTask, goalTask)
            summaries        = s
            weightLogs       = w
            bodyCompHistory  = bc
            goalCalories     = g?.calories
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
