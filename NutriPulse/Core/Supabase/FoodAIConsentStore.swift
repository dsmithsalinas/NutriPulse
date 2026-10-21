import Foundation
import Observation
import Supabase

struct FoodAIConsent: Decodable {
    let userId: UUID
    let agreedAt: Date?
    enum CodingKeys: String, CodingKey { case userId = "user_id", agreedAt = "food_ai_consent_at" }
}

@MainActor
protocol FoodAIConsentRepositoryProtocol {
    func fetch(userId: UUID) async throws -> FoodAIConsent?
    func save(userId: UUID, agreed: Bool) async throws -> FoodAIConsent
}

struct FoodAIConsentRepository: FoodAIConsentRepositoryProtocol {
    func fetch(userId: UUID) async throws -> FoodAIConsent? {
        let rows: [FoodAIConsent] = try await supabase.from("pulse_profiles")
            .select("user_id,food_ai_consent_at").eq("user_id", value: userId).limit(1).execute().value
        return rows.first
    }
    func save(userId: UUID, agreed: Bool) async throws -> FoodAIConsent {
        guard supabase.auth.currentSession?.user.id == userId else { throw URLError(.userAuthenticationRequired) }
        let fields: [String: AnyJSON] = ["user_id": .string(userId.uuidString),
            "food_ai_consent_at": agreed ? .string(Date.now.ISO8601Format()) : .null]
        return try await supabase.from("pulse_profiles").upsert(fields, onConflict: "user_id")
            .select("user_id,food_ai_consent_at").single().execute().value
    }
}

// No cached grant: a new account/session must load its own server decision.
@Observable @MainActor
final class FoodAIConsentStore {
    static let shared = FoodAIConsentStore()
    private(set) var accountId: UUID?
    private(set) var agreedAt: Date?
    private(set) var isLoaded = false
    private(set) var loadFailed = false
    private var generation = UUID()
    private let repository: any FoodAIConsentRepositoryProtocol
    private let currentUser: () -> UUID?

    var isAllowed: Bool { isLoaded && !loadFailed && agreedAt != nil && accountId != nil && currentUser() == accountId }

    init(repository: (any FoodAIConsentRepositoryProtocol)? = nil,
         currentUser: @escaping () -> UUID? = { supabase.auth.currentSession?.user.id }) {
        self.repository = repository ?? FoodAIConsentRepository(); self.currentUser = currentUser
    }

    func setAccount(_ id: UUID?) {
        guard accountId != id else { return }
        accountId = id; generation = UUID(); agreedAt = nil; isLoaded = false; loadFailed = false
    }

    func load() async {
        setAccount(currentUser())
        guard let id = accountId else { return }
        let request = generation
        do {
            let row = try await repository.fetch(userId: id)
            try validate(id, request, row: row)
            agreedAt = row?.agreedAt; isLoaded = true; loadFailed = false
        } catch {
            guard accountId == id, generation == request else { return }
            agreedAt = nil; isLoaded = false; loadFailed = true
        }
    }

    func record(agreed: Bool, for expectedOwner: UUID) async throws {
        let request = generation
        try validate(expectedOwner, request)
        // Revoke locally immediately; a failed server save never silently restores a grant.
        agreedAt = nil; isLoaded = false
        do {
            let row = try await repository.save(userId: expectedOwner, agreed: agreed)
            try validate(expectedOwner, request, row: row)
            guard (row.agreedAt != nil) == agreed else { throw URLError(.badServerResponse) }
            agreedAt = row.agreedAt; isLoaded = true; loadFailed = false
        } catch {
            if accountId == expectedOwner, generation == request { loadFailed = true }
            throw error
        }
    }

    private func validate(_ id: UUID, _ request: UUID, row: FoodAIConsent? = nil) throws {
        guard accountId == id, currentUser() == id, generation == request,
              row == nil || row?.userId == id else { throw URLError(.userAuthenticationRequired) }
    }
}
