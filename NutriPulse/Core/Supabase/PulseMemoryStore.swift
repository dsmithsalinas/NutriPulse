import Foundation
import Observation
import Supabase

@MainActor
protocol PulseMemoryRepositoryProtocol {
    func fetch(userId: UUID) async throws -> [PulseMemory]
    func save(_ memory: PulseMemory) async throws
    func delete(_ memory: PulseMemory) async throws
}

@MainActor
struct PulseMemoryRepository: PulseMemoryRepositoryProtocol {
    func fetch(userId: UUID) async throws -> [PulseMemory] {
        try await supabase.from("pulse_memories").select().eq("user_id", value: userId)
            .order("approved_at", ascending: false).execute().value
    }
    func save(_ memory: PulseMemory) async throws {
        guard supabase.auth.currentSession?.user.id == memory.userId else { throw URLError(.userAuthenticationRequired) }
        try await supabase.from("pulse_memories").upsert(memory, onConflict: "id").execute()
    }
    func delete(_ memory: PulseMemory) async throws {
        guard supabase.auth.currentSession?.user.id == memory.userId else { throw URLError(.userAuthenticationRequired) }
        try await supabase.from("pulse_memories").delete().eq("id", value: memory.id).eq("user_id", value: memory.userId).execute()
    }
}

/// No disk cache or offline queue of sensitive coaching memories. Clear immediately on an
/// account change; a generation fence rejects responses from the previous account/session.
@Observable @MainActor
final class PulseMemoryStore {
    static let shared = PulseMemoryStore()
    private(set) var accountId: UUID?
    private(set) var memories: [PulseMemory] = []
    private(set) var isLoaded = false
    private(set) var loadFailed = false
    private(set) var isSaving = false
    private var generation = UUID()
    private let repository: any PulseMemoryRepositoryProtocol
    init(repository: (any PulseMemoryRepositoryProtocol)? = nil) { self.repository = repository ?? PulseMemoryRepository() }
    func setAccount(_ id: UUID?) {
        guard id != accountId else { return }
        generation = UUID(); accountId = id; memories = []; isLoaded = false; loadFailed = false; isSaving = false
    }
    #if DEBUG
    func preview() {
        accountId = AppStoreScreenshotPreview.sampleUser
        memories = [.init(userId: accountId!, content: "When traveling, a familiar breakfast makes mornings easier.")]
        isLoaded = true; loadFailed = false
    }
    #endif
    func load() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--pulse-week-preview") || ProcessInfo.processInfo.arguments.contains("--everyday-tools-preview") { return }
        #endif
        guard let id = accountId else { return }
        let request = generation
        do {
            let rows = try await repository.fetch(userId: id)
            guard generation == request, accountId == id, !isSaving else { return }
            memories = rows.filter { $0.userId == id && $0.isValid }; isLoaded = true; loadFailed = false
        } catch {
            guard generation == request, accountId == id else { return }
            // Never expose a previous successful snapshot as current after a failed refresh.
            memories = []; loadFailed = true
        }
    }
    func approve(_ content: String, for expectedOwner: UUID) async throws {
        guard let id = accountId, id == expectedOwner else { throw URLError(.userAuthenticationRequired) }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !memories.contains(where: { $0.content.caseInsensitiveCompare(text) == .orderedSame }) else { return }
        try await save(PulseMemory(userId: id, content: text))
    }
    func save(_ memory: PulseMemory) async throws {
        guard memories.count < 30 || memories.contains(where: { $0.id == memory.id }) else { throw SaveError.capacity }
        guard memory.isValid, memory.userId == accountId, !isSaving else { throw URLError(.badServerResponse) }
        let request = UUID(); generation = request; isSaving = true
        defer { if generation == request { isSaving = false } }
        try await repository.save(memory)
        guard generation == request, accountId == memory.userId else { throw URLError(.userAuthenticationRequired) }
        memories.removeAll { $0.id == memory.id }; memories.insert(memory, at: 0); loadFailed = false; isLoaded = true
    }
    enum SaveError: Error { case capacity }
    func forget(_ memory: PulseMemory) async throws {
        guard memory.userId == accountId, !isSaving else { throw URLError(.userAuthenticationRequired) }
        let request = UUID(); generation = request; isSaving = true
        defer { if generation == request { isSaving = false } }
        try await repository.delete(memory)
        guard generation == request, accountId == memory.userId else { throw URLError(.userAuthenticationRequired) }
        memories.removeAll { $0.id == memory.id }
    }
}
