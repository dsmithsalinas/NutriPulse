import Foundation
import Observation

struct TinyObservation: Codable, Equatable {
    let day: String
    var tried: Bool
    var rating: Int
}

struct TinyExperiment: Codable, Identifiable, Equatable {
    var id = UUID()
    var action: String
    var outcome: String
    var startedOn: String
    var paused = false
    var completedOn: String?
    var observations: [TinyObservation] = []

    var summary: String {
        let tried = observations.filter { $0.tried }
        let other = observations.filter { !$0.tried }
        guard tried.count >= 3, other.count >= 3 else {
            return "Tried: \(tried.count) · Didn’t try: \(other.count). Not enough observations to compare yet. Blank days stay unknown."
        }
        let a = Double(tried.reduce(0) { $0 + $1.rating }) / Double(tried.count)
        let b = Double(other.reduce(0) { $0 + $1.rating }) / Double(other.count)
        return String(format: "Your %@ rating averaged %.1f/5 on %d tried days and %.1f/5 on %d explicitly not-tried days. This describes your observations; it does not show cause. Sleep, stress and other circumstances may differ.", outcome, a, tried.count, b, other.count)
    }
}

struct SavedLeftover: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var savedOn: String
    var meal: Meal
    var finishedOn: String?
    var initialNoteSaved: Bool?
    var finishRequestedOn: String?
    // A stable note ID makes a retried finish replace the same note, never duplicate it.
    var finishNoteId = UUID()
    var finishBody: String { "Finished the rest of \(name), saved on \(savedOn). Portions and nutrition are unknown." }
}

enum OneDecision: String, Codable, CaseIterable, Identifiable {
    case food = "Something to eat", movement = "Some movement", groceries = "One grocery addition"
    var id: String { rawValue }
    func prompt(constraints: String, alternative: Bool = false) -> String? {
        guard let text = MealNote.validBody(constraints) else { return nil }
        return """
        Help me delegate one decision: \(rawValue).
        My constraints: \(text)
        \(alternative ? "Offer a different option from your previous suggestion." : "Offer one concrete, manageable option.")
        Keep the answer short, optional and low-pressure. No list of choices, detailed exercise prescription, medication advice or catch-up work. Respect my reported limitations; do not infer medical clearance. If safety-critical information is missing, ask one useful question instead. Do not claim anything was logged, completed, remembered or changed. I will decide whether to do it.
        """
    }
}

struct EverydayToolData: Codable, Equatable {
    var experiments: [TinyExperiment] = []
    var leftovers: [SavedLeftover] = []
    var constraints: [String: String] = [:]
}

/// Device-only drafts and observations. Separate protected files per account; none of this
/// becomes model context or an approved memory without an explicit user action.
@Observable @MainActor
final class EverydayToolsStore {
    static let shared = EverydayToolsStore()
    private(set) var accountId: UUID?
    private(set) var generation = UUID()
    private(set) var data = EverydayToolData()
    private(set) var error: String?
    private let directory: URL
    init(directory: URL = URL.applicationSupportDirectory.appending(path: "EverydayTools", directoryHint: .isDirectory)) {
        self.directory = directory
    }
    private func url(_ owner: UUID) -> URL { directory.appending(path: owner.uuidString + ".json") }
    func setAccount(_ owner: UUID?) {
        guard owner != accountId else { return }
        generation = UUID(); accountId = owner; data = .init(); error = nil
        guard let owner, FileManager.default.fileExists(atPath: url(owner).path) else { return }
        do { data = try JSONDecoder().decode(EverydayToolData.self, from: Data(contentsOf: url(owner))) }
        catch { self.error = "Couldn’t open your saved tools. Nothing has been replaced. Try again after unlocking your phone." }
    }
    func update(owner: UUID, generation expected: UUID, _ change: (inout EverydayToolData) -> Void) throws {
        guard owner == accountId, expected == generation else { throw URLError(.userAuthenticationRequired) }
        guard error == nil else { throw URLError(.cannotOpenFile) }
        var next = data; change(&next)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var protectedDirectory = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try protectedDirectory.setResourceValues(values)
        try JSONEncoder().encode(next).write(to: url(owner), options: [.atomic, .completeFileProtection])
        data = next
    }
    func saveInitialLeftoverNote(id: UUID, owner: UUID, generation expected: UUID,
                                 saveNote: (MealNote) async throws -> Void) async throws {
        guard owner == accountId, expected == generation,
              let item = data.leftovers.first(where: { $0.id == id }) else { throw URLError(.userAuthenticationRequired) }
        let note = MealNote(id: item.id, userId: owner, logDate: item.savedOn, meal: item.meal,
                            body: "Had some of \(item.name) and saved the rest. Portions and nutrition are unknown.")
        try await saveNote(note)
        try update(owner: owner, generation: expected) { data in
            guard let index = data.leftovers.firstIndex(where: { $0.id == id }) else { return }
            data.leftovers[index].initialNoteSaved = true
        }
    }
    func finishLeftover(id: UUID, owner: UUID, generation expected: UUID, on day: String,
                        saveNote: (MealNote) async throws -> Void) async throws {
        guard owner == accountId, expected == generation,
              let item = data.leftovers.first(where: { $0.id == id }), item.initialNoteSaved == true
        else { throw URLError(.userAuthenticationRequired) }
        guard item.finishedOn == nil else { return }
        let requestedDay = item.finishRequestedOn ?? day
        try update(owner: owner, generation: expected) { data in
            guard let index = data.leftovers.firstIndex(where: { $0.id == id }) else { return }
            data.leftovers[index].finishRequestedOn = requestedDay
        }
        try await saveNote(MealNote(id: item.finishNoteId, userId: owner, logDate: requestedDay, meal: item.meal, body: item.finishBody))
        try update(owner: owner, generation: expected) { data in
            guard let index = data.leftovers.firstIndex(where: { $0.id == id }) else { return }
            data.leftovers[index].finishedOn = requestedDay
        }
    }

    #if DEBUG
    func preview() {
        accountId = AppStoreScreenshotPreview.sampleUser; generation = UUID(); error = nil
        data = .init(experiments: [.init(action: "A short walk after lunch", outcome: "Afternoon energy", startedOn: "2026-10-17",
            observations: [.init(day: "2026-10-17", tried: true, rating: 4), .init(day: "2026-10-18", tried: false, rating: 3)])],
            leftovers: [.init(name: "Chicken and rice bowl", savedOn: "2026-10-19", meal: .lunch, initialNoteSaved: true)],
            constraints: [OneDecision.food.rawValue: "Ten minutes, at home. Something cold and easy sounds better today."])
    }
    #endif
    func purgeAccount(_ owner: UUID) throws {
        if FileManager.default.fileExists(atPath: url(owner).path) { try FileManager.default.removeItem(at: url(owner)) }
        if accountId == owner { accountId = nil; generation = UUID(); data = .init(); error = nil }
    }
}
