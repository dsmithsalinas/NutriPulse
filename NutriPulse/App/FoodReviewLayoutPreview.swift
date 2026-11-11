#if DEBUG
import SwiftUI

/// Real review sheets with local fixtures; screenshots never require lookup or a food save.
struct FoodReviewLayoutPreview: View {
    @State private var presented = true
    @State private var search = FoodSearchViewModel()
    private let result = FoodSearchResult(id: "layout-preview", name: "Greek yogurt, berries & granola", brand: nil, description: "")

    var body: some View {
        FoodLoggingView(selectedDate: .now)
            .sheet(isPresented: $presented) {
                if ProcessInfo.processInfo.arguments.contains("--familiar-review-preview") {
                    FamiliarFoodReview(food: AppStoreScreenshotPreview.todayModel().foodLogs[0], date: .now, meal: .lunch, onSaved: {})
                } else if ProcessInfo.processInfo.arguments.contains("--repeat-review-preview") {
                    RepeatedMealConfirmationSheet(sourceDate: Date.now.isoDateString, meal: .lunch, vm: TodayViewModel())
                } else {
                    FoodDetailSheet(vm: search, result: result, date: .now, source: .search, onLogged: { _ in })
                }
            }
            .onAppear {
                let serving = FoodServing(id: "bowl", description: "1 bowl (250 g)", grams: 250, calories: 320, proteinG: 24, carbsG: 38, fatG: 9, fiberG: 6)
                search.detail = FoodDetail(id: result.id, name: result.name, brand: nil, servings: [serving, FoodServing(id: "grams", description: "100 g", grams: 100, calories: 128, proteinG: 9.6, carbsG: 15.2, fatG: 3.6, fiberG: 2.4)])
                search.selectedServing = serving
                search.selectedMeal = .lunch
            }
    }
}
#endif
