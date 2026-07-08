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
    // A failed fetch is NOT the same as "this user has no profile yet". Conflating
    // the two sent every authenticated user with a flaky connection back through
    // onboarding — where re-running the save duplicated their starting weight.
    var profileLoadFailed = false

    var isAuthenticated: Bool { session != nil }

    // Onboarding is needed when we know the profile row exists (or genuinely doesn't
    // yet) and fullName hasn't been saved. The database trigger creates the row
    // (with just id+email) the moment the user signs up.
    var needsOnboarding: Bool {
        isAuthenticated && !profileLoadFailed && profile?.fullName == nil
    }

    // Subscribes to Supabase auth state changes as an AsyncStream.
    // Called from RootView.task{} so it runs for the lifetime of the root view.
    // Profile is fetched before isLoading clears so RootView never flashes the wrong screen.
    func startObservingAuth() async {
        for await (_, session) in supabase.auth.authStateChanges {
            self.session = session
            if session != nil {
                await fetchProfile()
            } else {
                profile = nil
                profileLoadFailed = false
            }
            self.isLoading = false
        }
    }

    // Selects into an array rather than .single() on purpose: .single() throws when
    // the row is absent, which is indistinguishable from a network failure. An empty
    // array means "no profile row yet" (the sign-up trigger hasn't fired) → onboarding.
    // A thrown error means "we don't know" → retry screen, never onboarding.
    func fetchProfile() async {
        guard let userId = session?.user.id else { return }
        do {
            let rows: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            profile = rows.first
            profileLoadFailed = false
        } catch {
            profile = nil
            profileLoadFailed = true
        }
    }

    // Set directly from onboarding's save response so completing onboarding doesn't
    // depend on a second network round trip that can fail and strand the user.
    func setProfile(_ profile: UserProfile) {
        self.profile = profile
        self.profileLoadFailed = false
    }
}
