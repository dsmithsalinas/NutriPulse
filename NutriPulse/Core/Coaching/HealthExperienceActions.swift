import Foundation

enum CycleFitChoice: String, Codable, CaseIterable, Identifiable {
    case familiar, different, notUseful
    var id: String { rawValue }
    var title: String {
        switch self { case .familiar: "Sounds familiar"; case .different: "Today feels different"; case .notUseful: "Not useful" }
    }
}
struct CycleFitFeedback: Codable, Equatable {
    let day: String
    let cycleDay: Int
    let choice: CycleFitChoice
}

extension EverydayToolData {
    func cycleFit(on day: String, cycleDay: Int) -> CycleFitChoice? {
        cycleFeedback?.last { $0.day == day && $0.cycleDay == cycleDay }?.choice
    }
    mutating func setCycleFit(_ choice: CycleFitChoice?, day: String, cycleDay: Int) {
        var entries = cycleFeedback ?? []
        entries.removeAll { $0.day == day }
        if let choice { entries.append(.init(day: day, cycleDay: cycleDay, choice: choice)) }
        cycleFeedback = Array(entries.sorted { $0.day < $1.day }.suffix(14))
    }
}

struct EasierDayRecipeDraft: Equatable {
    var situation = "When I want an easier day"
    var food = ""
    var water = ""
    var support = ""
    var draftText: String? {
        let when = situation.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [("Food", food), ("Water", water), ("Support", support)].compactMap { label, value -> String? in
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : "\(label): \(text)"
        }
        guard !when.isEmpty, !parts.isEmpty else { return nil }
        let text = "\(when). What helps me: " + parts.joined(separator: "; ") + "."
        return text
    }
    var memory: String? { draftText.flatMap { $0.unicodeScalars.count <= 300 ? $0 : nil } }
}

enum ExperimentNextStep: String, Codable, CaseIterable, Identifiable {
    case keepTrying, makeEasier, finish
    var id: String { rawValue }
    var title: String { switch self { case .keepTrying: "Keep trying"; case .makeEasier: "Make it easier"; case .finish: "Finish here" } }
}
struct ExperimentReflection: Codable, Equatable {
    let reviewedOn: String
    let nextStep: ExperimentNextStep
    let note: String
}
extension TinyExperiment {
    var readyToReflect: Bool {
        guard completedOn == nil else { return false }
        return Set(observations.filter { $0.day > (reflection?.reviewedOn ?? "") }.map(\.day)).count >= 6
    }
}
enum ExperimentWrapUp {
    enum Failure: Error { case invalid, capacity }
    static func applying(id: UUID, choice: ExperimentNextStep, note: String, revisedAction: String,
                         day: String, to data: EverydayToolData) throws -> EverydayToolData {
        guard let index = data.experiments.firstIndex(where: { $0.id == id }), data.experiments[index].completedOn == nil,
              Date.fromISODateString(day) != nil else { throw Failure.invalid }
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard note.unicodeScalars.count <= 240 else { throw Failure.invalid }
        var next = data
        if choice == .makeEasier {
            let action = revisedAction.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !action.isEmpty, action.unicodeScalars.count <= 150, action != data.experiments[index].action else { throw Failure.invalid }
            guard data.experiments.count < 20 else { throw Failure.capacity }
            let old = data.experiments[index]
            next.experiments.append(TinyExperiment(action: action, outcome: old.outcome, startedOn: day,
                parentExperimentId: old.id, healthOutcome: old.healthOutcome, healthLink: old.healthLink))
        }
        next.experiments[index].reflection = .init(reviewedOn: day, nextStep: choice, note: note)
        if choice != .keepTrying { next.experiments[index].completedOn = day }
        else { next.experiments[index].paused = false }
        return next
    }
}
