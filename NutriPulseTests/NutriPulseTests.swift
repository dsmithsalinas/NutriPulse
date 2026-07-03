import XCTest
@testable import NutriPulse

final class NutriPulseTests: XCTestCase {
    func testMealSortOrder() {
        let meals = Meal.allCases.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(meals, [.breakfast, .lunch, .dinner, .snack])
    }

    func testFoodLogTotals() {
        let log = FoodLog(
            id: UUID(),
            userId: UUID(),
            loggedAt: Date(),
            logDate: "2024-03-15",
            meal: .breakfast,
            foodItemId: UUID(),
            quantity: 2.0,
            caloriesSnapshot: 100,
            proteinGSnapshot: 10,
            carbsGSnapshot: 15,
            fatGSnapshot: 3,
            fiberGSnapshot: 2,
            foodItems: nil
        )
        XCTAssertEqual(log.totalCalories, 200)
        XCTAssertEqual(log.totalProteinG, 20)
        XCTAssertEqual(log.totalFiberG, 4)
    }

    func testDateISOString() {
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 15
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.isoDateString, "2024-03-15")
    }
}
