import XCTest
@testable import Footing

final class HealthExperienceActionsTests: XCTestCase {
    private func experiment() -> TinyExperiment {
        var result = TinyExperiment(action: "A long walk", outcome: "Energy", startedOn: "2026-10-01", healthLink: .init(metric: .walking))
        result.observations = (1...6).map { .init(day: String(format: "2026-10-%02d", $0), tried: true, rating: 3) }
        return result
    }
    func testFeedbackExpiresAndUndoDoesNotTouchCheckInsOrExperiments() {
        var data = EverydayToolData(experiments: [experiment()])
        let original = data.experiments
        data.setCycleFit(.different, day: "2026-10-24", cycleDay: 1)
        XCTAssertEqual(data.cycleFit(on: "2026-10-24", cycleDay: 1), .different)
        XCTAssertNil(data.cycleFit(on: "2026-10-25", cycleDay: 1))
        XCTAssertNil(data.cycleFit(on: "2026-10-24", cycleDay: 2))
        data.setCycleFit(.notUseful, day: "2026-10-24", cycleDay: 1)
        XCTAssertEqual(data.cycleFeedback?.count, 1)
        data.setCycleFit(nil, day: "2026-10-24", cycleDay: 1)
        XCTAssertNil(data.cycleFit(on: "2026-10-24", cycleDay: 1))
        XCTAssertEqual(data.experiments, original)
    }
    @MainActor func testFeedbackAndWrapUpStayWithTheirOwner() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = EverydayToolsStore(directory: directory), a = UUID(), b = UUID()
        store.setAccount(a); let generation = store.generation
        try store.update(owner: a, generation: generation) { $0.setCycleFit(.different, day: "2026-10-24", cycleDay: 1) }
        store.setAccount(b)
        XCTAssertNil(store.data.cycleFit(on: "2026-10-24", cycleDay: 1))
        XCTAssertThrowsError(try store.update(owner: a, generation: generation) { $0.setCycleFit(.notUseful, day: "2026-10-24", cycleDay: 1) })
        store.setAccount(a)
        XCTAssertEqual(store.data.cycleFit(on: "2026-10-24", cycleDay: 1), .different)
    }
    func testRecipeRequiresAnActualHelpAndNeverSilentlyTruncates() {
        var draft = EasierDayRecipeDraft()
        XCTAssertNil(draft.memory)
        draft.food = "Yogurt and fruit"
        XCTAssertTrue(draft.memory?.contains("Food: Yogurt and fruit") == true)
        XCTAssertFalse(draft.memory?.contains("Water:") == true)
        draft.support = String(repeating: "🙂", count: 301)
        XCTAssertNil(draft.memory)
        XCTAssertGreaterThan(draft.draftText!.unicodeScalars.count, 300)
    }
    func testReflectionNeedsSixNewConfirmedDaysAndKeepDoesNotChangeHistory() throws {
        let original = experiment()
        XCTAssertTrue(original.readyToReflect)
        let next = try ExperimentWrapUp.applying(id: original.id, choice: .keepTrying, note: "Manageable", revisedAction: "", day: "2026-10-24", to: .init(experiments: [original]))
        XCTAssertEqual(next.experiments.count, 1)
        XCTAssertNil(next.experiments[0].completedOn)
        XCTAssertEqual(next.experiments[0].observations, original.observations)
        XCTAssertFalse(next.experiments[0].readyToReflect)
        XCTAssertEqual(next.experiments[0].reflection?.note, "Manageable")
    }
    func testEasierVersionHasFreshEvidenceAndKeepsOriginal() throws {
        let original = experiment()
        let next = try ExperimentWrapUp.applying(id: original.id, choice: .makeEasier, note: "Shorter is better for me", revisedAction: "A five-minute walk", day: "2026-10-24", to: .init(experiments: [original]))
        XCTAssertEqual(next.experiments[0].observations, original.observations)
        XCTAssertEqual(next.experiments[0].completedOn, "2026-10-24")
        XCTAssertEqual(next.experiments[1].parentExperimentId, original.id)
        XCTAssertTrue(next.experiments[1].observations.isEmpty)
        XCTAssertEqual(next.experiments[1].healthLink, original.healthLink)
        XCTAssertThrowsError(try ExperimentWrapUp.applying(id: original.id, choice: .makeEasier, note: "", revisedAction: "Again", day: "2026-10-24", to: next))
    }
    func testFinishKeepsReflectionAndCapacityCannotPartiallyFinishOriginal() throws {
        let original = experiment()
        let next = try ExperimentWrapUp.applying(id: original.id, choice: .finish, note: "Enough for now", revisedAction: "", day: "2026-10-24", to: .init(experiments: [original]))
        XCTAssertEqual(next.experiments.count, 1)
        XCTAssertEqual(next.experiments[0].reflection?.nextStep, .finish)
        XCTAssertEqual(next.experiments[0].observations, original.observations)
        let full = EverydayToolData(experiments: (0..<20).map { _ in experiment() })
        XCTAssertThrowsError(try ExperimentWrapUp.applying(id: full.experiments[0].id, choice: .makeEasier, note: "", revisedAction: "Shorter", day: "2026-10-24", to: full))
        XCTAssertNil(full.experiments[0].completedOn)
    }
    func testLegacyDataAndReflectionRoundTrip() throws {
        let data = EverydayToolData(experiments: [experiment()])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(data)) as? [String: Any])
        object.removeValue(forKey: "cycleFeedback")
        let restored = try JSONDecoder().decode(EverydayToolData.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.cycleFeedback)
        let finished = try ExperimentWrapUp.applying(id: data.experiments[0].id, choice: .finish, note: "Enough", revisedAction: "", day: "2026-10-24", to: restored)
        XCTAssertEqual(try JSONDecoder().decode(EverydayToolData.self, from: JSONEncoder().encode(finished)), finished)
    }
}
