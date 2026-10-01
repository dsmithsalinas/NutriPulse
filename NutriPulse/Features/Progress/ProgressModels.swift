import Foundation

enum ProgressRange: Int, CaseIterable, Identifiable, Hashable {
    case week = 7
    case month = 30
    case quarter = 90

    var id: Int { rawValue }
    var label: String { "\(rawValue) days" }

    /// Short label for the Daylight pill switcher ("Week", "Month", "3 months").
    var pillLabel: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .quarter: "3 months"
        }
    }

    var analyticsRange: AnalyticsViewModel.TimeRange {
        switch self {
        case .week: .week
        case .month: .month
        case .quarter: .quarter
        }
    }

    /// The window immediately preceding this range's trailing window, same length — used to
    /// compare this period's floor days against the prior one (e.g. this week vs. last week).
    func previousWindow(now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date> {
        let end = calendar.startOfDay(for: now)
        let currentStart = calendar.date(byAdding: .day, value: -(rawValue - 1), to: end) ?? end
        let previousEnd = calendar.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
        let previousStart = calendar.date(byAdding: .day, value: -(rawValue - 1), to: previousEnd) ?? previousEnd
        return previousStart...previousEnd
    }

    var summaryPeriod: ProgressSummaryPeriod {
        switch self {
        case .week: .week
        case .month: .month
        case .quarter: .quarter
        }
    }

    func dateRangeText(now: Date = .now, calendar: Calendar = .current) -> String {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(rawValue - 1), to: end) ?? end
        return ProgressDateRangeFormatter.text(from: start, through: end)
    }
}

enum ProgressSummaryPeriod: String, CaseIterable, Identifiable, Hashable {
    case sinceLastShot
    case week
    case month
    case quarter

    var id: Self { self }

    var label: String {
        switch self {
        case .sinceLastShot: "Last shot"
        case .week: "7 days"
        case .month: "30 days"
        case .quarter: "90 days"
        }
    }

    var fullLabel: String {
        switch self {
        case .sinceLastShot: "Since last shot"
        case .week: "Last 7 days"
        case .month: "Last 30 days"
        case .quarter: "Last 90 days"
        }
    }

    var fixedDayCount: Int? {
        switch self {
        case .sinceLastShot: nil
        case .week: 7
        case .month: 30
        case .quarter: 90
        }
    }

    func window(
        shots: [GLP1Log],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ClosedRange<Date>? {
        let end = calendar.startOfDay(for: now)
        if let fixedDayCount {
            let start = calendar.date(byAdding: .day, value: -(fixedDayCount - 1), to: end) ?? end
            return start...end
        }
        guard let latest = shots.map(\.injectedAt).filter({ $0 <= now }).max() else { return nil }
        return calendar.startOfDay(for: latest)...end
    }
}

enum ProgressDateRangeFormatter {
    static func text(from start: Date, through end: Date) -> String {
        "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day().year()))"
    }
}

enum ProgressMarkState: Equatable {
    case met
    case below
    case logged
    case unknown
}

struct ProgressMetrics {
    let summaries: [DailySummary]
    let proteinGoal: Double?

    var logged: [DailySummary] { summaries.filter(\.hasData) }
    var hasGoal: Bool { (proteinGoal ?? 0) > 0 }
    var metCount: Int {
        guard let proteinGoal, proteinGoal > 0 else { return 0 }
        return logged.filter { $0.proteinG >= proteinGoal }.count
    }
    var missingCount: Int { max(summaries.count - logged.count, 0) }
    var completion: Double {
        guard !logged.isEmpty else { return 0 }
        if hasGoal { return Double(metCount) / Double(logged.count) }
        return Double(logged.count) / Double(max(summaries.count, 1))
    }
    var summaryReady: Bool { logged.count >= 3 }
    var averageProtein: Double {
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.proteinG } / Double(logged.count)
    }

    func state(for summary: DailySummary) -> ProgressMarkState {
        guard summary.hasData else { return .unknown }
        guard let proteinGoal, proteinGoal > 0 else { return .logged }
        return summary.proteinG >= proteinGoal ? .met : .below
    }
}

struct ProgressWeekInterval: Identifiable, Equatable {
    let index: Int
    let start: Date
    let end: Date
    let measuredDays: Int
    let metDays: Int
    let expectedDays: Int
    let hasGoal: Bool

    var id: Int { index }
    var hasEnoughData: Bool { measuredDays >= 3 }
    var fraction: Double {
        guard measuredDays > 0 else { return 0 }
        return hasGoal
            ? Double(metDays) / Double(measuredDays)
            : Double(measuredDays) / Double(max(expectedDays, 1))
    }

    var accessibilityText: String {
        let range = ProgressDateRangeFormatter.text(from: start, through: end)
        guard hasEnoughData else { return "\(range), not enough measured data" }
        if hasGoal { return "\(range), protein floor met on \(metDays) of \(measuredDays) measured days" }
        return "\(range), nutrition logged on \(measuredDays) of \(expectedDays) days"
    }
}

enum ProgressTimelineBuilder {
    static func thirteenWeeks(
        summaries: [DailySummary],
        proteinGoal: Double?
    ) -> [ProgressWeekInterval] {
        let ordered = summaries.sorted { $0.date < $1.date }
        guard !ordered.isEmpty else { return [] }

        let firstBucketCount = max(ordered.count - 84, 1)
        var buckets: [[DailySummary]] = [Array(ordered.prefix(firstBucketCount))]
        var cursor = firstBucketCount
        while cursor < ordered.count {
            let end = min(cursor + 7, ordered.count)
            buckets.append(Array(ordered[cursor..<end]))
            cursor = end
        }

        return buckets.suffix(13).enumerated().compactMap { index, bucket in
            guard let start = bucket.first?.date, let end = bucket.last?.date else { return nil }
            let metrics = ProgressMetrics(summaries: bucket, proteinGoal: proteinGoal)
            return ProgressWeekInterval(
                index: index,
                start: start,
                end: end,
                measuredDays: metrics.logged.count,
                metDays: metrics.metCount,
                expectedDays: bucket.count,
                hasGoal: metrics.hasGoal
            )
        }
    }
}

enum ProgressNoticeBuilder {
    static func text(insights: [CycleDayInsight]) -> String {
        let early = insights.filter { (2...3).contains($0.cycleDay) }
        let later = insights.filter { (4...6).contains($0.cycleDay) }

        func confidentAverage(
            _ values: [(value: Double?, samples: Int)],
            minimumDistinctDays: Int = 2
        ) -> Double? {
            let confident = values.compactMap { item -> Double? in
                guard item.samples >= 2 else { return nil }
                return item.value
            }
            guard confident.count >= minimumDistinctDays else { return nil }
            return confident.reduce(0, +) / Double(confident.count)
        }

        if let earlyWater = confidentAverage(early.map { ($0.averageWaterMl, $0.hydrationSampleCount) }),
           let laterWater = confidentAverage(later.map { ($0.averageWaterMl, $0.hydrationSampleCount) }),
           earlyWater < laterWater * 0.9 {
            return "Across at least two shot cycles, water was lower on days 2–3 than later in the cycle."
        }
        if let earlyProtein = confidentAverage(early.map { ($0.averageProteinG, $0.nutritionSampleCount) }),
           let laterProtein = confidentAverage(later.map { ($0.averageProteinG, $0.nutritionSampleCount) }),
           earlyProtein < laterProtein * 0.9 {
            return "Across at least two shot cycles, protein was lower on days 2–3 than later in the cycle."
        }

        let hasTwoCycles = insights.contains { $0.sampleCount >= 2 }
        if hasTwoCycles { return "Your shot-cycle pattern is becoming clearer as you log." }
        return "Log across at least two shot cycles and patterns will appear here."
    }
}

/// The floor-days hero tile's trend pill ("Up from 3") — this period's protein-floor days
/// against the immediately preceding period of the same length.
struct ProgressTrend: Equatable {
    enum Direction { case up, down, flat }

    let currentMet: Int
    let previousMet: Int

    var direction: Direction {
        if currentMet > previousMet { return .up }
        if currentMet < previousMet { return .down }
        return .flat
    }

    var label: String {
        switch direction {
        case .up: "Up from \(previousMet)"
        case .down: "Down from \(previousMet)"
        case .flat: "Same as last period"
        }
    }
}

enum ProgressTrendBuilder {
    /// Trailing mean over up to `window` values ending at each index; same length as `values`.
    static func rollingAverage(_ values: [Double], window: Int) -> [Double] {
        guard window > 1 else { return values }
        return values.indices.map { index in
            let slice = values[max(0, index - window + 1)...index]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    /// Only meaningful with a protein goal and at least one measured day in the prior period —
    /// otherwise there's nothing real to compare against, and the pill stays hidden.
    static func trend(current: ProgressMetrics, previous: ProgressMetrics) -> ProgressTrend? {
        guard current.hasGoal, previous.hasGoal, !previous.logged.isEmpty else { return nil }
        return ProgressTrend(currentMet: current.metCount, previousMet: previous.metCount)
    }
}

/// Y-axis bounds for the Progress sparklines. The weight sparkline (unlike the protein one,
/// which anchors its floor at 60% of the peak to tame noisy day-to-day swings — see
/// `Sparkline.defaultBounds` in ProgressView) scales to the data's own min...max: weight moves
/// slowly and a real week-over-week change is exactly what the tile is for. Android's
/// `ProgressTiles.sparklineBounds` uses the same 60%-of-peak anchor for its one shared
/// sparkline, which is the behavior being fixed here — padding plus a floor under the span is
/// closer to what a weight chart should do, so this intentionally diverges from Android.
enum SparklineScale {
    /// `minimumSpan` keeps a near-flat week (a few hundred grams of noise) from being stretched
    /// into a dramatic-looking cliff — e.g. ~1 kg, or the equivalent ~2 lb in display units.
    static func weightBounds(_ values: [Double], minimumSpan: Double) -> (min: Double, max: Double) {
        guard let dataMin = values.min(), let dataMax = values.max() else { return (0, 1) }
        guard dataMax > dataMin else {
            let half = max(minimumSpan, 0.0001) / 2
            return (dataMin - half, dataMax + half)
        }
        let span = dataMax - dataMin
        let padding = span * 0.15
        var lo = dataMin - padding
        var hi = dataMax + padding
        let paddedSpan = hi - lo
        if paddedSpan < minimumSpan {
            let extra = (minimumSpan - paddedSpan) / 2
            lo -= extra
            hi += extra
        }
        return (lo, hi)
    }
}

/// The "Try this" tile's suggestion — a single, data-derived nudge (never a canned line),
/// mirroring the logic `SummaryReviewCard`'s "one thing to try" already uses.
enum ProgressTryThisBuilder {
    static func text(_ metrics: ProgressMetrics) -> String {
        guard metrics.hasGoal, let goal = metrics.proteinGoal, goal > 0, !metrics.logged.isEmpty else {
            return "Log nutrition on a few more days and a suggestion will show up here."
        }
        if metrics.averageProtein < goal {
            let gap = Int((goal - metrics.averageProtein).rounded())
            return "You're averaging \(gap)g under your floor. Stage one protein-dense option the night before."
        }
        return "You're clearing your floor most days — keep repeating what's working."
    }
}

struct ProgressHistoryItem: Identifiable, Equatable {
    let id: String
    let title: String
    let dateRange: String
    let measuredDays: Int
    let expectedDays: Int
    let averageProtein: Int
}

enum ProgressHistoryBuilder {
    static func previousPeriods(
        for period: ProgressSummaryPeriod,
        summaries: [DailySummary],
        shots: [GLP1Log],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ProgressHistoryItem] {
        let ordered = summaries.sorted { $0.date < $1.date }
        guard !ordered.isEmpty else { return [] }

        let windows: [(String, ClosedRange<Date>)]
        if let days = period.fixedDayCount {
            let today = calendar.startOfDay(for: now)
            windows = (1...3).compactMap { offset in
                guard let end = calendar.date(byAdding: .day, value: -(days * offset), to: today),
                      let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else { return nil }
                return ("Previous \(period.label)", start...end)
            }
        } else {
            let eligibleShots = shots.map(\.injectedAt).filter { $0 <= now }.sorted()
            windows = zip(eligibleShots.dropLast(), eligibleShots.dropFirst()).reversed().prefix(3).map { startShot, nextShot in
                let start = calendar.startOfDay(for: startShot)
                let next = calendar.startOfDay(for: nextShot)
                let end = calendar.date(byAdding: .day, value: -1, to: next) ?? next
                return ("Completed shot cycle", start...end)
            }
        }

        return windows.compactMap { title, window in
            let periodSummaries = ordered.filter { window.contains(calendar.startOfDay(for: $0.date)) }
            let metrics = ProgressMetrics(summaries: periodSummaries, proteinGoal: nil)
            guard metrics.summaryReady else { return nil }
            return ProgressHistoryItem(
                id: "\(window.lowerBound.isoDateString)-\(window.upperBound.isoDateString)",
                title: title,
                dateRange: ProgressDateRangeFormatter.text(from: window.lowerBound, through: window.upperBound),
                measuredDays: metrics.logged.count,
                expectedDays: periodSummaries.count,
                averageProtein: Int(metrics.averageProtein.rounded())
            )
        }
    }
}
