import Foundation

// Pure logic for Personal experiments: comparing an outcome across intervention/non-intervention
// days, and finding starter experiments in the user's own recent patterns. No networking, no
// SwiftUI — everything here takes plain data in and returns a plain result, so it's cheap to
// test and safe to call from a computed property.

// MARK: - Honest result comparison

/// One measured day: whether the intervention goal was checked in as done, and the outcome
/// value recorded that day. Either side can be missing — a day only counts toward the
/// comparison once both are known.
struct ExperimentDayObservation: Equatable {
    let localDate: String
    let didIntervene: Bool?
    let outcomeValue: Double?
}

struct ExperimentComparisonResult: Equatable {
    let interventionMean: Double
    let interventionCount: Int
    let nonInterventionMean: Double
    let nonInterventionCount: Int
    /// Intervention mean minus non-intervention mean, in the outcome's own unit.
    let difference: Double
    /// False when there isn't enough data, or the difference is within normal day-to-day noise.
    /// The view should show `Self.notEnoughDataMessage` rather than the numbers when this is
    /// false — the numbers above are still returned so a caller can log/debug, but they should
    /// never be presented as a finding.
    let isReadable: Bool

    static let notEnoughDataMessage = "Not enough data to tell yet"
}

enum ExperimentComparisonEngine {
    /// Fewer measured days than this on either side and there isn't enough data to say anything.
    static let minimumSampleSize = 5
    /// A difference has to clear this fraction of the pooled standard deviation to be called
    /// out — otherwise it reads as ordinary day-to-day variation, not a pattern.
    static let noiseFraction = 0.5

    /// Builds day observations by joining an outcome-by-date map with an intervention-by-date
    /// map (from the goal's own boolean check-ins). Dates are matched as plain `yyyy-MM-dd`
    /// strings, so no calendar/timezone reasoning is needed here.
    static func days(
        outcomeByDate: [String: Double],
        interventionByDate: [String: Bool]
    ) -> [ExperimentDayObservation] {
        let allDates = Set(outcomeByDate.keys).union(interventionByDate.keys)
        return allDates.sorted().map { date in
            ExperimentDayObservation(
                localDate: date,
                didIntervene: interventionByDate[date],
                outcomeValue: outcomeByDate[date]
            )
        }
    }

    /// Compares the outcome on days the user did the intervention against days they didn't.
    /// Returns `nil` only when there's no data at all on one side (nothing to compare); an
    /// unreadable-but-present comparison comes back with `isReadable == false` instead, so the
    /// view can still show "Not enough data to tell yet" with the day counts underneath it.
    static func compare(_ days: [ExperimentDayObservation]) -> ExperimentComparisonResult? {
        let intervention = days.compactMap { $0.didIntervene == true ? $0.outcomeValue : nil }
        let nonIntervention = days.compactMap { $0.didIntervene == false ? $0.outcomeValue : nil }
        guard !intervention.isEmpty, !nonIntervention.isEmpty else { return nil }

        let interventionMean = mean(intervention)
        let nonInterventionMean = mean(nonIntervention)
        let difference = interventionMean - nonInterventionMean

        let enoughDays = intervention.count >= minimumSampleSize && nonIntervention.count >= minimumSampleSize
        let pooledSD = pooledStandardDeviation(intervention, nonIntervention)
        let clearsNoise = pooledSD.map { abs(difference) >= $0 * noiseFraction } ?? true

        return ExperimentComparisonResult(
            interventionMean: interventionMean,
            interventionCount: intervention.count,
            nonInterventionMean: nonInterventionMean,
            nonInterventionCount: nonIntervention.count,
            difference: difference,
            isReadable: enoughDays && clearsNoise
        )
    }

    private static func mean(_ values: [Double]) -> Double {
        values.reduce(0, +) / Double(values.count)
    }

    private static func pooledStandardDeviation(_ a: [Double], _ b: [Double]) -> Double? {
        let n1 = a.count, n2 = b.count
        guard n1 + n2 > 2 else { return nil }
        let m1 = mean(a), m2 = mean(b)
        let ss1 = a.reduce(0) { $0 + ($1 - m1) * ($1 - m1) }
        let ss2 = b.reduce(0) { $0 + ($1 - m2) * ($1 - m2) }
        let pooledVariance = (ss1 + ss2) / Double(n1 + n2 - 2)
        return pooledVariance.squareRoot()
    }
}

// MARK: - Timeline (day X of Y)

/// Where an experiment sits in its own window: which day it is, out of how many (when it has an
/// end date), and how far along that makes it.
struct ExperimentTimeline: Equatable {
    let dayIndex: Int
    let totalDays: Int?
    let progress: Double

    /// True once today is on or past the last day of a fixed window. An open-ended experiment
    /// (no end date) is never "elapsed" on its own — completion has to come from its status.
    var hasElapsed: Bool {
        guard let totalDays else { return false }
        return dayIndex >= totalDays
    }
}

enum ExperimentTimelineCalculator {
    static func timeline(
        interventionStart: String,
        endDate: String?,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> ExperimentTimeline? {
        guard let start = parseISODate(interventionStart, calendar: calendar) else { return nil }
        let todayStart = calendar.startOfDay(for: today)
        let dayIndex = max((calendar.dateComponents([.day], from: start, to: todayStart).day ?? 0) + 1, 1)
        let end = endDate.flatMap { parseISODate($0, calendar: calendar) }
        let totalDays = end.map { (calendar.dateComponents([.day], from: start, to: $0).day ?? 0) + 1 }
        let progress = totalDays.map { min(Double(dayIndex) / Double(max($0, 1)), 1) } ?? 0
        return ExperimentTimeline(dayIndex: dayIndex, totalDays: totalDays, progress: progress)
    }

    static func parseISODate(_ value: String, calendar: Calendar = .current) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

// MARK: - Intervention days, from a goal's own check-ins

/// Reduces a goal's raw check-ins/observations to "was the intervention done on this day",
/// keyed by `yyyy-MM-dd`. Only boolean check-ins carry a clear yes/no; a goal tracked by number
/// has no such day.
enum ExperimentInterventionDays {
    static func build(
        checkins: [GoalCheckin],
        observations: [GoalObservation],
        measurementId: UUID
    ) -> [String: Bool] {
        let dateByCheckin = Dictionary(uniqueKeysWithValues: checkins.map { ($0.id, $0.localDate) })
        var result: [String: Bool] = [:]
        for observation in observations where observation.measurementId == measurementId {
            guard let date = dateByCheckin[observation.checkinId],
                  let value = observation.valueBoolean
            else { continue }
            result[date] = value
        }
        return result
    }
}

// MARK: - Starter experiments from the user's own data

/// A suggested experiment, derived from a real pattern in the user's own history — never a
/// generic template. `why` names the pattern and the numbers behind it.
struct ExperimentSuggestion: Identifiable, Equatable {
    let id: String
    let why: String
    let suggestedQuestion: String
    let outcome: ExperimentOutcomeTemplate
    let suggestedDurationDays: Int
}

enum ExperimentSuggestionEngine {
    /// Matches `LowAppetitePreparationEngine`'s bar for "this is a real pattern, not noise":
    /// at least two prior days logged for a given cycle day.
    static let minimumSampleCount = 2
    /// A cycle day counts as a dip only when it's noticeably below the rest of the cycle —
    /// 15% under the mean of days that qualify.
    static let dipFraction = 0.85
    static let defaultDurationDays = 21

    /// Up to three suggestions built from shot-cycle patterns in `insights`
    /// (`CycleAnalyticsEngine.build`'s output). Suggests nothing when the data doesn't clearly
    /// support it — no generic filler.
    static func suggestions(from insights: [CycleDayInsight]) -> [ExperimentSuggestion] {
        var results: [ExperimentSuggestion] = []
        if let protein = proteinDipSuggestion(insights) { results.append(protein) }
        if let energy = energyDipSuggestion(insights) { results.append(energy) }
        return Array(results.prefix(3))
    }

    private static func proteinDipSuggestion(_ insights: [CycleDayInsight]) -> ExperimentSuggestion? {
        guard let dip = dipRange(
            insights,
            value: \.averageProteinG,
            sampleCount: \.nutritionSampleCount
        ) else { return nil }
        let days = dayRangeText(dip.range)
        return ExperimentSuggestion(
            id: "protein-dip-\(dip.range.lowerBound)-\(dip.range.upperBound)",
            why: "Your protein dips on shot day\(dip.range.isSingle ? "" : "s") \(days) — averaging \(Int(dip.dipAverage.rounded()))g vs \(Int(dip.overallAverage.rounded()))g the rest of the cycle, across \(dip.sampleCount) logged days.",
            suggestedQuestion: "Does a pre-staged protein snack help on shot day\(dip.range.isSingle ? "" : "s") \(days)?",
            outcome: .protein,
            suggestedDurationDays: defaultDurationDays
        )
    }

    private static func energyDipSuggestion(_ insights: [CycleDayInsight]) -> ExperimentSuggestion? {
        guard let dip = dipRange(
            insights,
            value: \.averageEnergy,
            sampleCount: \.checkInSampleCount
        ) else { return nil }
        let days = dayRangeText(dip.range)
        let dipText = String(format: "%.1f", dip.dipAverage)
        let overallText = String(format: "%.1f", dip.overallAverage)
        return ExperimentSuggestion(
            id: "energy-dip-\(dip.range.lowerBound)-\(dip.range.upperBound)",
            why: "Your energy check-ins dip on shot day\(dip.range.isSingle ? "" : "s") \(days) — averaging \(dipText)/5 vs \(overallText)/5 the rest of the cycle, across \(dip.sampleCount) check-ins.",
            suggestedQuestion: "Does an easier plan on shot day\(dip.range.isSingle ? "" : "s") \(days) help energy?",
            outcome: .energy,
            suggestedDurationDays: defaultDurationDays
        )
    }

    private struct Dip {
        let range: ClosedRange<Int>
        let dipAverage: Double
        let overallAverage: Double
        let sampleCount: Int
    }

    /// Finds the longest run of consecutive cycle days whose average sits at or below
    /// `dipFraction` of the mean across all qualifying days. Days without enough samples are
    /// excluded before averaging, so one thin day can't manufacture a dip.
    private static func dipRange(
        _ insights: [CycleDayInsight],
        value: (CycleDayInsight) -> Double?,
        sampleCount: (CycleDayInsight) -> Int
    ) -> Dip? {
        let qualifying = insights.compactMap { insight -> (day: Int, value: Double, count: Int)? in
            guard let v = value(insight), sampleCount(insight) >= minimumSampleCount else { return nil }
            return (insight.cycleDay, v, sampleCount(insight))
        }
        guard qualifying.count >= 2 else { return nil }
        let overall = qualifying.reduce(0.0) { $0 + $1.value } / Double(qualifying.count)
        guard overall > 0 else { return nil }

        let dipping = qualifying.filter { $0.value <= overall * dipFraction }.sorted { $0.day < $1.day }
        guard !dipping.isEmpty else { return nil }

        var bestRun: [(day: Int, value: Double, count: Int)] = []
        var currentRun: [(day: Int, value: Double, count: Int)] = []
        for item in dipping {
            if let last = currentRun.last, item.day == last.day + 1 {
                currentRun.append(item)
            } else {
                currentRun = [item]
            }
            if currentRun.count > bestRun.count { bestRun = currentRun }
        }
        guard let first = bestRun.first?.day, let last = bestRun.last?.day else { return nil }

        return Dip(
            range: first...last,
            dipAverage: bestRun.reduce(0.0) { $0 + $1.value } / Double(bestRun.count),
            overallAverage: overall,
            sampleCount: bestRun.reduce(0) { $0 + $1.count }
        )
    }

    private static func dayRangeText(_ range: ClosedRange<Int>) -> String {
        range.isSingle ? "\(range.lowerBound)" : "\(range.lowerBound)–\(range.upperBound)"
    }
}

private extension ClosedRange where Bound == Int {
    var isSingle: Bool { lowerBound == upperBound }
}
