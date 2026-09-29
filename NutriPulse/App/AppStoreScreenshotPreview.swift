import SwiftUI

enum AppStoreScreenshotMode {
    static var active: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--store-today") || ProcessInfo.processInfo.arguments.contains("--store-food")
        #else
        false
        #endif
    }
}

#if DEBUG
// Read-only fixtures using production views. No account, parsing, or persistence.
struct AppStoreScreenshotPreview: View {
    @State private var today = Self.todayModel()
    @State private var tab: MainTab = .today
    var body: some View {
        Group {
            if ProcessInfo.processInfo.arguments.contains("--store-food") {
                FoodLoggingView(selectedDate: .now)
            } else {
                TodayView(vm: today)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        MainTabBar(selected: $tab, onLog: {})
                    }
            }
        }
        .allowsHitTesting(false)
    }

    static let sampleUser = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static var week: StrongWeek {
        .init(id: UUID(), userId: sampleUser, weekStart: StrongWeekWindow.key(), circumstances: [.usual],
              note: "", activityRestrictions: "", ongoing: false, contextRevision: UUID(),
              outlook: .init(observation: "Keep meals simple and protein within reach. Leave room for walks and your familiar movement routine.",
                             foodFocus: "Choose a familiar protein-rich breakfast.", movementFocus: "Make room for a walk when it fits your day."),
              generatedAt: .now, updatedAt: .now)
    }

    @MainActor static func todayModel() -> TodayViewModel {
        let vm = TodayViewModel()
        vm.dailyGoal = .init(id: UUID(), userId: sampleUser, effectiveDate: StrongWeekWindow.key(),
                            calories: 2000, proteinG: 130, carbsG: 220, fatG: 65, fiberG: 28, waterMlTarget: 2000)
        let meals: [(String, Meal, Double, Double, Double, Double, Double)] = [
            ("Greek yogurt with berries", .breakfast, 320, 30, 38, 7, 6),
            ("Chicken, rice & avocado bowl", .lunch, 640, 48, 65, 21, 10),
            ("Apple with peanut butter", .snack, 240, 7, 30, 10, 5)
        ]
        vm.foodLogs = meals.map { name, meal, calories, protein, carbs, fat, fiber in
            .init(id: UUID(), userId: sampleUser, loggedAt: .now, logDate: Date.now.ISO8601Format().prefix(10).description,
                  meal: meal, foodItemId: UUID(), quantity: 1, caloriesSnapshot: calories, proteinGSnapshot: protein,
                  carbsGSnapshot: carbs, fatGSnapshot: fat, fiberGSnapshot: fiber,
                  foodItems: .init(name: name, brand: nil, servingDesc: "1 serving"))
        }
        vm.waterIntakeMl = 1250
        vm.activeCalories = 280
        vm.sleepHours = 7.5
        vm.restingHeartRate = 62
        vm.hrv = 48
        return vm
    }

    @MainActor static func foodModel() -> TalkToLogViewModel {
        let vm = TalkToLogViewModel()
        vm.inputText = "I had grilled chicken, brown rice, and half an avocado for lunch."
        vm.selectedMeal = .lunch
        vm.rows = [
            .init(name: "Chicken breast", servingDesc: "1 breast", grams: 140, quantity: 1,
                  calories: 231, proteinG: 43, carbsG: 0, fatG: 5, fiberG: 0, source: "estimated", initialQuantity: 1),
            .init(name: "Brown rice", servingDesc: "1 cup cooked", grams: 195, quantity: 1,
                  calories: 216, proteinG: 5, carbsG: 45, fatG: 2, fiberG: 4, source: "estimated", initialQuantity: 1),
            .init(name: "Avocado", servingDesc: "½ avocado", grams: 75, quantity: 1,
                  calories: 120, proteinG: 2, carbsG: 6, fatG: 11, fiberG: 5, source: "estimated", initialQuantity: 1)
        ]
        return vm
    }
}
#endif
