import Foundation
import Observation
import Supabase

struct PulseHealthInsightsSnapshot {
    var weekly: [HealthPatternLine] = []
    var cycle: [HealthPatternLine] = []
    var experimentDays: [ExperimentHealthDay] = []
    var experiment: TinyExperiment?
    var cycleDay: Int?
    var interrupted = false
}

/// Screen-owned, ephemeral observations. Opening a card never sends a chat or saves a memory.
@MainActor @Observable
final class PulseHealthInsightsModel {
    private(set) var owner: UUID?
    private(set) var weekly: [HealthPatternLine] = []
    private(set) var cycle: [HealthPatternLine] = []
    private(set) var experimentDays: [ExperimentHealthDay] = []
    private(set) var experiment: TinyExperiment?
    private(set) var cycleDay: Int?
    private(set) var interrupted = false
    private(set) var loading = false
    private(set) var loaded = false
    private(set) var error: String?
    private(set) var accessMessage: String?
    private var request = UUID()
    private var loadedAt: Date?
    private let sessionOwner: @MainActor () -> UUID?
    private let read: @MainActor (UUID, Bool) async throws -> PulseHealthInsightsSnapshot
    init(sessionOwner: @escaping @MainActor () -> UUID? = { supabase.auth.currentSession?.user.id },
         read: (@MainActor (UUID, Bool) async throws -> PulseHealthInsightsSnapshot)? = nil) {
        self.sessionOwner = sessionOwner; self.read = read ?? Self.readSnapshot
    }
    var isPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--health-patterns-preview") || ProcessInfo.processInfo.arguments.contains("--pulse-health-preview")
        #else
        false
        #endif
    }
    var ownsScreen: Bool { isPreview || (owner != nil && sessionOwner() == owner) }
    func configure(owner: UUID?) {
        guard self.owner != owner else { return }
        request = UUID(); self.owner = owner; weekly = []; cycle = []; experimentDays = []; experiment = nil
        cycleDay = nil; interrupted = false; loaded = false; loading = false; error = nil; accessMessage = nil; loadedAt = nil
    }
    func refreshLocalExperiment() {
        guard !isPreview, ownsScreen, owner == EverydayToolsStore.shared.accountId else { return }
        let next = EverydayToolsStore.shared.data.experiments.first { $0.completedOn == nil && $0.healthLink != nil }
        if next?.id != experiment?.id { experimentDays = [] }
        experiment = next
    }
    func load(force: Bool = false, requestAccess: Bool = false) async {
        #if DEBUG
        if isPreview {
            owner = AppStoreScreenshotPreview.sampleUser
            weekly = HealthExperiencePreview.weekly; cycle = HealthExperiencePreview.cycle; cycleDay = 1
            EverydayToolsStore.shared.preview()
            experiment = EverydayToolsStore.shared.data.experiments.first ?? HealthExperiencePreview.experiment()
            experimentDays = HealthExperiencePreview.experimentDays()
            loaded = true; return
        }
        #endif
        guard let owner, ownsScreen, !loading else { return }
        if !force, let loadedAt, Date.now.timeIntervalSince(loadedAt) < 300 { return }
        let token = UUID(); request = token; loading = true; error = nil
        defer { if request == token { loading = false } }
        do {
            if requestAccess {
                let offered = try await HealthKitManager.shared.reconnect()
                guard ownsScreen, request == token else { return }
                accessMessage = offered ? "Your choices are saved in Apple Health." : "Manage Footing’s read choices in the Health app, then refresh here. Empty reads can mean missing data or unavailable access."
            }
            guard ownsScreen, request == token else { return }
            let snapshot = try await read(owner, HealthKitManager.shared.hasRequestedAuthorization)
            guard ownsScreen, request == token, !Task.isCancelled else { return }
            weekly = snapshot.weekly; cycle = snapshot.cycle; experiment = snapshot.experiment
            experimentDays = snapshot.experimentDays; cycleDay = snapshot.cycleDay; interrupted = snapshot.interrupted
            loaded = true; loadedAt = .now
        } catch {
            guard ownsScreen, request == token else { return }
            self.error = "Couldn’t refresh your observations. Please try again."
        }
    }
    private static func readSnapshot(owner: UUID, includeHealth: Bool) async throws -> PulseHealthInsightsSnapshot {
        EverydayToolsStore.shared.setAccount(owner)
        let experiment = EverydayToolsStore.shared.data.experiments.first { $0.completedOn == nil && $0.healthLink != nil }
        let observedDays: [ExperimentHealthDay]
        if let experiment { observedDays = await HealthExperienceReader.experiment(experiment) }
        else { observedDays = [] }
        guard supabase.auth.currentSession?.user.id == owner, !Task.isCancelled else { throw CancellationError() }
        async let reports = ShotCycleRepository().fetchRecent(days: 84)
        async let shots = GLP1Repository().fetchRecentLogs(limit: 20)
        async let skips = GLP1Repository().fetchSkippedDoses()
        let (allReports, allShots, allSkips) = try await (reports, shots, skips)
        let logs = allShots.filter { $0.userId == owner && $0.injectedAt <= .now }
        let latest = logs.max { $0.injectedAt < $1.injectedAt }
        let schedule = GLP1DoseSchedule(latest: latest, skips: allSkips.filter { $0.userId == owner })
        let interrupted = schedule.cycleInterrupted
        let cycleDay: Int? = GLP1TrackingStore.shared.isTracking ? latest.flatMap {
            Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0.injectedAt), to: Calendar.current.startOfDay(for: .now)).day
        } : nil
        let checkIns = allReports.filter { $0.userId == owner }
        var dates = Set(checkIns.filter { $0.cycleDay == cycleDay }.map(\.checkinDate))
        for offset in 1...7 {
            if let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now) { dates.insert(date.isoDateString) }
        }
        var days: [HealthExperienceDay] = []
        if includeHealth {
            for key in dates.filter({ $0 <= Date.now.isoDateString }).sorted().suffix(84) {
                guard supabase.auth.currentSession?.user.id == owner, !Task.isCancelled else { throw CancellationError() }
                if let date = Date.fromISODateString(key) { days.append(await HealthExperienceReader.day(date)) }
            }
        }
        guard supabase.auth.currentSession?.user.id == owner, !Task.isCancelled else { throw CancellationError() }
        let weekly = HealthPatternInsights.week(days: days, checkIns: checkIns)
        let cycle = !interrupted && cycleDay != nil ? HealthPatternInsights.cycle(cycleDay: cycleDay!, injections: logs, skips: allSkips, checkIns: checkIns, days: days, owner: owner) : []

        return .init(weekly: weekly, cycle: cycle, experimentDays: observedDays, experiment: experiment, cycleDay: cycleDay, interrupted: interrupted)
    }

}
