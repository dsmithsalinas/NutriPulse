import Foundation
import Observation
import SwiftUI
import Supabase

/// Explicitly scoped to a user's save task, including its child tasks. Remote pulls never
/// produce receipts. Undo removes exactly these new log IDs, never a source food or favorite.
@Observable @MainActor
final class FoodSaveUndo {
    @TaskLocal static var current: FoodSaveUndo?
    private(set) var foodIDs: [UUID: UUID] = [:]
    private(set) var note: MealNote?
    var isUndoing = false
    var error: String?
    var canUndo: Bool { !foodIDs.isEmpty || note != nil }
    var savedFoods: [FoodLog] {
        guard let owner = foodIDs.values.first else { return [] }
        return ((try? LocalStore.shared.fetchFoodLogs(since: .distantPast, userId: owner)) ?? [])
            .filter { foodIDs[$0.id] == owner }
    }
    func record(id: UUID, userId: UUID) { foodIDs[id] = userId }
    func record(note: MealNote) { reset(); self.note = note }
    func reset() { foodIDs = [:]; note = nil; error = nil }
    func undo() async -> Bool {
        guard canUndo, !isUndoing else { return false }
        isUndoing = true; error = nil
        defer { isUndoing = false }
        do {
            guard let owner = supabase.auth.currentSession?.user.id,
                  foodIDs.values.allSatisfy({ $0 == owner }), note.map({ $0.userId == owner }) != false else {
                throw URLError(.userAuthenticationRequired)
            }
            if let note { try await MealNoteRepository().delete(note) }
            if !foodIDs.isEmpty { try LocalStore.shared.markFoodLogsDeleted(ids: Set(foodIDs.keys), userId: owner) }
            reset()
            SyncEngine.shared.refreshPendingCount()
            Task { await SyncEngine.shared.pushPendingChanges() }
            NotificationCenter.default.post(name: .foodSaveUndone, object: nil)
            return true
        } catch { self.error = "Couldn’t undo. Your saved entry is still here; try again."; return false }
    }
}
private struct FoodSaveUndoKey: EnvironmentKey { static let defaultValue: FoodSaveUndo? = nil }
extension EnvironmentValues {
    var foodSaveUndo: FoodSaveUndo? {
        get { self[FoodSaveUndoKey.self] }
        set { self[FoodSaveUndoKey.self] = newValue }
    }
}
extension Notification.Name { static let foodSaveUndone = Notification.Name("foodSaveUndone") }
