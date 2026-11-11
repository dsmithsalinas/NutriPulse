import Observation
import Foundation
import Supabase

// Backs the Daylight Favorites tab (docs/daylight-redesign.md): the favorites grid, plus
// "Recents from the last 72 hours" grouped by day with favorited foods hidden. Grouping/
// filtering logic itself lives in RecentFoodsGrouper (pure, unit-tested).
@Observable
@MainActor
final class FavoritesViewModel {
    struct RecentSection: Identifiable {
        let id: String
        let label: String
        let logs: [FoodLog]
    }

    private(set) var favorites: [FavoriteQuickAdd] = []
    private(set) var recentSections: [RecentSection] = []
    var isLoading = true
    var errorMessage: String? = nil

    private let favRepo = FavoriteRepository()

    var isEmpty: Bool { favorites.isEmpty && recentSections.isEmpty }

    private var usesLayoutPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--log-preview") && (ProcessInfo.processInfo.arguments.contains("--favorites-preview") || ProcessInfo.processInfo.arguments.contains("--food-review-preview"))
        #else
        false
        #endif
    }

    func load() async {
        #if DEBUG
        if usesLayoutPreview {
            favorites = [("Protein shake", 30.0), ("Greek yogurt, berries & granola", 24.0), ("Cottage cheese", 25.0), ("Salmon rice bowl", 36.0)].map { name, protein in
                FavoriteQuickAdd(foodItemId: UUID(), name: name, brand: nil, servingDesc: "1 serving", quantity: 1,
                                 caloriesSnapshot: 220, proteinGSnapshot: protein, carbsGSnapshot: 20, fatGSnapshot: 8, fiberGSnapshot: 3)
            }
            recentSections = [.init(id: "today", label: "Today", logs: Array(AppStoreScreenshotPreview.todayModel().foodLogs.suffix(2)))]
            isLoading = false
            return
        }
        #endif
        isLoading = true
        defer { isLoading = false }
        favorites = (try? await favRepo.fetchQuickAdds()) ?? []
        await refreshRecents()
    }

    private func refreshRecents() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            recentSections = []
            return
        }
        let history: [FoodLog]
        do {
            history = try await FoodLogRepository().familiarHistory()
        } catch {
            history = (try? LocalStore.shared.fetchFoodLogs(since: .distantPast, userId: userId)) ?? []
        }
        guard (try? await supabase.auth.session.user.id) == userId else { return }
        let favoritedIds = Set(favorites.map(\.foodItemId))
        let recent = FamiliarFoods.suggestions(history.filter { !favoritedIds.contains($0.foodItemId) }, limit: 20)
            .sorted { $0.loggedAt > $1.loggedAt }
        recentSections = RecentFoodsGrouper.grouped(recent).map {
            RecentSection(id: $0.id, label: $0.label, logs: $0.logs)
        }
    }

    // Writes local-first, same as every other logging path in this feature — see
    // FavoriteRepository.quickLog.
    func logFavorite(_ fav: FavoriteQuickAdd, meal: Meal, date: Date) async -> Bool {
        guard !usesLayoutPreview else { return false }
        do {
            try await favRepo.quickLog(fav, on: date, meal: meal)
            return true
        } catch {
            errorMessage = "Couldn't log \(fav.name). Try again."
            return false
        }
    }

    // "Log again" on a Recents row: a fresh log entry with that row's snapshot macros, under
    // a new id and today's timestamp — the food_item itself already exists, so there's nothing
    // to upsert.
    func logAgain(_ log: FoodLog, meal: Meal, date: Date, quantity: Double? = nil) async -> Bool {
        guard !usesLayoutPreview else { return false }
        do {
            let userId = try await supabase.auth.session.user.id
            try LocalStore.shared.insertFoodLog(
                id: UUID(),
                userId: userId,
                logDate: date.isoDateString,
                meal: meal.rawValue,
                foodItemId: log.foodItemId,
                foodItemName: log.displayName,
                quantity: quantity ?? log.quantity,
                caloriesSnapshot: log.caloriesSnapshot,
                proteinGSnapshot: log.proteinGSnapshot,
                carbsGSnapshot: log.carbsGSnapshot,
                fatGSnapshot: log.fatGSnapshot,
                fiberGSnapshot: log.fiberGSnapshot
            )
            SyncEngine.shared.refreshPendingCount()
            Task { await SyncEngine.shared.pushPendingChanges() }
            return true
        } catch {
            errorMessage = "Couldn't log \(log.displayName). Try again."
            return false
        }
    }

    // Starring a Recents row favorites it and — since Recents hides favorited foods — drops
    // it from the list; refreshing also picks it up in the favorites grid.
    func addToFavorites(_ log: FoodLog) async {
        guard !usesLayoutPreview else { return }
        await FavoritesStore.shared.toggle(foodItemId: log.foodItemId)
        await load()
    }
}
