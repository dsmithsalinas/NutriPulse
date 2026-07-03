import Observation
import Foundation
import Supabase

@Observable
@MainActor
final class FoodSearchViewModel {
    var searchQuery = ""
    var results: [FoodSearchResult] = []
    var isSearching = false

    // Set when the user taps a result — triggers the detail sheet
    var selectedResult: FoodSearchResult? = nil
    var detail: FoodDetail? = nil
    var isLoadingDetail = false

    // Detail sheet form state
    var selectedServing: FoodServing? = nil
    var selectedMeal: Meal = .current
    var quantity: Double = 1.0

    var isLogging = false
    var errorMessage: String? = nil

    private let client = FatSecretClient()

    // Called from .task(id: searchQuery) in FoodSearchView.
    // The task auto-cancels when searchQuery changes, giving us debounce for free.
    func search() async {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await client.search(query: q)
        } catch {
            // Network errors during typing are silent; the field stays empty
        }
    }

    func loadDetail(for result: FoodSearchResult) async {
        selectedResult = result
        detail = nil
        selectedServing = nil
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        do {
            let loaded = try await client.getFood(id: result.id)
            detail = loaded
            selectedServing = loaded.servings.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var macroPreview: (calories: Double, proteinG: Double, carbsG: Double, fatG: Double, fiberG: Double)? {
        guard let s = selectedServing else { return nil }
        return (
            s.calories  * quantity,
            s.proteinG  * quantity,
            s.carbsG    * quantity,
            s.fatG      * quantity,
            s.fiberG    * quantity
        )
    }

    func logFood(on date: Date) async throws {
        guard let detail, let serving = selectedServing else { return }
        isLogging = true
        defer { isLogging = false }

        let userId = try await supabase.auth.session.user.id

        // Upsert the food_item so logging the same FatSecret food twice doesn't duplicate rows.
        // The UNIQUE (source, external_id) constraint resolves the conflict.
        let newItem = NewFoodItem(
            userId: userId,
            source: "fatsecret",
            externalId: detail.id,
            name: detail.name,
            brand: detail.brand,
            servingDesc: serving.description,
            servingGrams: serving.grams,
            calories: serving.calories,
            proteinG: serving.proteinG,
            carbsG: serving.carbsG,
            fatG: serving.fatG,
            fiberG: serving.fiberG
        )

        let item: FoodItem = try await supabase
            .from("food_items")
            .upsert(newItem, onConflict: "source,external_id")
            .select()
            .single()
            .execute()
            .value

        let newLog = NewFoodLog(
            userId: userId,
            loggedAt: Date(),
            logDate: date.isoDateString,
            meal: selectedMeal,
            foodItemId: item.id,
            quantity: quantity,
            caloriesSnapshot: serving.calories,
            proteinGSnapshot: serving.proteinG,
            carbsGSnapshot: serving.carbsG,
            fatGSnapshot: serving.fatG,
            fiberGSnapshot: serving.fiberG
        )

        try await supabase.from("food_logs").insert(newLog).execute()
    }
}
