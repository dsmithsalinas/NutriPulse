import Foundation
import Observation

@Observable
@MainActor
final class ProgressSummaryViewModel {
    private(set) var summaries: [DailySummary] = []
    private(set) var shots: [GLP1Log] = []
    private(set) var proteinGoal: Double?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let analyticsRepository = AnalyticsRepository()
    private let goalRepository = GoalRepository()
    private let glp1Repository = GLP1Repository()

    func load() async {
        guard !isLoading else { return }
        #if DEBUG
        if DebugLaunch.has("--progress-preview") {
            loadPreview()
            return
        }
        #endif

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let shotsTask = glp1Repository.fetchHistory()
            async let goalTask = goalRepository.fetchGoal(for: .now)
            let (loadedShots, goal) = try await (shotsTask, goalTask)

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            let historyStart = calendar.date(byAdding: .day, value: -269, to: today) ?? today
            let recentCycleStart = loadedShots.suffix(4).first.map { calendar.startOfDay(for: $0.injectedAt) }
            let start = min(historyStart, recentCycleStart ?? historyStart)
            let loadedSummaries = try await analyticsRepository.fetchDailySummaries(from: start, through: today)

            guard !Task.isCancelled else { return }
            summaries = loadedSummaries
            shots = loadedShots
            proteinGoal = goal?.proteinG
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Summaries couldn’t refresh. Check your connection and try again."
        }
    }

    #if DEBUG
    private func loadPreview() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        summaries = (0..<270).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - 269, to: today)!
            let recentIndex = offset - 240
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
        shots = stride(from: 88, through: 4, by: -7).map { offset in
            let injectedAt = calendar.date(byAdding: .day, value: -offset, to: today)!
            return GLP1Log(
                id: UUID(), userId: UUID(), injectedAt: injectedAt,
                medication: "Zepbound", doseMg: 5, site: "Left Abdomen",
                nextDueAt: calendar.date(byAdding: .day, value: 7, to: injectedAt)
            )
        }
        proteinGoal = 130
        errorMessage = nil
        isLoading = false
    }
    #endif
}
