import Observation
import Foundation
import Supabase

@Observable
@MainActor
final class FoodLoggingViewModel {
    enum LogTab: String, CaseIterable {
        case manual   = "Manual"
        case search   = "Search"
        case scan     = "Scan"
    }

    var selectedTab: LogTab = .manual
    var selectedMeal: Meal = .current   // pre-selects based on time of day
    var quantity: Double = 1.0

    // Manual entry fields (per serving)
    var name: String = ""
    var brand: String = ""
    var servingDesc: String = "1 serving"
    var servingGrams: Double = 100
    var calories: Double = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatG: Double = 0
    var fiberG: Double = 0

    var isLoading = false
    var errorMessage: String? = nil

    var canLog: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && calories > 0 }

    func logManualFood(on date: Date) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // `session` is async and throws AuthError if no valid session exists — safer than
        // `currentSession?` which can be nil briefly while the keychain restores on launch.
        let userId: UUID
        do {
            userId = try await supabase.auth.session.user.id
        } catch {
            throw URLError(.userAuthenticationRequired)
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // 1 — Insert the food item, get back the row (including the generated UUID)
        // SWIFT CONCEPT — `.select().single()` after `.insert()` tells PostgREST to return
        // the created row. Without it, insert returns 204 No Content and we have no id.
        let newItem = NewFoodItem(
            userId: userId,
            name: trimmedName,
            brand: brand.trimmingCharacters(in: .whitespaces).isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces),
            servingDesc: servingDesc.isEmpty ? "1 serving" : servingDesc,
            servingGrams: servingGrams > 0 ? servingGrams : 100,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG
        )

        let createdItem: FoodItem = try await supabase
            .from("food_items")
            .insert(newItem)
            .select()
            .single()
            .execute()
            .value

        // 2 — Insert the food log with the denormalized macro snapshot
        let newLog = NewFoodLog(
            userId: userId,
            loggedAt: Date(),
            logDate: date.isoDateString,
            meal: selectedMeal,
            foodItemId: createdItem.id,
            quantity: quantity,
            caloriesSnapshot: calories,
            proteinGSnapshot: proteinG,
            carbsGSnapshot: carbsG,
            fatGSnapshot: fatG,
            fiberGSnapshot: fiberG
        )

        try await supabase
            .from("food_logs")
            .insert(newLog)
            .execute()
    }
}
