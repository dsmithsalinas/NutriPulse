import Foundation
import Supabase

// Proxies the delete-account Edge Function, which deletes the auth.users row
// via the Admin API — every owned table cascades from there. Deleting a user
// requires the service-role key, which never reaches the client; only the
// caller's JWT does.
struct AccountRepository {
    func deleteAccount(expectedUserId: UUID, appleAuthorizationCode: String?, manualAppleRevocation: Bool = false) async throws {
        struct Response: Decodable { let success: Bool; let appleRevocationRequired: Bool? }
        struct Payload: Encodable { let appleAuthorizationCode: String?; let manualAppleRevocation: Bool }
        let id = try await supabase.auth.session.user.id
        guard id == expectedUserId else { throw URLError(.userAuthenticationRequired) }
        let response: Response = try await supabase.functions.invoke("delete-account", options: .init(body: Payload(appleAuthorizationCode: appleAuthorizationCode, manualAppleRevocation: manualAppleRevocation)))
        guard response.success else { throw URLError(.badServerResponse) }
        if supabase.auth.currentSession?.user.id == id {
            UserDefaults.standard.set(response.appleRevocationRequired == true, forKey: "appleDisconnectHelpNeeded")
        }
        // Attempt every cleanup even if one file is unavailable. Never sign out a different
        // account that became active while the deletion request was in flight.
        var cleanupError: Error?
        do { try await EverydayToolsStore.shared.purgeAccount(id) } catch { cleanupError = error }
        do { try await MealNoteStore.shared.purgeAccount(id) } catch { cleanupError = error }
        do { try await UsualMealStore.shared.purgeAccount(id) } catch { cleanupError = error }
        UserDefaults.standard.removeObject(forKey: LogMethodPreference.key(id))
        await PulseProfileStore.shared.purgeAccount(id)
        if supabase.auth.currentSession?.user.id == id { try? await supabase.auth.signOut(scope: .local) }
        if let cleanupError { throw cleanupError }
    }
}
