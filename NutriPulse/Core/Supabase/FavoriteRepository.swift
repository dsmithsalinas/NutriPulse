import Foundation

struct FavoriteRepository {

    func fetchFavoriteIds() async throws -> Set<UUID> {
        struct Row: Decodable {
            let foodItemId: UUID
            enum CodingKeys: String, CodingKey { case foodItemId = "food_item_id" }
        }
        let userId = try await supabase.auth.session.user.id
        let rows: [Row] = try await supabase
            .from("food_favorites")
            .select("food_item_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        return Set(rows.map(\.foodItemId))
    }

    func setFavorited(_ favorited: Bool, foodItemId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id
        if favorited {
            struct NewFav: Encodable {
                let userId: UUID; let foodItemId: UUID
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"; case foodItemId = "food_item_id"
                }
            }
            try await supabase
                .from("food_favorites")
                .insert(NewFav(userId: userId, foodItemId: foodItemId))
                .execute()
        } else {
            try await supabase
                .from("food_favorites")
                .delete()
                .eq("user_id", value: userId)
                .eq("food_item_id", value: foodItemId)
                .execute()
        }
    }

    func fetchQuickAdds() async throws -> [FavoriteQuickAdd] {
        return try await supabase
            .rpc("get_favorite_quick_adds")
            .execute()
            .value
    }

    // Writes local-first, exactly like every other logging path (search, scan, manual,
    // talk). Inserting straight into Supabase meant the Today screen — which reads only
    // from LocalStore — didn't show the food until the next foreground pull, so users
    // assumed the tap failed and logged it again. It also meant the whole flow was the
    // one logging path that didn't work offline.
    //
    // The food_item already exists (it's what was favorited), so there's nothing to
    // upsert here — just the log row.
    @MainActor
    func quickLog(_ fav: FavoriteQuickAdd, on date: Date, meal: Meal) async throws {
        let userId = try await supabase.auth.session.user.id
        try LocalStore.shared.insertFoodLog(
            id: UUID(),
            userId: userId,
            logDate: date.isoDateString,
            meal: meal.rawValue,
            foodItemId: fav.foodItemId,
            foodItemName: fav.name,
            quantity: fav.quantity,
            caloriesSnapshot: fav.caloriesSnapshot,
            proteinGSnapshot: fav.proteinGSnapshot,
            carbsGSnapshot: fav.carbsGSnapshot,
            fatGSnapshot: fav.fatGSnapshot,
            fiberGSnapshot: fav.fiberGSnapshot
        )
        SyncEngine.shared.refreshPendingCount()
        Task { await SyncEngine.shared.pushPendingChanges() }
    }
}
