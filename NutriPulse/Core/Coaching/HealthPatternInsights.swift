import Foundation

struct HealthPatternMetric: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let unit: String
    let caption: String
}

struct HealthPatternLine: Identifiable, Equatable {
    let id: String
    let text: String
    var metrics: [HealthPatternMetric] = []
}

enum HealthPatternInsights {
    /// Last seven complete days, with coverage shown instead of treating missing data as rest.
    static func week(days: [HealthExperienceDay], checkIns: [ShotCycleCheckIn], now: Date = .now,
                     calendar: Calendar = .current) -> [HealthPatternLine] {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -7, to: today)!.isoDateString
        let recent = days.filter { $0.day >= start && $0.day < today.isoDateString }
        var result: [HealthPatternLine] = []
        let strength = recent.flatMap(\.workouts).filter { ["strength", "traditionalStrengthTraining", "functionalStrengthTraining"].contains($0.activitySlug) }
        if !strength.isEmpty { result.append(.init(id: "strength", text: "\(strength.count) recorded strength sessions in the last seven complete days.", metrics: [.init(id: "strength", title: "Strength", value: String(strength.count), unit: "sessions", caption: "Recorded this week")])) }
        let walking = recent.filter { $0.workouts.contains { $0.activitySlug == "walking" } }
        if !walking.isEmpty { result.append(.init(id: "walking", text: "Walking workouts recorded on \(walking.count) of seven days. Other days are unknown.", metrics: [.init(id: "walking", title: "Walking", value: String(walking.count), unit: "days", caption: "Workouts recorded")])) }
        let steps = recent.compactMap(\.steps)
        if steps.count >= 3 { result.append(.init(id: "steps", text: "\(Int(mean(steps)).formatted()) steps per observed day · \(steps.count)/7 days available.", metrics: [.init(id: "steps", title: "Steps", value: Int(mean(steps)).formatted(), unit: "/ day", caption: "\(steps.count)/7 days observed")])) }
        let sleep = recent.compactMap(\.sleep)
        if sleep.count >= 3 { result.append(.init(id: "sleep", text: String(format: "%.1f hours of recorded sleep per observed night · %d/7 nights available.", mean(sleep), sleep.count), metrics: [.init(id: "sleep", title: "Sleep", value: String(format: "%.1f", mean(sleep)), unit: "hours", caption: "\(sleep.count)/7 nights observed")])) }
        let energy = checkIns.filter { $0.checkinDate >= start && $0.checkinDate < today.isoDateString && (1...5).contains($0.energy) }.map { Double($0.energy) }
        if energy.count >= 3 { result.append(.init(id: "energy", text: String(format: "You reported energy averaging %.1f/5 across %d check-in days.", mean(energy), energy.count), metrics: [.init(id: "energy", title: "Energy", value: String(format: "%.1f", mean(energy)), unit: "/ 5", caption: "\(energy.count) check-in days")])) }
        return result
    }

    /// Compare the same cycle day from three distinct completed cycles on the same regimen.
    /// Neither the current cycle nor skipped/interrupted intervals establish a pattern.
    static func cycle(cycleDay: Int, injections: [GLP1Log], skips: [GLP1SkippedDose],
                      checkIns: [ShotCycleCheckIn], days: [HealthExperienceDay], owner: UUID,
                      now: Date = .now, calendar: Calendar = .current) -> [HealthPatternLine] {
        let logs = injections.filter { $0.userId == owner && $0.injectedAt <= now }.sorted { $0.injectedAt < $1.injectedAt }
        guard let current = logs.last, cycleDay >= 0, cycleDay < current.cycleLengthDays else { return [] }
        var selected: [ShotCycleCheckIn] = []
        for index in logs.indices.dropLast() {
            let shot = logs[index], next = logs[index + 1]
            guard shot.medication == current.medication, shot.doseMg == current.doseMg,
                  next.medication == shot.medication, next.doseMg == shot.doseMg,
                  !skips.contains(where: { $0.userId == owner && $0.injectionId == shot.id }),
                  let date = calendar.date(byAdding: .day, value: cycleDay, to: calendar.startOfDay(for: shot.injectedAt)),
                  date < calendar.startOfDay(for: next.injectedAt) else { continue }
            let length = calendar.dateComponents([.day], from: calendar.startOfDay(for: shot.injectedAt), to: calendar.startOfDay(for: next.injectedAt)).day ?? 0
            guard length == shot.cycleLengthDays,
                  let checkIn = checkIns.first(where: { $0.userId == owner && $0.checkinDate == date.isoDateString && $0.cycleDay == cycleDay }),
                  (1...5).contains(checkIn.appetite), (1...5).contains(checkIn.energy) else { continue }
            selected.append(checkIn)
        }
        selected = Array(selected.suffix(6))
        guard selected.count >= 3 else { return [] }
        var lines: [HealthPatternLine] = [.init(id: "experience", text: String(format: "On day %d across %d earlier cycles at this medication and dose, you reported appetite averaging %.1f/5 and energy %.1f/5.", cycleDay, selected.count, mean(selected.map { Double($0.appetite) }), mean(selected.map { Double($0.energy) })), metrics: [
            .init(id: "appetite", title: "Appetite", value: String(format: "%.1f", mean(selected.map { Double($0.appetite) })), unit: "/ 5", caption: "\(selected.count) earlier cycles"),
            .init(id: "energy", title: "Energy", value: String(format: "%.1f", mean(selected.map { Double($0.energy) })), unit: "/ 5", caption: "Your check-ins")])]
        let dates = Set(selected.map(\.checkinDate))
        let observed = days.filter { dates.contains($0.day) }
        let sleep = observed.compactMap(\.sleep)
        if sleep.count >= 3 { lines.append(.init(id: "cycleSleep", text: String(format: "Those check-in days had %.1f hours of preceding-night sleep on average · %d matched nights available.", mean(sleep), sleep.count), metrics: [.init(id: "cycleSleep", title: "Sleep", value: String(format: "%.1f", mean(sleep)), unit: "hours", caption: "\(sleep.count) matched nights")])) }
        let steps = observed.compactMap(\.steps)
        if steps.count >= 3 { lines.append(.init(id: "cycleSteps", text: "\(Int(mean(steps)).formatted()) recorded steps per observed day · \(steps.count) matched days available.", metrics: [.init(id: "cycleSteps", title: "Steps", value: Int(mean(steps)).formatted(), unit: "/ day", caption: "\(steps.count) matched days")])) }
        return lines
    }

    static func shorterSleep(hours: Double?, baseline: Double?) -> Bool {
        guard let hours, let baseline, hours.isFinite, baseline.isFinite, (0.5...16).contains(hours), (0.5...16).contains(baseline) else { return false }
        return baseline - hours >= 1
    }
    private static func mean(_ values: [Double]) -> Double { values.reduce(0, +) / Double(values.count) }
}
