import XCTest
@testable import Footing

final class NutritionImportTests: XCTestCase {
    private let source = NutritionSource(id: "diabetes.app", name: "Diabetes tracker")
    private var local: DailySummary { .init(date: .now, calories: 1200, proteinG: 85, carbsG: 133, fatG: 38, fiberG: 21) }
    private func sample(_ value: Double, id: UUID = UUID(), date: Date = .now, source: NutritionSource? = nil, macro: NutritionMacro = .carbs) -> ImportedNutritionSample {
        .init(id: id, macro: macro, date: date, value: value, source: source ?? self.source)
    }
    func testSelectedSourceReplacesOnlyItsMacroAndExcludesOtherSources() {
        let result = NutritionResolver.resolve(local, selections: [.carbs: source], samples: [sample(42), sample(30), sample(100, source: .init(id: "other", name: "Other"))])
        XCTAssertEqual(result.carbsG, 72)
        XCTAssertEqual(result.proteinG, 85)
        XCTAssertEqual(result.calories, 1200)
        XCTAssertEqual(result.nutritionSources[.carbs], source.name)
    }
    func testRepeatedUUIDCountsOnceButEqualDistinctEntriesBothCount() {
        let repeated = sample(20)
        let result = NutritionResolver.resolve(local, selections: [.carbs: source], samples: [repeated, repeated, sample(20)])
        XCTAssertEqual(result.carbsG, 40)
    }
    func testNoReadableDataIsUnknownAndDoesNotFallbackToFooting() {
        let result = NutritionResolver.resolve(local, selections: [.carbs: source, .protein: source], samples: [])
        XCTAssertEqual(result.carbsG, 0)
        XCTAssertTrue(result.unavailableMacros.contains(.carbs))
        XCTAssertTrue(result.unavailableMacros.contains(.protein))
        XCTAssertNil(result.proteinFloorHit(target: 1))
        XCTAssertFalse(result.hasData)
    }
    func testExplicitZeroIsKnownAndCaloriesAreNotInferred() {
        let result = NutritionResolver.resolve(local, selections: [.carbs: source, .calories: source], samples: [sample(0)])
        XCTAssertFalse(result.unavailableMacros.contains(.carbs))
        XCTAssertTrue(result.unavailableMacros.contains(.calories))
        XCTAssertEqual(result.calories, 0)
    }
    func testRereadReflectsCorrectionsAndDeletionWithoutAppending() {
        let selected: [NutritionMacro: NutritionSource] = [.carbs: source]
        XCTAssertEqual(NutritionResolver.resolve(local, selections: selected, samples: [sample(42)]).carbsG, 42)
        XCTAssertEqual(NutritionResolver.resolve(local, selections: selected, samples: [sample(30)]).carbsG, 30)
        XCTAssertTrue(NutritionResolver.resolve(local, selections: selected, samples: []).unavailableMacros.contains(.carbs))
        XCTAssertEqual(NutritionResolver.resolve(local, selections: [:], samples: [sample(42)]).carbsG, 133)
    }
    func testEachMacroCanHaveAnIndependentSource() {
        let selections = Dictionary(uniqueKeysWithValues: NutritionMacro.allCases.map { ($0, source) })
        let entries = NutritionMacro.allCases.enumerated().map { sample(Double($0.offset + 1), macro: $0.element) }
        let day = NutritionResolver.resolve(local, selections: selections, samples: entries)
        XCTAssertEqual(day.calories, 1); XCTAssertEqual(day.proteinG, 2)
        XCTAssertEqual(day.carbsG, 3); XCTAssertEqual(day.fatG, 4); XCTAssertEqual(day.fiberG, 5)
        XCTAssertTrue(day.unavailableMacros.isEmpty)
    }
    func testProteinFloorCanBeConfirmedWithoutCalorieData() {
        var empty = DailySummary(date: .now, calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0)
        empty.unavailableMacros = Set(NutritionMacro.allCases)
        let result = NutritionResolver.resolve(empty, selections: [.protein: source], samples: [sample(140, macro: .protein)])
        XCTAssertTrue(result.hasProteinData)
        XCTAssertFalse(result.hasCalorieData)
        XCTAssertEqual(result.proteinFloorHit(target: 130), true)
        let evidence = StrongWeekEvidence.nutrition([result], expectedDays: 1, target: 130)
        XCTAssertNil(evidence.averageLoggedCalories)
        let recap = WeeklyRecapDigest.build(interval: (start: Calendar.current.startOfDay(for: .now), end: .now, priorStart: .distantPast),
            summaries: [result], movement: [], weightLogs: [], checkIns: [], foodNames: [], proteinGoal: 130)
        XCTAssertNil(recap.avgCalories)
        XCTAssertEqual(recap.avgProteinG, 140)
    }
    func testCarbsOnlyImportDoesNotInventMissingProteinOrCalories() {
        var empty = DailySummary(date: .now, calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0)
        empty.unavailableMacros = Set(NutritionMacro.allCases)
        let result = NutritionResolver.resolve(empty, selections: [.carbs: source], samples: [sample(42)])
        XCTAssertFalse(result.unavailableMacros.contains(.carbs))
        XCTAssertTrue(result.unavailableMacros.contains(.calories))
        XCTAssertTrue(result.unavailableMacros.contains(.protein))
        XCTAssertFalse(result.hasData)
    }
    func testDateBoundaryAndInvalidValuesAreExcluded() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let result = NutritionResolver.resolve(local, selections: [.carbs: source], samples: [sample(42, date: yesterday), sample(-1), sample(.nan), sample(.infinity), sample(12)])
        XCTAssertEqual(result.carbsG, 12)
    }
    @MainActor func testPreferencesAreAccountScopedAndSignOutClearsHealthValues() {
        let suite = "NutritionImportTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = NutritionImportStore(defaults: defaults, allowsHealthQueries: false)
        let first = UUID(), second = UUID()
        store.setAccount(first)
        store.select(source, for: .carbs)
        store.setAccount(second)
        XCTAssertTrue(store.selections.isEmpty)
        XCTAssertTrue(store.samples.isEmpty)
        store.setAccount(first)
        XCTAssertEqual(store.selections[.carbs], source)
        store.setAccount(nil)
        XCTAssertTrue(store.selections.isEmpty)
        XCTAssertTrue(store.samples.isEmpty)
    }
}
