import Foundation
import Observation
import Supabase

@MainActor
protocol PulseAttentionRepositoryProtocol {
    func fetch(userId: UUID) async throws -> PulseAttentionPreference?
    func save(_ preference: PulseAttentionPreference) async throws
    func reserve(day: String, token: UUID) async throws -> Bool
}
@MainActor
struct PulseAttentionRepository: PulseAttentionRepositoryProtocol {
    func fetch(userId: UUID) async throws -> PulseAttentionPreference? {
        let rows: [PulseAttentionPreference] = try await supabase.from("pulse_attention_preferences")
            .select().eq("user_id", value: userId).limit(1).execute().value
        return rows.first
    }
    func save(_ preference: PulseAttentionPreference) async throws {
        guard supabase.auth.currentSession?.user.id == preference.userId else { throw URLError(.userAuthenticationRequired) }
        try await supabase.from("pulse_attention_preferences").upsert(preference, onConflict: "user_id").execute()
    }
    func reserve(day: String, token: UUID) async throws -> Bool {
        try await supabase.rpc("reserve_pulse_attention", params: ["p_day": day, "p_token": token.uuidString]).execute().value
    }
}

@Observable @MainActor
final class PulseAttentionStore {
    static let shared = PulseAttentionStore()
    private(set) var accountId: UUID?
    private(set) var limit: PulseAttentionLimit = .quiet
    private(set) var isLoaded = false
    private(set) var loadFailed = false
    private(set) var isSaving = false
    private var generation = UUID()
    private let repository: any PulseAttentionRepositoryProtocol
    init(repository: (any PulseAttentionRepositoryProtocol)? = nil) { self.repository = repository ?? PulseAttentionRepository() }
    var allowsProactive: Bool { accountId != nil && isLoaded && !loadFailed && limit == .one && !isSaving }
    func setAccount(_ id: UUID?) {
        guard accountId != id else { return }
        generation = UUID(); accountId = id; limit = .quiet; isLoaded = false; loadFailed = false; isSaving = false
        changed()
    }
    #if DEBUG
    func preview() { accountId = AppStoreScreenshotPreview.sampleUser; limit = .one; isLoaded = true; loadFailed = false }
    #endif
    func load() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--pulse-week-preview") { return }
        #endif
        guard let id = accountId else { return }
        let request = generation
        do {
            let row = try await repository.fetch(userId: id)
            guard request == generation, id == accountId, !isSaving else { return }
            guard row == nil || row?.userId == id else { throw URLError(.badServerResponse) }
            limit = row?.limit ?? .one; isLoaded = true; loadFailed = false
        } catch {
            guard request == generation else { return }
            loadFailed = true
        }
        changed()
    }
    func setLimit(_ value: PulseAttentionLimit) async throws {
        guard let id = accountId, !isSaving else { throw URLError(.userAuthenticationRequired) }
        let request = UUID(); generation = request; isSaving = true
        changed() // Pause pending notifications while saving; failure never increases pressure.
        defer { if generation == request { isSaving = false; changed() } }
        do { try await repository.save(.init(userId: id, limit: value)) }
        catch { if request == generation { loadFailed = true }; throw error }
        guard request == generation, id == accountId else { throw URLError(.userAuthenticationRequired) }
        limit = value; isLoaded = true; loadFailed = false
    }
    func reserve(on date: Date, token: UUID) async -> Bool {
        guard allowsProactive, let id = accountId else { return false }
        let request = generation
        let accepted = (try? await repository.reserve(day: date.isoDateString, token: token)) == true
        return accepted && request == generation && id == accountId && allowsProactive
    }
    private func changed() { NotificationCenter.default.post(name: .pulseAttentionChanged, object: nil) }
}
extension Notification.Name {
    static let pulseAttentionChanged = Notification.Name("pulseAttentionChanged")
}
