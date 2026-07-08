import Observation
import Foundation

// Shared observable store for favorited food_item_ids.
// @Observable means any SwiftUI view that reads `favoritedIds` (via isFavorited) will
// automatically re-render when the set changes — even though this is a global singleton,
// not an @Environment or @State value.
@Observable
@MainActor
final class FavoritesStore {
    static let shared = FavoritesStore()
    private init() {}

    private(set) var favoritedIds: Set<UUID> = []
    private var isLoaded = false
    private let repo = FavoriteRepository()

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true
        do {
            favoritedIds = try await repo.fetchFavoriteIds()
        } catch {
            isLoaded = false
        }
    }

    func isFavorited(_ foodItemId: UUID) -> Bool {
        favoritedIds.contains(foodItemId)
    }

    func toggle(foodItemId: UUID) async {
        let wasFavorited = favoritedIds.contains(foodItemId)
        if wasFavorited { favoritedIds.remove(foodItemId) } else { favoritedIds.insert(foodItemId) }
        do {
            try await repo.setFavorited(!wasFavorited, foodItemId: foodItemId)
        } catch {
            if wasFavorited { favoritedIds.insert(foodItemId) } else { favoritedIds.remove(foodItemId) }
        }
    }

    func insertId(_ foodItemId: UUID) {
        favoritedIds.insert(foodItemId)
    }

    // Called on sign-out. This is a process-lifetime singleton, so without an explicit
    // reset the next account sees the previous user's favorite stars until relaunch.
    func reset() {
        favoritedIds = []
        isLoaded = false
    }
}
