import Foundation
import Supabase

// Proxies the delete-account Edge Function, which deletes the auth.users row
// via the Admin API — every owned table cascades from there. Deleting a user
// requires the service-role key, which never reaches the client; only the
// caller's JWT does.
struct AccountRepository {
    func deleteAccount() async throws {
        struct Response: Decodable { let success: Bool }
        let _: Response = try await supabase.functions.invoke("delete-account")
    }
}
