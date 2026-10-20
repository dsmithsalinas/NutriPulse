import Foundation
import Supabase

@MainActor
struct RemoteMealNoteRepository: MealNoteTransport {
    func fetch(for date: Date) async throws -> [MealNote] {
        let id = try await supabase.auth.session.user.id
        let notes: [MealNote] = try await supabase.from("meal_notes").select()
            .eq("user_id", value: id).eq("log_date", value: date.isoDateString)
            .order("created_at").execute().value
        guard (try? await supabase.auth.session.user.id) == id else { throw URLError(.userAuthenticationRequired) }
        return notes
    }
    func save(_ note: MealNote) async throws {
        guard MealNote.validBody(note.body) != nil,
              try await supabase.auth.session.user.id == note.userId else { throw URLError(.badServerResponse) }
        try await supabase.from("meal_notes").upsert(note, onConflict: "id").execute()
        guard (try? await supabase.auth.session.user.id) == note.userId else { throw URLError(.userAuthenticationRequired) }

    }
    func delete(_ note: MealNote) async throws {
        guard try await supabase.auth.session.user.id == note.userId else { throw URLError(.userAuthenticationRequired) }
        try await supabase.from("meal_notes").delete().eq("id", value: note.id).eq("user_id", value: note.userId).execute()

    }
}
/// Public writes commit on-device first. Network retry belongs to the durable outbox.
@MainActor
struct MealNoteRepository {
    private func store() throws -> MealNoteStore {
        guard let id = supabase.auth.currentSession?.user.id else { throw URLError(.userAuthenticationRequired) }
        let store = MealNoteStore.shared
        store.setAccount(id)
        return store
    }
    func fetch(for date: Date) async throws -> [MealNote] {
        let store = try store()
        if !SyncEngine.shared.isOnline { return try store.cachedOnly(for: date) }
        return try await store.fetch(for: date)
    }
    func save(_ note: MealNote) async throws {
        let store = try store(); try store.save(note)
        SyncEngine.shared.refreshPendingCount()
        Task { await SyncEngine.shared.pushPendingChanges() }
    }
    func delete(_ note: MealNote) async throws {
        let store = try store(); try store.delete(note)
        SyncEngine.shared.refreshPendingCount()
        Task { await SyncEngine.shared.pushPendingChanges() }
    }
}
extension Notification.Name { static let mealNotesChanged = Notification.Name("mealNotesChanged") }
