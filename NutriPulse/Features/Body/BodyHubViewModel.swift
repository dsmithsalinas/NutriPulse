import Observation
import Foundation

@Observable
@MainActor
final class BodyHubViewModel {

    enum TimeRange: Int, CaseIterable, Identifiable {
        case month    = 30
        case quarter  = 90
        case halfYear = 180
        case all      = 1095

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .month:    return "1M"
            case .quarter:  return "3M"
            case .halfYear: return "6M"
            case .all:      return "All"
            }
        }
        // Used inside insight sentences — "your waist moved this quarter…"
        var phrase: String {
            switch self {
            case .month:    return "this month"
            case .quarter:  return "this quarter"
            case .halfYear: return "these six months"
            case .all:      return "overall"
            }
        }
    }

    var selectedRange: TimeRange = .quarter
    var weightLogs: [WeightLog] = []
    var compLogs: [BodyCompositionLog] = []
    // Within the selected range, grouped by site.
    var siteHistory: [MeasurementSite: [BodyMeasurementLog]] = [:]
    // All-time latest per site — a row keeps showing its last value even when the
    // selected range predates it, the same way a scale app never blanks your weight.
    var latestPerSite: [MeasurementSite: BodyMeasurementLog] = [:]
    var goals: BodyGoals? = nil
    var isLoading = false

    private let analyticsRepo   = AnalyticsRepository()
    private let compRepo        = BodyCompositionRepository()
    private let measurementRepo = BodyMeasurementRepository()
    private let goalsRepo       = BodyGoalsRepository()

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        async let weightTask  = analyticsRepo.fetchWeightLogs(days: selectedRange.rawValue)
        async let compTask    = compRepo.fetchHistory(days: selectedRange.rawValue)
        async let historyTask = measurementRepo.fetchHistoryAll(days: selectedRange.rawValue)
        async let latestTask  = measurementRepo.fetchLatestPerSite()
        async let goalsTask   = goalsRepo.fetch()

        weightLogs = (try? await weightTask) ?? []
        goals = (try? await goalsTask) ?? nil
        compLogs   = (try? await compTask) ?? []
        var grouped: [MeasurementSite: [BodyMeasurementLog]] = [:]
        for row in (try? await historyTask) ?? [] {
            guard let site = row.siteType else { continue }
            grouped[site, default: []].append(row)
        }
        siteHistory = grouped
        latestPerSite = (try? await latestTask) ?? [:]
    }

    // MARK: - Series (date-ordered, storage units)

    var weightSeries: [(date: Date, value: Double)] {
        weightLogs.map { ($0.loggedAt, $0.weightKg) }
    }

    var bodyFatSeries: [(date: Date, value: Double)] {
        compLogs.compactMap { log in
            guard let pct = log.bodyFatPct, let date = Date.fromISODateString(log.logDate) else { return nil }
            return (date, pct)
        }
    }

    var leanSeries: [(date: Date, value: Double)] {
        compLogs.compactMap { log in
            guard let kg = log.leanBodyMassKg, let date = Date.fromISODateString(log.logDate) else { return nil }
            return (date, kg)
        }
    }

    func siteSeries(_ site: MeasurementSite) -> [(date: Date, value: Double)] {
        (siteHistory[site] ?? []).compactMap { row in
            guard let date = Date.fromISODateString(row.logDate) else { return nil }
            return (date, row.valueCm)
        }
    }

    // Sites with any data ever (rows), and the rest (the "track another" affordance).
    var trackedSites: [MeasurementSite] {
        MeasurementSite.allCases.filter { latestPerSite[$0] != nil }
    }
    var untrackedSites: [MeasurementSite] {
        MeasurementSite.allCases.filter { latestPerSite[$0] == nil }
    }

    // MARK: - Pure trend helpers (testable without a network)

    nonisolated static func delta(_ series: [(date: Date, value: Double)]) -> Double? {
        guard series.count >= 2, let first = series.first, let last = series.last else { return nil }
        return last.value - first.value
    }

    // Lean mass is a FLOOR: within ±2% of its starting value counts as held — the happy
    // state, worded as such ("holding steady"), never as a zero on a progress meter.
    nonisolated static func leanHeldSteady(deltaKg: Double?, baselineKg: Double?) -> Bool? {
        guard let deltaKg, let baselineKg, baselineKg > 0 else { return nil }
        return abs(deltaKg) / baselineKg <= 0.02
    }

    // The insight card. Hand-written rules with strict triggers, first match wins — no
    // generated copy. Both rules only fire on a waist DECREASE: a waist increase gets no
    // commentary at all, per the non-shaming law.
    nonisolated static func insight(
        waistDeltaCm: Double?, waistPoints: Int,
        leanDeltaKg: Double?, leanBaselineKg: Double?, leanPoints: Int,
        weightDeltaKg: Double?, weightBaselineKg: Double?, weightPoints: Int,
        rangePhrase: String
    ) -> String? {
        let waistDown = (waistDeltaCm ?? 0) <= -1.0 && waistPoints >= 2

        // The product thesis in one sentence: fat moved, muscle didn't.
        if waistDown,
           leanPoints >= 2,
           leanHeldSteady(deltaKg: leanDeltaKg, baselineKg: leanBaselineKg) == true {
            return "Your waist moved \(rangePhrase) while lean mass held steady."
        }
        // The classic GLP-1 stall reassurance: scale flat, tape not.
        if waistDown,
           weightPoints >= 2,
           let weightDeltaKg, let weightBaselineKg, weightBaselineKg > 0,
           abs(weightDeltaKg) / weightBaselineKg <= 0.01 {
            return "The scale held still \(rangePhrase), but your waist didn't — that's change the scale can't see."
        }
        return nil
    }

    func saveGoals(weightKgTarget: Double?, bodyFatPctTarget: Double?, leanMassKgFloor: Double?) async {
        try? await goalsRepo.upsert(
            weightKgTarget: weightKgTarget,
            bodyFatPctTarget: bodyFatPctTarget,
            leanMassKgFloor: leanMassKgFloor
        )
        goals = (try? await goalsRepo.fetch()) ?? nil
    }

    // The goal (or floor) attached to a metric, if any. Measurement sites have none.
    func goalValue(for metric: BodyMetric) -> Double? {
        switch metric {
        case .weight:   return goals?.weightKgTarget
        case .bodyFat:  return goals?.bodyFatPctTarget
        case .leanMass: return goals?.leanMassKgFloor
        case .site:     return nil
        }
    }

    var insightText: String? {
        let waist = siteSeries(.waist)
        let lean = leanSeries
        let weight = weightSeries
        return Self.insight(
            waistDeltaCm: Self.delta(waist), waistPoints: waist.count,
            leanDeltaKg: Self.delta(lean), leanBaselineKg: lean.first?.value, leanPoints: lean.count,
            weightDeltaKg: Self.delta(weight), weightBaselineKg: weight.first?.value, weightPoints: weight.count,
            rangePhrase: selectedRange.phrase
        )
    }
}
