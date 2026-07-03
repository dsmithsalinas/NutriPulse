import Observation
import Supabase

// SWIFT CONCEPT — @Observable (iOS 17, Observation framework) is the modern replacement
// for ObservableObject + @Published. Any view that reads a property automatically
// re-renders when that property changes — no manual @Published annotations needed.
//
// @MainActor pins all methods and property mutations to the main thread, which is
// required for UI updates. Think of it as "every method runs in the main queue dispatch."

@Observable
@MainActor
final class AppState {
    var session: Session? = nil
    var profile: UserProfile? = nil
    var isLoading = true

    var isAuthenticated: Bool { session != nil }
    // Onboarding is needed when the profile row exists but fullName hasn't been saved yet.
    // The database trigger creates the row (with just id+email) the moment the user signs up.
    var needsOnboarding: Bool { isAuthenticated && profile?.fullName == nil }

    // Subscribes to Supabase auth state changes as an AsyncStream.
    // Called from RootView.task{} so it runs for the lifetime of the root view.
    // Profile is fetched before isLoading clears so RootView never flashes the wrong screen.
    func startObservingAuth() async {
        for await (_, session) in supabase.auth.authStateChanges {
            self.session = session
            if session != nil { await fetchProfile() } else { profile = nil }
            self.isLoading = false
        }
    }

    func fetchProfile() async {
        guard let userId = session?.user.id else { return }
        do {
            profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
        } catch {
            // Non-fatal: trigger may not have fired yet on first sign-up.
            // RootView will show onboarding if profile remains nil.
        }
    }
}
