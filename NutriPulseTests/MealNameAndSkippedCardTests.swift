import XCTest
@testable import Footing

final class MealNameAndSkippedCardTests: XCTestCase {
    private func food(_ name: String, owner: UUID, meal: Meal = .breakfast) -> FoodLog {
        .init(id: UUID(), userId: owner, loggedAt: .now, logDate: "2026-10-19", meal: meal,
              foodItemId: UUID(), quantity: 1, caloriesSnapshot: 150, proteinGSnapshot: 30,
              carbsGSnapshot: 5, fatGSnapshot: 2, fiberGSnapshot: 1,
              foodItems: .init(name: name, brand: nil, servingDesc: "1 serving"))
    }

    func testSingleFoodStartsWithASavableRealName() {
        let owner = UUID()
        let foods = [food("Nutrition Plan Vanilla (11.5 oz)", owner: owner)]
        let name = UsualMeal.suggestedName(for: foods)
        XCTAssertEqual(name, "Nutrition Plan Vanilla (11.5 oz)")
        XCTAssertNil(UsualMeal.nameValidationMessage(name))
        let validFoods = [food(name, owner: owner)]
        XCTAssertTrue(UsualMeal(userId: owner, name: name, meal: .breakfast, items: validFoods).isValid)
    }

    func testMultipleFoodsAndOversizeNamesGetUsableSuggestions() {
        let owner = UUID()
        let foods = [food("Yogurt", owner: owner, meal: .lunch), food("Berries", owner: owner, meal: .lunch)]
        XCTAssertEqual(UsualMeal.suggestedName(for: foods), "My usual lunch")
        XCTAssertEqual(UsualMeal.suggestedName(for: [food(String(repeating: "a", count: 81), owner: owner)]), "My usual breakfast")
    }

    func testClearingNameExplainsWhySaveIsUnavailable() {
        XCTAssertEqual(UsualMeal.nameValidationMessage(" \n "), "Enter a meal name to save.")
        XCTAssertNotNil(UsualMeal.nameValidationMessage(String(repeating: "a", count: 81)))
        XCTAssertNil(UsualMeal.nameValidationMessage("  " + String(repeating: "a", count: 80) + "  "))
    }

    private func skip(owner: UUID, id: UUID = UUID()) -> GLP1SkippedDose {
        .init(id: id, userId: owner, injectionId: UUID(), scheduledAt: .now,
              nextReminderAt: .now.addingTimeInterval(7 * 86400), createdAt: .now)
    }

    func testDismissalPersistsPerAccountAndDoesNotHideANewSkip() {
        let a = skip(owner: UUID()), b = skip(owner: UUID())
        let stored = SkippedShotCardDismissal.recording(a, in: "")
        XCTAssertTrue(SkippedShotCardDismissal.contains(a, in: stored))
        XCTAssertFalse(SkippedShotCardDismissal.contains(b, in: stored))
        XCTAssertFalse(SkippedShotCardDismissal.contains(skip(owner: b.userId, id: a.id), in: stored))
        XCTAssertFalse(SkippedShotCardDismissal.contains(skip(owner: a.userId), in: stored))
        let both = SkippedShotCardDismissal.recording(b, in: stored)
        XCTAssertTrue(SkippedShotCardDismissal.contains(a, in: both))
        XCTAssertTrue(SkippedShotCardDismissal.contains(b, in: both))
    }

    func testDismissalDoesNotChangeSavedSkipOrReminderSchedule() {
        let owner = UUID()
        let skipped = skip(owner: owner)
        let shot = GLP1Log(id: skipped.injectionId, userId: owner,
                           injectedAt: skipped.scheduledAt.addingTimeInterval(-7 * 86400),
                           medication: "Example", doseMg: 5, site: "Left Abdomen", nextDueAt: skipped.scheduledAt)
        let schedule = GLP1DoseSchedule(latest: shot, skips: [skipped])
        _ = SkippedShotCardDismissal.recording(skipped, in: "invalid old storage")
        XCTAssertEqual(schedule.skips.first?.id, skipped.id)
        XCTAssertEqual(schedule.nextDue, skipped.nextReminderAt)
    }
}
