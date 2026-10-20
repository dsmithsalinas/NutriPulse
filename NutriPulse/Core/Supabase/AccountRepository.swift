import Foundation
import Foundation
import Supabase

// Proxies the delete-account Edge Function, which deletes the auth.users row
// via the Admin API — every owned table cascades from there. Deleting a user
// requires the service-role key, which never reaches the client; only the
// caller's JWT does.
struct AccountRepository {
    func deleteAccount() async throws {
        struct Response: Decodable { let success: Bool }
        let id = try await supabase.auth.session.user.id
        let _: Response = try await supabase.functions.invoke("delete-account")
        try await EverydayToolsStore.shared.purgeAccount(id)
        try await MealNoteStore.shared.purgeAccount(id)
        try await UsualMealStore.shared.purgeAccount(id)
        UserDefaults.standard.removeObject(forKey: LogMethodPreference.key(id))
    }
}
