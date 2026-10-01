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
    var isPasswordRecoveryFlow = false

    var isAuthenticated: Bool { session != nil }

    // A prompt handed off from another surface (the Today under-eating nudge) for the Pulse
    // coach to pick up. MainTabView switches to the Pulse tab when it's set; CoachView sends
    // it and clears it. Keeps the deep-link one-directional and stateless.
    //
    // Backed by a private stored property so every write — whether through `askPulse` or a
    // direct assignment (GoalsView sets this straight from a goal question) — passes through
    // `PulseGate`. Nothing should reach the AI provider while Pulse is off or unconsented.
    private var _pendingCoachPrompt: String? = nil
    var pendingCoachPrompt: String? {
        get { _pendingCoachPrompt }
        set { setPendingCoachPrompt(newValue) }
    }
    // The prompt captured while the consent sheet is up, so agreeing fires the original
    // hand-off instead of silently dropping it.
    var pendingConsentPrompt: String? = nil
    // MainTabView presents PulseConsentSheet on this — set whenever a hand-off needs consent,
    // or the user opens the Pulse tab before ever answering.
    var showPulseConsentSheet = false

    var pendingQuickAction: FootingQuickAction? = nil
    var pendingStrongWeekReminder = false
    var pendingSmartNotificationRoute: SmartNotificationRoute? = nil
    // GoalsView's protein floor card links to Profile's daily targets (Android: GoalsNav.openProfile
    // / ProfileModel.focusTargets). MainTabView switches to the Profile tab on this and consumes it
    // right away, same shape as the other pending hand-offs above.
    var pendingProfileDailyTargetsFocus = false

    func askPulse(_ prompt: String) {
        pendingCoachPrompt = prompt
    }

    private func setPendingCoachPrompt(_ prompt: String?) {
        // Clearing always goes straight through — CoachView clears this the instant it
        // consumes a prompt, and that must never get rerouted into the consent flow.
        guard let prompt else { _pendingCoachPrompt = nil; return }
        let store = PulseProfileStore.shared
        switch PulseGate.handoff(pulseEnabled: store.pulseEnabled, aiConsentAt: store.aiConsentAt) {
        case .allowed:
            _pendingCoachPrompt = prompt
        case .needsConsent:
            pendingConsentPrompt = prompt
            showPulseConsentSheet = true
        case .blocked:
            break
        }
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
            NotificationManager.shared.setWeeklyReminderAccount(session?.user.id)

            if event == .passwordRecovery {
                isPasswordRecoveryFlow = true
            }

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
            if session != nil { await NotificationManager.shared.reconcileWeeklyReminder() }
            // The foreground sync skips while signed out (or before the keychain restores the
            // session), so run it as soon as there's an account to sync.
            if session != nil, event == .signedIn || event == .initialSession {
                Task { await SyncEngine.shared.syncNow() }
            }
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
        isPasswordRecoveryFlow = false

        try? LocalStore.shared.wipeAll()
        FavoritesStore.shared.reset()
        SyncEngine.shared.clearFailure()
        GLP1TrackingStore.shared.reset()

        for key in Self.accountScopedDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        NotificationManager.shared.setWeeklyReminderAccount(nil)
        pendingStrongWeekReminder = false
        UserDefaults.standard.removeObject(forKey: StrongWeekReminder.routeKey)
        NotificationManager.shared.cancelSmartNotifications()
        SmartNotificationHistoryStore.clear()
    }

    // Display preferences (unitSystem) are deliberately excluded — a device preference,
    // not account data.
    private static let accountScopedDefaultsKeys = [
        "lastHKWeightSyncDate",
        "chatHistoryVersion",
        "glp1PlannedDoseMg",
        "doseCardDismissedDay",
        NotificationManager.smartCoachingEnabledKey,
        NotificationManager.smartSuppressedDayKey,
        SmartNotificationPreferences.workoutKey,
        SmartNotificationPreferences.proteinKey,
        SmartNotificationPreferences.appetiteKey,
        SmartNotificationPreferences.mealKey,
        SmartNotificationPreferences.quietStartKey,
        SmartNotificationPreferences.quietEndKey,
        LowAppetitePreparationStore.completedKey,
        ShotCycleCheckInSchedule.dismissedDayKey,
        AuthViewModel.pendingAppleFullNameKey,
    ]

    // Signup always creates a profile row in the database trigger. Therefore an
    // authenticated user seeing zero rows is not a new-user signal: it means the JWT
    // was not attached/refreshed yet, or access failed. Retry once, then fail closed
    // into the retry screen. The session delivered by authStateChanges is authoritative:
    // re-reading Auth's persisted session inside that callback races the SDK's storage
    // update and can throw before the first profile request is even made.
    func fetchProfile() async {
        guard let userId = session?.user.id else { return }
        do {
            for attempt in 0..<2 {
                let rows: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: userId)
                    .limit(1)
                    .execute()
                    .value
                if let loaded = rows.first {
                    profile = loaded
                    profileLoadFailed = false
                    GLP1TrackingStore.shared.apply(profile: loaded)
                    return
                }
                if attempt == 0 { try await Task.sleep(for: .milliseconds(300)) }
            }
            throw ProfileAccessError.profileNotVisible
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

    func finishPasswordRecovery() {
        isPasswordRecoveryFlow = false
    }
}

private enum ProfileAccessError: Error {
    case profileNotVisible
}
