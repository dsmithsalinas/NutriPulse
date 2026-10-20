import XCTest
import SwiftData
@testable import Footing

final class EverydayToolsLogicTests: XCTestCase {
    func testBlankExperimentDaysNeverBecomeNotTried() {
        let experiment = TinyExperiment(action: "Walk", outcome: "Energy", startedOn: "2026-10-01",
                                        observations: [.init(day: "2026-10-02", tried: true, rating: 4)])
        XCTAssertTrue(experiment.summary.contains("Tried: 1 · Didn’t try: 0"))
        XCTAssertTrue(experiment.summary.contains("Not enough"))
    }
    func testComparisonNeedsBothGroupsAndNeverClaimsCause() {
        var experiment = TinyExperiment(action: "Walk", outcome: "Energy", startedOn: "2026-10-01")
        experiment.observations = (1...3).map { .init(day: "2026-10-0\($0)", tried: true, rating: 5) }
        XCTAssertTrue(experiment.summary.contains("Not enough"))
        experiment.observations += (4...6).map { .init(day: "2026-10-0\($0)", tried: false, rating: 3) }
        XCTAssertTrue(experiment.summary.contains("5.0/5 on 3 tried days"))
        XCTAssertTrue(experiment.summary.contains("3.0/5 on 3 explicitly not-tried days"))
        XCTAssertTrue(experiment.summary.contains("does not show cause"))
    }
    func testLeftoversAreQualitativeAndFinishNoteIdentitySurvivesRestart() throws {
        let item = SavedLeftover(name: "Chicken bowl", savedOn: "2026-10-19", meal: .lunch)
        let restored = try JSONDecoder().decode(SavedLeftover.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(restored.finishNoteId, item.finishNoteId)
        XCTAssertTrue(restored.finishBody.contains("nutrition are unknown"))
        let json = String(decoding: try JSONEncoder().encode(item), as: UTF8.self)
        XCTAssertFalse(json.contains("calories")); XCTAssertFalse(json.contains("protein"))
    }
    func testOneDecisionRequiresExplicitContextAndPreservesScope() throws {
        for decision in OneDecision.allCases {
            XCTAssertNil(decision.prompt(constraints: "  "))
            XCTAssertNil(decision.prompt(constraints: String(repeating: "a", count: 1001)))
            let request = try XCTUnwrap(decision.prompt(constraints: "10 minutes, at home"))
            XCTAssertTrue(request.contains("one concrete"))
            XCTAssertTrue(request.contains("Do not claim anything was logged"))
            XCTAssertTrue(request.contains("do not infer medical clearance"))
            XCTAssertTrue(decision.prompt(constraints: "10 minutes", alternative: true)!.contains("different option"))
        }
    }
    func testSiriWaterUnitsAndInvalidInput() throws {
        XCTAssertEqual(try XCTUnwrap(CaptureWaterUnit.fluidOunces.milliliters(for: 16)), 473.176473, accuracy: 0.001)
        XCTAssertEqual(CaptureWaterUnit.milliliters.milliliters(for: 250), 250)
        for value in [-1.0, 0, .nan, .infinity, 3001] {
            XCTAssertNil(CaptureWaterUnit.milliliters.milliliters(for: value))
        }
    }
}

@MainActor
final class EverydayToolsPersistenceTests: XCTestCase {
    func testRestartIsolationGenerationFenceAndAccountDeletion() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let a = UUID(), b = UUID(), store = EverydayToolsStore(directory: folder)
        store.setAccount(a); let oldGeneration = store.generation
        try store.update(owner: a, generation: oldGeneration) {
            $0.experiments.append(.init(action: "A private walk", outcome: "Energy", startedOn: "2026-10-19"))
            $0.leftovers.append(.init(name: "A private bowl", savedOn: "2026-10-19", meal: .lunch))
            $0.constraints[OneDecision.food.rawValue] = "A private constraint"
        }
        let restart = EverydayToolsStore(directory: folder); restart.setAccount(a)
        XCTAssertEqual(restart.data, store.data)
        store.setAccount(b); XCTAssertEqual(store.data, .init())
        XCTAssertThrowsError(try store.update(owner: a, generation: oldGeneration) { $0.leftovers = [] })
        store.setAccount(a)
        XCTAssertThrowsError(try store.update(owner: a, generation: oldGeneration) { $0.leftovers = [] })
        XCTAssertEqual(store.data.experiments.count, 1)
        store.setAccount(nil); XCTAssertEqual(store.data, .init())
        try store.purgeAccount(a)
        store.setAccount(a); XCTAssertEqual(store.data, .init())
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(a.uuidString + ".json").path))
    }
    func testCorruptStoreCannotBeOverwrittenByNewActions() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let owner = UUID(), file = folder.appendingPathComponent(owner.uuidString + ".json")
        let broken = Data("not-json".utf8); try broken.write(to: file)
        let store = EverydayToolsStore(directory: folder); store.setAccount(owner)
        XCTAssertNotNil(store.error)
        XCTAssertThrowsError(try store.update(owner: owner, generation: store.generation) { $0.leftovers = [] })
        XCTAssertEqual(try Data(contentsOf: file), broken)
    }
}

@MainActor
final class LeftoverWorkflowTests: XCTestCase {
    func testInterruptedFinishKeepsOriginalDateAndIdentityAcrossRestart() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let owner = UUID(), item = SavedLeftover(name: "Bowl", savedOn: "2026-10-19", meal: .lunch)
        let store = EverydayToolsStore(directory: folder); store.setAccount(owner)
        try store.update(owner: owner, generation: store.generation) { $0.leftovers = [item] }
        var notes: [UUID: MealNote] = [:]
        try await store.saveInitialLeftoverNote(id: item.id, owner: owner, generation: store.generation) { notes[$0.id] = $0 }
        do {
            try await store.finishLeftover(id: item.id, owner: owner, generation: store.generation, on: "2026-10-20") { _ in throw URLError(.cannotWriteToFile) }
            XCTFail("An unsaved note must not report finished")
        } catch {}
        XCTAssertNil(store.data.leftovers.first?.finishedOn)
        let restart = EverydayToolsStore(directory: folder); restart.setAccount(owner)
        try await restart.finishLeftover(id: item.id, owner: owner, generation: restart.generation, on: "2026-10-21") { notes[$0.id] = $0 }
        XCTAssertEqual(restart.data.leftovers.first?.finishedOn, "2026-10-20")
        XCTAssertEqual(notes[item.finishNoteId]?.logDate, "2026-10-20")
        try await restart.finishLeftover(id: item.id, owner: owner, generation: restart.generation, on: "2026-10-22") { _ in XCTFail("Already finished must not write again") }
        XCTAssertEqual(notes.count, 2)
        XCTAssertTrue(notes.values.allSatisfy { $0.userId == owner })
    }
    func testAccountSwitchDuringSaveCannotApplyOldCompletion() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let owner = UUID(), other = UUID(), store = EverydayToolsStore(directory: folder)
        store.setAccount(owner)
        let item = SavedLeftover(name: "Private bowl", savedOn: "2026-10-19", meal: .lunch)
        try store.update(owner: owner, generation: store.generation) { $0.leftovers = [item] }
        do {
            try await store.saveInitialLeftoverNote(id: item.id, owner: owner, generation: store.generation) { note in
                XCTAssertEqual(note.userId, owner)
                store.setAccount(other)
            }
            XCTFail("An old request must be rejected after account change")
        } catch {}
        XCTAssertEqual(store.data, .init())
        store.setAccount(owner)
        XCTAssertNotEqual(store.data.leftovers.first?.initialNoteSaved, true)
    }
}

@MainActor
final class QuickCaptureWaterPersistenceTests: XCTestCase {
    func testHistorySeparatesOwnersAndDaysAndRemovesTombstones() throws {
        let container = try ModelContainer(for: SDWaterLog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        LocalStore.shared.configure(with: container)
        let owner = UUID(), other = UUID(), first = UUID(), second = UUID()
        try LocalStore.shared.insertWaterLog(id: first, userId: owner, logDate: Date.now.isoDateString, amountMl: 250)
        try LocalStore.shared.insertWaterLog(id: second, userId: other, logDate: Date.now.isoDateString, amountMl: 500)
        try LocalStore.shared.insertWaterLog(id: UUID(), userId: owner, logDate: "2020-01-01", amountMl: 100)
        XCTAssertThrowsError(try LocalStore.shared.insertWaterLog(id: UUID(), userId: owner, logDate: Date.now.isoDateString, amountMl: .nan))
        XCTAssertEqual(try LocalStore.shared.waterHistory(for: .now, userId: owner).map(\.id), [first])
        try LocalStore.shared.markWaterLogDeleted(id: first)
        XCTAssertTrue(try LocalStore.shared.waterHistory(for: .now, userId: owner).isEmpty)
        XCTAssertEqual(try LocalStore.shared.waterHistory(for: .now, userId: other).map(\.id), [second])
    }
}
