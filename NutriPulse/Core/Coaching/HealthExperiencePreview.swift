#if DEBUG
import Foundation

/// Fictional, in-memory fixtures. No Health reads, auth, network, or persistence.
@MainActor
enum HealthExperiencePreview {
    static func experiment() -> TinyExperiment {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        var experiment = TinyExperiment(action: "A screen-free wind-down", outcome: "Following-night sleep", startedOn: start.isoDateString, healthOutcome: true, healthLink: .init(metric: .sleep))
        experiment.observations = (1...6).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now)!
            return .init(day: date.isoDateString, tried: offset % 2 == 0, rating: nil)
        }
        return experiment
    }
    static func experimentDays() -> [ExperimentHealthDay] {
        (1...6).map { offset in
            .init(day: Calendar.current.date(byAdding: .day, value: -offset, to: .now)!.isoDateString, value: offset % 2 == 0 ? 7.4 : 6.8)
        }
    }
    static var weekly: [HealthPatternLine] { [
        .init(id: "strength", text: "2 recorded strength sessions in the last seven complete days.", metrics: [.init(id: "strength", title: "Strength", value: "2", unit: "sessions", caption: "Recorded this week")]),
        .init(id: "walking", text: "Walking workouts recorded on 3 of seven days. Other days are unknown.", metrics: [.init(id: "walking", title: "Walking", value: "3", unit: "days", caption: "Workouts recorded")]),
        .init(id: "sleep", text: "7.1 hours of recorded sleep per observed night · 5/7 nights available.", metrics: [.init(id: "sleep", title: "Sleep", value: "7.1", unit: "hours", caption: "5/7 nights observed")]),
        .init(id: "energy", text: "You reported energy averaging 3.5/5 across 4 check-in days.", metrics: [.init(id: "energy", title: "Energy", value: "3.5", unit: "/ 5", caption: "4 check-in days")])
    ] }
    static var cycle: [HealthPatternLine] { [
        .init(id: "experience", text: "On day 1 across 3 earlier cycles at this medication and dose, you reported appetite averaging 2.3/5 and energy 2.7/5.", metrics: [.init(id: "appetite", title: "Appetite", value: "2.3", unit: "/ 5", caption: "3 earlier cycles"), .init(id: "energy", title: "Energy", value: "2.7", unit: "/ 5", caption: "Your check-ins")]),
        .init(id: "cycleSleep", text: "Those check-in days had 6.8 hours of preceding-night sleep on average · 3 matched nights available.", metrics: [.init(id: "cycleSleep", title: "Sleep", value: "6.8", unit: "hours", caption: "3 matched nights")])
    ] }
}
#endif
