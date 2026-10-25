import Foundation

/// Health observations are evidence, never proof of an intention or of a missed day.
struct ExperimentHealthLink: Codable, Equatable {
    enum Metric: String, Codable, CaseIterable { case walking, sleep }
    var metric: Metric
    var startHour = 12
    var endHour = 16
    var label: String { metric == .walking ? "Recorded walking" : "Following night's sleep" }
}

struct ExperimentHealthDay: Identifiable, Equatable {
    let day: String
    let value: Double
    var id: String { day }
}

enum ExperimentHealthEvidence {
    static func walkingMinutes(_ workouts: [HealthKitManager.HKWorkoutSummary], on date: Date,
                               link: ExperimentHealthLink, now: Date = .now, calendar: Calendar = .current) -> Double? {
        guard link.startHour >= 0, link.endHour <= 24, link.startHour < link.endHour else { return nil }
        let start = calendar.date(bySettingHour: link.startHour, minute: 0, second: 0, of: date)!
        let localEnd = link.endHour == 24
            ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
            : calendar.date(bySettingHour: link.endHour, minute: 0, second: 0, of: date)!
        let end = min(localEnd, now)
        let intervals = workouts.filter { $0.activitySlug == "walking" && $0.durationMinutes.isFinite && $0.durationMinutes > 0 }
            .compactMap { workout -> (start: Date, end: Date)? in
                let a = max(start, workout.startDate)
                let b = min(end, workout.startDate.addingTimeInterval(workout.durationMinutes * 60))
                return b > a ? (a, b) : nil
            }
        let minutes = HealthKitManager.mergedDuration(of: intervals) / 60
        return minutes > 0 ? minutes : nil
    }

    static func comparison(experiment: TinyExperiment, days: [ExperimentHealthDay]) -> String? {
        guard let link = experiment.healthLink else { return nil }
        // Only explicit tried/not-tried entries form the groups. Health never labels a day.
        let observations = Dictionary(experiment.observations.map { ($0.day, $0) }, uniquingKeysWith: { _, b in b })
        let pairs = days.filter { $0.day >= experiment.startedOn && $0.value.isFinite && $0.value > 0 && observations[$0.day] != nil }
        let tried = pairs.filter { observations[$0.day]?.tried == true }.map(\.value)
        let other = pairs.filter { observations[$0.day]?.tried == false }.map(\.value)
        guard tried.count >= 3, other.count >= 3 else { return nil }
        let unit = link.metric == .sleep ? "h" : "min"
        return String(format: "Recorded %@ averaged %.1f %@ on %d confirmed tried days and %.1f %@ on %d confirmed not-tried days. This is a description, not evidence that the experiment caused the difference.",
                      link.metric == .sleep ? "sleep" : "walking", average(tried), unit, tried.count, average(other), unit, other.count)
    }
    static func groupMetrics(experiment: TinyExperiment, days: [ExperimentHealthDay]) -> [HealthPatternMetric] {
        guard let link = experiment.healthLink else { return [] }
        let observations = Dictionary(experiment.observations.map { ($0.day, $0) }, uniquingKeysWith: { _, b in b })
        let pairs = days.filter { $0.day >= experiment.startedOn && $0.value.isFinite && $0.value > 0 && observations[$0.day] != nil }
        let a = pairs.filter { observations[$0.day]?.tried == true }.map(\.value)
        let b = pairs.filter { observations[$0.day]?.tried == false }.map(\.value)
        guard a.count >= 3, b.count >= 3 else { return [] }
        let unit = link.metric == .sleep ? "hours" : "min"
        return [.init(id: "tried", title: "Tried the change", value: String(format: "%.1f", average(a)), unit: unit, caption: "\(a.count) confirmed days"),
                .init(id: "other", title: "Didn’t try", value: String(format: "%.1f", average(b)), unit: unit, caption: "\(b.count) confirmed days")]
    }
    private static func average(_ values: [Double]) -> Double { values.reduce(0, +) / Double(values.count) }
}

struct HealthExperienceDay: Identifiable {
    let day: String
    let sleep: Double?
    let steps: Double?
    let workouts: [HealthKitManager.HKWorkoutSummary]
    var id: String { day }
}

@MainActor
enum HealthExperienceReader {
    static func sleepHours(_ date: Date) async -> Double? {
        let hk = HealthKitManager.shared
        async let hours = hk.fetchSleepHours(for: date)
        async let rows = hk.fetchQualityObservations(metric: .sleepDuration, dates: [date])
        let (value, observations) = await (hours, rows)
        let quality = HealthDataQualityEngine.assess(metric: .sleepDuration, observations: observations, expectedDates: [date])
        guard !observations.isEmpty, !quality.usableObservations.isEmpty,
              !quality.issues.contains(where: { $0.code == .conflictingSources || $0.code == .implausibleValue }),
              let value, value.isFinite, (0.5...16).contains(value) else { return nil }
        return value
    }
    static func day(_ date: Date) async -> HealthExperienceDay {
        let hk = HealthKitManager.shared
        async let sleep = sleepHours(date)
        async let steps = hk.fetchSteps(for: date)
        async let workouts = hk.fetchWorkouts(for: date)
        let values = await (sleep, steps, workouts)
        return HealthExperienceDay(day: date.isoDateString,
            sleep: values.0.flatMap { $0.isFinite && $0 > 0 && $0 <= 16 ? $0 : nil },
            steps: values.1.flatMap { $0.isFinite && $0 >= 0 && $0 <= 100_000 ? $0 : nil },
            workouts: values.2)
    }

    static func experiment(_ experiment: TinyExperiment, now: Date = .now) async -> [ExperimentHealthDay] {
        guard let link = experiment.healthLink, let start = Date.fromISODateString(experiment.startedOn) else { return [] }
        var result: [ExperimentHealthDay] = []
        for offset in 0..<14 {
            guard !Task.isCancelled, let date = Calendar.current.date(byAdding: .day, value: -offset, to: now),
                  Calendar.current.startOfDay(for: date) >= start,
                  experiment.completedOn.map({ date.isoDateString <= $0 }) ?? true else { continue }
            if link.metric == .walking {
                let workouts = await HealthKitManager.shared.fetchWorkouts(for: date)
                if let value = ExperimentHealthEvidence.walkingMinutes(workouts, on: date, link: link, now: now) {
                    result.append(.init(day: date.isoDateString, value: value))
                }
            } else if offset > 0, let morning = Calendar.current.date(byAdding: .day, value: 1, to: date) {
                // Wait until the normal sleep-query window has ended before comparing it.
                if Calendar.current.isDate(morning, inSameDayAs: now), Calendar.current.component(.hour, from: now) < 10 { continue }
                let hours = await sleepHours(morning)
                if let hours, hours.isFinite, hours > 0, hours <= 16 {
                    result.append(.init(day: date.isoDateString, value: hours))
                }
            }
        }
        return result
    }
}
