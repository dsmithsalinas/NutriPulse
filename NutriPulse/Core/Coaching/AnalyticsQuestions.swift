import Foundation

// Pure logic behind the Analytics "questions" screen. Kept free of SwiftUI, Supabase and
// LocalStore so every rule here is trivially unit-testable — see FootingTests.swift. Each type
// answers exactly one question honestly: a takeaway that's computed from what's actually logged,
// never invented, and that says so plainly when there isn't enough data yet.

// MARK: - Where does my protein come from?

/// One food's contribution to protein logged in a range.
struct ProteinSource: Identifiable, Equatable {
    /// Display name as first logged — merging is case-insensitive/trimmed, but the label keeps
    /// whatever casing the user actually typed or picked.
    let name: String
    let gramsProtein: Double
    /// This food's share of ALL protein logged in the range (0...1), not just the top 5 shown.
    let share: Double
    let timesLogged: Int

    var id: String { name }
}

enum ProteinSourceAggregator {
    /// Merges food logs into per-food protein totals — case-insensitively and trimmed, so
    /// "Greek Yogurt" and "greek yogurt " count as the same food — then returns the top
    /// `limit` foods by total protein contributed, each carrying its share of the range total.
    static func topSources(from logs: [FoodLog], limit: Int = 5) -> [ProteinSource] {
        struct Aggregate {
            var displayName: String
            var gramsProtein: Double = 0
            var timesLogged: Int = 0
        }

        var byKey: [String: Aggregate] = [:]
        var order: [String] = []
        for log in logs {
            let trimmed = log.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if byKey[key] == nil {
                byKey[key] = Aggregate(displayName: trimmed)
                order.append(key)
            }
            byKey[key]?.gramsProtein += log.totalProteinG
            byKey[key]?.timesLogged += 1
        }

        let totalProtein = byKey.values.reduce(0) { $0 + $1.gramsProtein }
        guard totalProtein > 0 else { return [] }

        return order
            .compactMap { byKey[$0] }
            .sorted { $0.gramsProtein > $1.gramsProtein }
            .prefix(limit)
            .map {
                ProteinSource(
                    name: $0.displayName,
                    gramsProtein: $0.gramsProtein,
                    share: $0.gramsProtein / totalProtein,
                    timesLogged: $0.timesLogged
                )
            }
    }

    /// "Greek yogurt and turkey chili gave you 38% of your protein." — names the top one or two
    /// sources and their combined share. Never claims more than the top two contributed.
    static func headline(for sources: [ProteinSource]) -> String? {
        guard let first = sources.first else { return nil }
        let top = Array(sources.prefix(2))
        let combinedShare = top.reduce(0) { $0 + $1.share }
        let pct = Int((combinedShare * 100).rounded())
        let names: String
        if top.count == 1 {
            names = first.name
        } else {
            names = "\(top[0].name) and \(top[1].name)"
        }
        return "\(names) gave you \(pct)% of your protein."
    }
}

// MARK: - Is my weight trend real?

/// One point of a smoothed weight line — the app's own computed value, not a raw weigh-in.
struct WeightTrendPoint: Equatable {
    let date: Date
    let value: Double
}

/// A dose change worth marking on a chart: the date it took effect, the new dose, and which
/// medication it belongs to (someone can be mid-switch between two).
struct DoseChangeMark: Identifiable, Equatable {
    let date: Date
    let doseMg: Double
    let medication: String
    var id: Date { date }
}

enum GLP1DoseChangeDetector {
    /// Every log where the dose differs from that medication's previous logged dose — tracked
    /// per medication so a switch from one drug to another isn't read as a dose change on a
    /// shared scale. The first log of a medication is a start, not a change.
    static func changes(in logs: [GLP1Log]) -> [DoseChangeMark] {
        let sorted = logs.sorted { $0.injectedAt < $1.injectedAt }
        var lastDose: [String: Double] = [:]
        var marks: [DoseChangeMark] = []
        for log in sorted {
            if let previous = lastDose[log.medication], previous != log.doseMg {
                marks.append(DoseChangeMark(date: log.injectedAt, doseMg: log.doseMg, medication: log.medication))
            }
            lastDose[log.medication] = log.doseMg
        }
        return marks
    }
}

/// Keeps a weight chart's shot-day ticks and dose-change rules from stretching past the
/// selected range. `doseChanges`/`shotDays` are derived from the user's whole GLP-1 history (a
/// dose change needs that context to tell a start from a change), but Swift Charts infers its
/// x-axis from every mark plotted — so an old dose change outside the chosen week/month/quarter
/// would still widen the axis and squeeze the actual weight data into a sliver. Matches
/// Android's `ChartScale.inWindow` filtering in AnalyticsScreen's weight-trend question.
enum ChartRangeFilter {
    static func withinRange<T>(
        _ items: [T],
        days: Int,
        date: (T) -> Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [T] {
        let end = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else { return items }
        return items.filter {
            let day = calendar.startOfDay(for: date($0))
            return day >= start && day <= end
        }
    }
}

enum WeightTrendEngine {
    /// Below this many weigh-ins, a change is real data but not a "trend" — see `takeaway`.
    static let minimumForTrend = 4

    /// Trailing rolling average: each point is the mean of itself and the `window - 1` points
    /// before it. Smooths day-to-day noise (water weight, timing) without inventing data past
    /// the last real weigh-in the way a fitted projection would.
    static func rollingAverage(_ values: [Double], window: Int) -> [Double] {
        guard window > 1, !values.isEmpty else { return values }
        return values.indices.map { index in
            let slice = values[max(0, index - window + 1)...index]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    static func smoothedSeries(from logs: [WeightLog], window: Int = 3) -> [WeightTrendPoint] {
        let sorted = logs.sorted { $0.loggedAt < $1.loggedAt }
        let smoothed = rollingAverage(sorted.map(\.weightKg), window: window)
        return zip(sorted, smoothed).map { WeightTrendPoint(date: $0.loggedAt, value: $1) }
    }

    /// The honest, plain-English line: the actual change and how many weigh-ins it's based on,
    /// and — below `minimumForTrend` — an explicit admission that it's too little data to call a
    /// trend. Never a projection, never a claim the data doesn't support.
    static func takeaway(for logs: [WeightLog], units: UnitSystem) -> String {
        guard !logs.isEmpty else { return "No weigh-ins logged in this range yet." }
        guard logs.count >= 2 else { return "Only one weigh-in logged — not enough to show a change." }

        let sorted = logs.sorted { $0.loggedAt < $1.loggedAt }
        let change = sorted.last!.weightKg - sorted.first!.weightKg
        let base: String
        if abs(change) < 0.05 {
            base = "Weight has held steady across \(logs.count) weigh-ins."
        } else {
            let direction = change < 0 ? "down" : "up"
            let magnitude = units.formatWeight(abs(change))
            base = "Weight is \(direction) \(magnitude) across \(logs.count) weigh-ins."
        }

        guard logs.count >= minimumForTrend else {
            return base + " That's too few weigh-ins to call a trend."
        }
        return base
    }
}

// MARK: - How do shot days change my eating?

enum ShotDayEatingTakeaway {
    /// A single honest line about the cycle-day pattern, independent of whichever metric the
    /// chart's own picker currently shows: the day protein has tended to be highest, and how
    /// many logged days that's built on. Falls back to an invitation rather than a guess when
    /// there isn't a pattern to name yet.
    static func build(insights: [CycleDayInsight]) -> String {
        guard !insights.isEmpty else {
            return "Log a few days around your shots to see a pattern here."
        }
        let totalDays = insights.reduce(0) { $0 + $1.nutritionSampleCount }
        guard let strongest = insights
            .compactMap({ day -> (day: Int, protein: Double)? in
                guard let protein = day.averageProteinG else { return nil }
                return (day.cycleDay, protein)
            })
            .max(by: { $0.protein < $1.protein })
        else {
            return "Based on \(totalDays) logged day\(totalDays == 1 ? "" : "s") across your dose cycle."
        }
        return "Protein has tended to be highest around day \(strongest.day) of your dose cycle, from \(totalDays) logged day\(totalDays == 1 ? "" : "s")."
    }
}

// MARK: - Am I hitting protein and calories?

enum NutritionSummaryTakeaway {
    static func build(loggedDayCount: Int, avgProtein: Double, goalProtein: Double?, avgCalories: Double, goalCalories: Double?) -> String {
        guard loggedDayCount > 0 else { return "No days logged in this range yet." }
        var parts: [String] = []
        if let goalProtein, goalProtein > 0 {
            let pct = Int((avgProtein / goalProtein * 100).rounded())
            parts.append("\(pct)% of your \(Int(goalProtein.rounded()))g protein goal")
        } else {
            parts.append("\(Int(avgProtein.rounded()))g of protein a day")
        }
        if let goalCalories, goalCalories > 0 {
            parts.append("\(Int(avgCalories.rounded())) of \(Int(goalCalories.rounded())) kcal")
        } else {
            parts.append("\(Int(avgCalories.rounded())) kcal a day")
        }
        let day = loggedDayCount == 1 ? "day" : "days"
        return "Averaging, over \(loggedDayCount) logged \(day): " + parts.joined(separator: ", ") + "."
    }
}

// MARK: - Am I moving more?

enum MovementTakeaway {
    static func build(activeDayCount: Int, totalDayCount: Int, sessions: Int, avgMinutes: Double) -> String {
        guard activeDayCount > 0 else { return "No movement logged in this range yet." }
        let session = sessions == 1 ? "session" : "sessions"
        return "You moved on \(activeDayCount) of \(totalDayCount) days — \(sessions) \(session), averaging \(Int(avgMinutes.rounded())) min on active days."
    }
}

// MARK: - How's my body composition?

enum BodyFatTrendTakeaway {
    static func build(logs: [(date: Date, pct: Double)]) -> String {
        guard logs.count >= 2 else {
            return logs.isEmpty ? "No body fat readings in this range yet." : "One reading logged — too early to see a trend."
        }
        let sorted = logs.sorted { $0.date < $1.date }
        let change = sorted.last!.pct - sorted.first!.pct
        if abs(change) < 0.05 {
            return "Body fat has held steady across \(logs.count) readings."
        }
        let direction = change < 0 ? "down" : "up"
        return "Body fat is \(direction) \(String(format: "%.1f", abs(change)))% across \(logs.count) readings."
    }
}
