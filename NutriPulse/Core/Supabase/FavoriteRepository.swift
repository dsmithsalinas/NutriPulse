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

    func quickLog(_ fav: FavoriteQuickAdd, on date: Date) async throws {
        let userId = try await supabase.auth.session.user.id
        let newLog = NewFoodLog(
            userId: userId,
            loggedAt: Date(),
            logDate: date.isoDateString,
            meal: Meal.current,
            foodItemId: fav.foodItemId,
            quantity: fav.quantity,
            caloriesSnapshot: fav.caloriesSnapshot,
            proteinGSnapshot: fav.proteinGSnapshot,
            carbsGSnapshot: fav.carbsGSnapshot,
            fatGSnapshot: fav.fatGSnapshot,
            fiberGSnapshot: fav.fiberGSnapshot
        )
        try await supabase.from("food_logs").insert(newLog).execute()
    }
}
