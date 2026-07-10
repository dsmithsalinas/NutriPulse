import Observation
import Foundation
import Supabase

@Observable
@MainActor
final class TalkToLogViewModel {
    // One editable confirm-card row. Macro fields are per-serving (quantity = 1),
    // same snapshot + quantity split FoodLog uses — see totalCalories etc. below.
    struct ConfirmRow: Identifiable {
        let id = UUID()
        var isIncluded = true
        // Set once this row has landed in the local store. A partial failure used to leave
        // every row included, so tapping "Log 3 items" again re-saved the ones that had
        // already succeeded — with fresh UUIDs, so nothing deduped them.
        var isSaved = false
        var name: String
        var brand: String?
        var servingDesc: String
        var grams: Double
        var quantity: Double
        var calories: Double
        var proteinG: Double
        var carbsG: Double
        var fatG: Double
        var fiberG: Double
        var source: String       // "fatsecret" | "estimated" — drives the confirm-card badge
        var externalId: String?
        let initialQuantity: Double   // snapshot at parse time, to detect edits

        var totalCalories: Double { calories * quantity }
        var totalProteinG: Double { proteinG * quantity }
        var totalCarbsG: Double { carbsG * quantity }
        var totalFatG: Double { fatG * quantity }
        var totalFiberG: Double { fiberG * quantity }

        // The confirm-card trust proxy (Phase 1C): did the user have to correct
        // this row, or was Claude/FatSecret's parse good enough to accept as-is?
        var wasEdited: Bool { !isIncluded || quantity != initialQuantity }
    }

    var inputText = ""
    var isParsing = false
    var rows: [ConfirmRow] = []
    var selectedMeal: Meal = .current
    var isLogging = false
    var errorMessage: String? = nil

    private let client = TalkToLogClient()

    var hasParsed: Bool { !rows.isEmpty }
    var includedCount: Int { rows.filter(\.isIncluded).count }

    // What a tap on "Log" would actually write — excludes rows already saved by a
    // previous, partially-failed attempt.
    var pendingRows: [ConfirmRow] { rows.filter { $0.isIncluded && !$0.isSaved } }
    var pendingCount: Int { pendingRows.count }

    // Called from a "Parse" button — one Edge Function call runs Claude's full
    // decompose → search → resolve loop server-side and returns the finished rows.
    func parse() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isParsing = true
        errorMessage = nil
        defer { isParsing = false }

        do {
            let items = try await client.parse(text: text)
            rows = items.map {
                ConfirmRow(
                    name: $0.name, brand: $0.brand, servingDesc: $0.servingDesc,
                    grams: $0.grams, quantity: $0.quantity,
                    calories: $0.calories, proteinG: $0.proteinG, carbsG: $0.carbsG,
                    fatG: $0.fatG, fiberG: $0.fiberG,
                    source: $0.source, externalId: $0.externalId,
                    initialQuantity: $0.quantity
                )
            }
            if rows.isEmpty {
                errorMessage = "Couldn't find anything to log in that — try rephrasing."
            }
        } catch {
            // Show the server's reason when present (e.g. the 429 rate-limit copy); otherwise
            // the generic parse-failure message.
            errorMessage = EdgeFunctionError.message(
                from: error,
                fallback: "Couldn't parse that meal. Try again, or add it manually."
            )
        }
    }

    func reset() {
        inputText = ""
        rows = []
        errorMessage = nil
    }

    // Confirmed rows only — unchecked rows are dropped, never silently logged.
    // Rows save concurrently (each is an independent food_items round-trip
    // followed by a local write) instead of one at a time — a 5-component
    // bowl no longer pays for 5 sequential network round-trips end to end.
    //
    // Each row reports its own outcome rather than the group throwing on the first
    // failure. With a throwing group, one failed insert aborted logAll, the view showed
    // "Couldn't save that log. Try again.", and the confirm card kept every row included —
    // so the retry re-saved the rows that had already succeeded, under new UUIDs. Parse
    // "chicken, rice, and beans", let one insert fail, tap Log twice, and two of the three
    // foods are in the day twice.
    func logAll(on date: Date) async throws {
        let pending = pendingRows
        guard !pending.isEmpty else { return }
        isLogging = true
        defer { isLogging = false }

        let userId = try await supabase.auth.session.user.id
        let meal = selectedMeal

        var savedRowIds: Set<UUID> = []
        var firstError: Error? = nil

        await withTaskGroup(of: (UUID, Error?).self) { group in
            for row in pending {
                group.addTask {
                    do {
                        try await self.saveRow(row, userId: userId, meal: meal, date: date)
                        return (row.id, nil)
                    } catch {
                        return (row.id, error)
                    }
                }
            }
            for await (rowId, error) in group {
                if let error {
                    firstError = firstError ?? error
                } else {
                    savedRowIds.insert(rowId)
                }
            }
        }

        for index in rows.indices where savedRowIds.contains(rows[index].id) {
            rows[index].isSaved = true
        }

        if !savedRowIds.isEmpty {
            SyncEngine.shared.refreshPendingCount()
            Task { await SyncEngine.shared.pushPendingChanges() }
        }

        // Surface the failure only after the successful rows are marked, so a retry picks
        // up exactly the ones that didn't land.
        if let firstError { throw firstError }
    }

    private func saveRow(_ row: ConfirmRow, userId: UUID, meal: Meal, date: Date) async throws {
        let newItem = NewFoodItem(
            userId: userId,
            // The DB only allows 'fatsecret' | 'manual' — Claude's ungrounded
            // estimate is functionally a manual entry, just AI-authored.
            source: row.source == "fatsecret" ? "fatsecret" : "manual",
            externalId: row.externalId,
            name: row.name,
            brand: row.brand,
            servingDesc: row.servingDesc,
            servingGrams: row.grams,
            calories: row.calories,
            proteinG: row.proteinG,
            carbsG: row.carbsG,
            fatG: row.fatG,
            fiberG: row.fiberG
        )

        let item: FoodItem = if row.source == "fatsecret" {
            try await supabase
                .from("food_items")
                .upsert(newItem, onConflict: "user_id,source,external_id")
                .select()
                .single()
                .execute()
                .value
        } else {
            try await supabase
                .from("food_items")
                .insert(newItem)
                .select()
                .single()
                .execute()
                .value
        }

        try LocalStore.shared.insertFoodLog(
            id: UUID(),
            userId: userId,
            logDate: date.isoDateString,
            meal: meal.rawValue,
            foodItemId: item.id,
            foodItemName: row.name,
            quantity: row.quantity,
            caloriesSnapshot: row.calories,
            proteinGSnapshot: row.proteinG,
            carbsGSnapshot: row.carbsG,
            fatGSnapshot: row.fatG,
            fiberGSnapshot: row.fiberG
        )
    }
}
