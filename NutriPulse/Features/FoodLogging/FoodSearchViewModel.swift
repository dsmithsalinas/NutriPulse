import Observation
import Foundation
import Supabase

@Observable
@MainActor
final class FoodSearchViewModel {
    var searchQuery = ""
    var results: [FoodSearchResult] = []
    var isSearching = false
    private(set) var canLoadMoreResults = false
    private(set) var isLoadingMoreResults = false
    private var searchPage = 0

    // Set when the user taps a result — triggers the detail sheet
    var selectedResult: FoodSearchResult? = nil
    var detail: FoodDetail? = nil
    var isLoadingDetail = false

    // Detail sheet form state
    var selectedServing: FoodServing? = nil
    var selectedMeal: Meal = .current
    var quantity: Double = 1.0

    var isLogging = false
    // Presented by whichever view is on screen when the failure happens. These have to be
    // distinct: SwiftUI can't raise an alert from a view that is currently presenting a
    // sheet, so an error stored here while the detail sheet is up would never be seen.
    //   errorMessage — the search list / barcode scanner (no sheet up)
    //   detailError  — the detail sheet failed to load; replaces its content
    //   logError     — the detail sheet failed to log; alerts over its content
    var errorMessage: String? = nil
    var detailError: String? = nil
    var logError: String? = nil
    var wantsToFavorite = false

    // MARK: - Filter chips (Daylight Search: All / Protein-dense / My foods)

    var selectedFilter: SearchFilter = .all
    /// FatSecret ids (FoodItem.externalId) for foods the user has already favorited — lets
    /// Search sort favorites first and support the "My foods" filter without re-deriving it
    /// from FoodItem rows on every render.
    private(set) var favoritedExternalIds: Set<String> = []

    /// `results`, filtered by `selectedFilter` and sorted favorites-first. `Array.sorted` is
    /// stable (Swift 5+), so within each group the FatSecret ranking is preserved.
    var filteredResults: [FoodSearchResult] {
        results
            .filter { matchesSelectedFilter($0) }
            .sorted { favoritedExternalIds.contains($0.id) && !favoritedExternalIds.contains($1.id) }
    }

    private func matchesSelectedFilter(_ result: FoodSearchResult) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .proteinDense:
            guard let macros = FoodSearchMacros.parse(result.description) else { return false }
            return ProteinDensity.isProteinDense(calories: macros.calories, proteinG: macros.proteinG)
        case .myFoods:
            return favoritedExternalIds.contains(result.id)
        }
    }

    func loadFavoritedExternalIds() async {
        await FavoritesStore.shared.loadIfNeeded()
        let ids = FavoritesStore.shared.favoritedIds
        guard !ids.isEmpty else { favoritedExternalIds = []; return }
        struct Row: Decodable {
            let externalId: String?
            enum CodingKeys: String, CodingKey { case externalId = "external_id" }
        }
        do {
            let rows: [Row] = try await supabase
                .from("food_items")
                .select("external_id")
                .in("id", values: Array(ids))
                .eq("source", value: "fatsecret")
                .execute()
                .value
            favoritedExternalIds = Set(rows.compactMap(\.externalId))
        } catch {
            favoritedExternalIds = []
        }
    }

    // MARK: - Quick log ("+" — logs the first serving straight to the header meal)

    var quickLoggingID: String? = nil
    private(set) var quickLoggedIDs: Set<String> = []

    /// Tapping a result's name opens the full confirm sheet; tapping "+" logs it immediately
    /// at quantity 1, first serving, straight to whichever meal the header shows.
    func quickLog(_ result: FoodSearchResult, meal: Meal, on date: Date) async {
        quickLoggingID = result.id
        defer { quickLoggingID = nil }
        do {
            let detail = try await client.getFood(id: result.id)
            guard let serving = detail.servings.first else {
                errorMessage = "Couldn't log \(result.name). Try again."
                return
            }
            try await persistLog(detail: detail, serving: serving, quantity: 1, meal: meal, date: date, favorite: false)
            quickLoggedIDs.insert(result.id)
        } catch {
            errorMessage = "Couldn't log \(result.name). Try again."
        }
    }

    // Guards against a slow response for food A landing after the user has moved on to
    // food B. Both flows share this ViewModel's `detail`/`selectedServing`, so without
    // it the sheet could show B's title over A's macros — and log the food the user
    // never picked.
    private var detailRequestID = UUID()

    private let client = FatSecretClient()

    // Called from .task(id: searchQuery) in FoodSearchView.
    // The task auto-cancels when searchQuery changes, giving us debounce for free.
    func search() async {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            results = []
            canLoadMoreResults = false
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await client.search(query: q)
            searchPage = 0
            canLoadMoreResults = results.count == FatSecretClient.pageSize
        } catch {
            // The old comment claimed "the results list stays empty" — it didn't. On error
            // `results` kept the *previous* query's contents, so searching "banana" offline
            // right after "apple" showed apple results under the word banana, with no error.
            //
            // Cancellation lands here too: .task(id:) cancels the in-flight request on every
            // keystroke and that propagates through URLSession. Clearing on cancellation
            // would make the list flicker on every character typed.
            guard !Task.isCancelled else { return }
            results = []
            canLoadMoreResults = false
        }
    }

    // FatSecret's `page` parameter was plumbed all the way to the edge function and then
    // never used: search() only ever asked for page 0, capped at 25 results. A generic query
    // like "chicken" silently truncated and the food the user wanted could be unreachable.
    func loadMoreResults() async {
        guard canLoadMoreResults, !isLoadingMoreResults else { return }
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }

        isLoadingMoreResults = true
        defer { isLoadingMoreResults = false }

        let nextPage = searchPage + 1
        do {
            let more = try await client.search(query: q, page: nextPage)
            guard !Task.isCancelled else { return }
            searchPage = nextPage
            canLoadMoreResults = more.count == FatSecretClient.pageSize
            // The same food can surface on two pages; don't render it twice.
            let existingIds = Set(results.map(\.id))
            results.append(contentsOf: more.filter { !existingIds.contains($0.id) })
        } catch {
            guard !Task.isCancelled else { return }
            canLoadMoreResults = false
        }
    }

    func loadDetail(for result: FoodSearchResult) async {
        let requestID = UUID()
        detailRequestID = requestID

        selectedResult = result
        detail = nil
        selectedServing = nil
        wantsToFavorite = false
        detailError = nil
        // Reset per-food state. `quantity` persisted across foods: log 5 servings of
        // rice, open a different food, and its sheet was pre-filled at 5 servings —
        // logged as 5 by anyone who didn't happen to look at the stepper.
        quantity = 1.0
        isLoadingDetail = true
        // Only the newest request may clear the spinner — a stale one finishing later
        // would otherwise dismiss the loading state of the request still in flight.
        defer { if detailRequestID == requestID { isLoadingDetail = false } }

        do {
            let loaded = try await client.getFood(id: result.id)
            guard detailRequestID == requestID else { return }   // superseded; drop it
            detail = loaded
            selectedServing = loaded.servings.first
        } catch {
            guard detailRequestID == requestID else { return }
            // Shown inside the sheet. Stored in errorMessage, it went to the alert on the
            // view *presenting* the sheet, which SwiftUI can never show — so a failed load
            // rendered a permanently blank sheet.
            detailError = error.localizedDescription
        }
    }

    // Cancelling invalidates the in-flight request so its response can't land on top of
    // whatever the user does next.
    func cancelDetail() {
        detailRequestID = UUID()
        selectedResult = nil
        detail = nil
        selectedServing = nil
        detailError = nil
        isLoadingDetail = false
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

    // Shares `detail`/`selectedServing` with loadDetail (the Scan and Search tabs use one
    // ViewModel), so it takes a token too: a slow search-tab detail load must not land on
    // top of a barcode result, or vice versa.
    func lookupBarcode(_ barcode: String) async {
        let requestID = UUID()
        detailRequestID = requestID

        detail = nil
        selectedServing = nil
        detailError = nil
        quantity = 1.0
        isLoadingDetail = true

        do {
            let loaded = try await client.getFood(barcode: barcode)
            guard detailRequestID == requestID else { return }
            detail = loaded
            selectedServing = loaded.servings.first
            isLoadingDetail = false
            selectedResult = FoodSearchResult(id: loaded.id, name: loaded.name, brand: loaded.brand, description: "")
        } catch {
            guard detailRequestID == requestID else { return }
            isLoadingDetail = false
            // No sheet is up on this path (it only presents on success), so the scanner's
            // own alert can present this.
            errorMessage = "No food found for that barcode."
        }
    }

    func resetScanState() {
        detailRequestID = UUID()   // abandon any in-flight lookup
        selectedResult = nil
        detail = nil
        selectedServing = nil
        isLoadingDetail = false
        errorMessage = nil
        detailError = nil
        logError = nil
    }

    func logFood(on date: Date) async throws {
        guard let detail, let serving = selectedServing else { return }
        isLogging = true
        defer { isLogging = false }
        try await persistLog(detail: detail, serving: serving, quantity: quantity, meal: selectedMeal, date: date, favorite: wantsToFavorite)
        wantsToFavorite = false
    }

    // Shared by the full confirm-sheet log (logFood, above — any serving/quantity/meal, can
    // favorite) and the "+" quick log (first serving, quantity 1, never favorites in the same
    // tap). Kept as one path so both stay consistent about upserting the food_item and writing
    // local-first.
    private func persistLog(
        detail: FoodDetail,
        serving: FoodServing,
        quantity: Double,
        meal: Meal,
        date: Date,
        favorite: Bool
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        // Upsert the food_item so logging the same FatSecret food twice doesn't duplicate rows.
        // The conflict target must include user_id: the constraint is per-owner, because
        // RLS only lets a user UPDATE their own rows (a global key made the upsert collide
        // with another user's row and fail with a 42501).
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
            .upsert(newItem, onConflict: "user_id,source,external_id")
            .select()
            .single()
            .execute()
            .value

        // Write food_log locally — SyncEngine pushes to Supabase in the background
        try LocalStore.shared.insertFoodLog(
            id: UUID(),
            userId: userId,
            logDate: date.isoDateString,
            meal: meal.rawValue,
            foodItemId: item.id,
            foodItemName: detail.name,
            quantity: quantity,
            caloriesSnapshot: serving.calories,
            proteinGSnapshot: serving.proteinG,
            carbsGSnapshot: serving.carbsG,
            fatGSnapshot: serving.fatG,
            fiberGSnapshot: serving.fiberG
        )
        SyncEngine.shared.refreshPendingCount()
        Task { await SyncEngine.shared.pushPendingChanges() }

        if favorite {
            struct NewFav: Encodable {
                let userId: UUID; let foodItemId: UUID
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"; case foodItemId = "food_item_id"
                }
            }
            _ = try? await supabase
                .from("food_favorites")
                .insert(NewFav(userId: userId, foodItemId: item.id))
                .execute()
            FavoritesStore.shared.insertId(item.id)
        }
    }
}
