import Foundation
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

    // A prompt handed off from another surface (the Today under-eating nudge) for the Pulse
    // coach to pick up. MainTabView switches to the Pulse tab when it's set; CoachView sends
    // it and clears it. Keeps the deep-link one-directional and stateless.
    var pendingCoachPrompt: String? = nil

    func askPulse(_ prompt: String) {
        pendingCoachPrompt = prompt
    }

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
        for await (event, session) in supabase.auth.authStateChanges {
            self.session = session

            // Match on the event rather than `session == nil`: the stream also emits a
            // nil-session .initialSession on a signed-out cold launch, and wiping there
            // would be pointless work. .signedOut is the single funnel for both the
            // Sign Out button and account deletion (which signs out after deleting).
            if event == .signedOut {
                handleSignedOut()
            } else if session != nil {
                await fetchProfile()
            } else {
                profile = nil
                profileLoadFailed = false
            }

            self.isLoading = false
        }
    }

    // Everything account-scoped that outlives a session has to die here. The local
    // SwiftData cache, the favorites singleton, and the account-scoped UserDefaults
    // keys all persisted across sign-out, so the next user on this device inherited
    // the previous user's goals, favorites, and HealthKit sync state — and "Delete
    // Account" left their food history sitting on disk.
    private func handleSignedOut() {
        profile = nil
        profileLoadFailed = false

        try? LocalStore.shared.wipeAll()
        FavoritesStore.shared.reset()

        for key in Self.accountScopedDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // Display preferences (unitSystem, waterUnit) are deliberately excluded — those
    // are device preferences, not account data.
    private static let accountScopedDefaultsKeys = [
        "lastHKWeightSyncDate",
        "chatHistoryVersion",
        AuthViewModel.pendingAppleFullNameKey,
    ]

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
