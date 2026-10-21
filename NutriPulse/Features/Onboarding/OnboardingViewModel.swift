import Observation
import Foundation
import Supabase

// ─── Supporting enums ────────────────────────────────────────────────────────

enum BiologicalSex: String, CaseIterable, Identifiable {
    case male   = "male"
    case female = "female"
    case other  = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male:   return "Male"
        case .female: return "Female"
        case .other:  return "Non-binary / Other"
        }
    }

    // Same glyph for every option — the label carries the meaning, the icon is decorative.
    var icon: String { "person.fill" }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary  = "sedentary"
    case light      = "light"
    case moderate   = "moderate"
    case active     = "active"
    case veryActive = "very_active"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary:  return "Sedentary"
        case .light:      return "Lightly Active"
        case .moderate:   return "Moderately Active"
        case .active:     return "Active"
        case .veryActive: return "Very Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary:  return "Desk job, little or no exercise"
        case .light:      return "Light exercise 1–3 days/week"
        case .moderate:   return "Moderate exercise 3–5 days/week"
        case .active:     return "Hard exercise 6–7 days/week"
        case .veryActive: return "Twice daily training or physical job"
        }
    }

    // Harris-Benedict / Mifflin activity multipliers
    var multiplier: Double {
        switch self {
        case .sedentary:  return 1.2
        case .light:      return 1.375
        case .moderate:   return 1.55
        case .active:     return 1.725
        case .veryActive: return 1.9
        }
    }
}

enum WeightGoal: String, CaseIterable, Identifiable {
    case lose     = "lose"
    case maintain = "maintain"
    case gain     = "gain"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lose:     return "Lose Weight"
        case .maintain: return "Maintain Weight"
        case .gain:     return "Gain Weight"
        }
    }

    /// In the units the user picked on the height and weight step, so a metric user never sees
    /// pounds here (and "~1 lb", singular).
    func detail(imperial: Bool) -> String {
        switch self {
        case .lose:     return "500 kcal/day deficit (~\(imperial ? "1 lb" : "0.5 kg")/week)"
        case .maintain: return "Match your energy expenditure"
        case .gain:     return "250 kcal/day surplus (~\(imperial ? "0.5 lb" : "0.25 kg")/week)"
        }
    }

    var icon: String {
        switch self {
        case .lose:     return "arrow.down.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .gain:     return "arrow.up.circle.fill"
        }
    }

    var calorieAdjustment: Double {
        switch self {
        case .lose:     return -500
        case .maintain: return 0
        case .gain:     return  250
        }
    }
}

// ─── Calculated result ───────────────────────────────────────────────────────

struct CalculatedGoals {
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var waterMlTarget: Double
}

// ─── ViewModel ───────────────────────────────────────────────────────────────

@Observable
@MainActor
final class OnboardingViewModel {
    var support: OnboardingSupport = .strength
    var adultConfirmed = false
    var focusDraft = ""
    var customGoals: CalculatedGoals?
    // Fixture-only permission; production always reads account-scoped persisted consent.
    var previewPulseAllowed = false
    var trimmedFocus: String { focusDraft.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isFocusValid: Bool { focusDraft.unicodeScalars.count <= 300 }
    var selectedGoals: CalculatedGoals { customGoals ?? calculatedGoals }
    var adultDOBRange: ClosedRange<Date> {
        let calendar = Calendar.current
        return (calendar.date(byAdding: .year, value: -120, to: .now) ?? .now)...(calendar.date(byAdding: .year, value: -18, to: .now) ?? .now)
    }
    var canContinueBasics: Bool {
        canContinueName && adultConfirmed && adultDOBRange.contains(dob)
        && heightCm.isFinite && (100...250).contains(heightCm)
        && weightKg.isFinite && (30...300).contains(weightKg)
    }
    var areTargetsValid: Bool {
        let g = selectedGoals
        return g.calories.isFinite && (800...10000).contains(g.calories)
        && [g.proteinG, g.carbsG, g.fatG, g.fiberG].allSatisfy { $0.isFinite && (0...1500).contains($0) }
        && g.waterMlTarget.isFinite && (250...10000).contains(g.waterMlTarget)
    }
    func pulseAllowed(preview: Bool = false) -> Bool {
        preview ? previewPulseAllowed : PulseProfileStore.shared.pulseActive
    }
    func canSaveFocus(preview: Bool = false) -> Bool {
        pulseAllowed(preview: preview) && isFocusValid && !trimmedFocus.isEmpty
    }
    /// Stable ID makes a repeated finish tap converge on one explicitly approved memory.
    private let focusMemoryId = UUID()
    private var savedFocus: PulseMemory?
    private let focusRepository: any PulseMemoryRepositoryProtocol
    func focusMemory(userId: UUID, requested: Bool, allowed: Bool) -> PulseMemory? {
        guard requested, allowed, isFocusValid, !trimmedFocus.isEmpty else { return nil }
        return PulseMemory(id: focusMemoryId, userId: userId, content: trimmedFocus)
    }

    /// Reconcile with server state so a restart after a partial save cannot create a
    /// duplicate-content conflict. Never delete a memory that predates this setup attempt.
    func persistFocus(userId: UUID, requested: Bool, allowed: Bool) async throws {
        if let memory = focusMemory(userId: userId, requested: requested, allowed: allowed) {
            let existing = try await focusRepository.fetch(userId: userId)
            let match = existing.first {
                $0.userId == userId && $0.isValid && $0.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(memory.content) == .orderedSame
            }
            if let match, match.id != memory.id {
                if let previous = savedFocus {
                    try await focusRepository.delete(previous)
                    savedFocus = nil
                }
                return
            }
            try await focusRepository.save(memory)
            savedFocus = memory
        } else if let previous = savedFocus {
            // A prior finish saved focus but failed to commit the profile. A later skip
            // must remove that attempt's memory, and a deletion failure must remain retryable.
            try await focusRepository.delete(previous)
            savedFocus = nil
        }
    }

    // Step 1 – Name
    var fullName = ""

    init(focusRepository: (any PulseMemoryRepositoryProtocol)? = nil) {
        self.focusRepository = focusRepository ?? PulseMemoryRepository()
        // Sign in with Apple surrenders the user's name exactly once, on first authorization.
        // AuthViewModel stashes it; use it to pre-fill rather than asking for what we know.
        if let appleName = UserDefaults.standard.string(forKey: AuthViewModel.pendingAppleFullNameKey) {
            fullName = appleName
        }
    }

    // Step 2 – Biological sex
    var sex: BiologicalSex = .male

    // Step 3 – Date of birth (default: 30 years ago)
    var dob: Date = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now

    // Step 4 – Height & weight
    var useImperialUnits = true    // US default; controls display unit in the step view
    var heightCm: Double = 170     // always stored in cm; step view converts for display
    var weightKg: Double = 75      // always stored in kg

    // Step 5 – Activity level
    var activityLevel: ActivityLevel = .moderate

    // Step 6 – Goal
    var goal: WeightGoal = .maintain

    // Step 8 – GLP-1 (optional)
    var isOnGLP1 = false
    var glp1Medication: GLP1Medication = .ozempic
    var glp1DoseMg: Double = 0.5
    var glp1LastInjected: Date = Calendar.current.startOfDay(for: .now)

    // Step 9 – Anything Pulse should know? (optional, skippable). Only allergies and how they
    // eat — loves/avoids and the kitchen situation live in AboutYouView, after onboarding.
    var pulseAllergies: [String] = []
    var pulseAllergyNote = ""
    var pulseEatingPatterns: Set<EatingPattern> = []

    /// What this step collected, in the shape `PulseProfileStore.savePreferences` expects.
    var pulseAboutYou: PulsePreferences {
        .init(allergies: pulseAllergies, allergyNote: pulseAllergyNote,
              eatingPatterns: pulseEatingPatterns, loves: [], avoids: [])
    }

    var isLoading = false
    var errorMessage: String? = nil

    var canContinueName: Bool { !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // ── Mifflin-St Jeor BMR ──────────────────────────────────────────────────
    // Male:   BMR = 10W + 6.25H − 5A + 5
    // Female: BMR = 10W + 6.25H − 5A − 161
    // Other:  average of the two (no single validated formula)
    // Lives in GoalCalculator now, so Profile can reuse it when stats change.
    var calculatedGoals: CalculatedGoals {
        GoalCalculator.goals(
            sex: sex,
            ageYears: GoalCalculator.ageYears(fromDOB: dob),
            heightCm: heightCm,
            weightKg: weightKg,
            activity: activityLevel,
            weightGoal: goal
        )
    }

    // ── Save (called from SummaryStepView) ───────────────────────────────────
    //
    // These four writes are not a transaction, so any of them can fail after an
    // earlier one committed and the user will tap "Start Tracking" again. Two
    // properties make that safe:
    //
    // IDEMPOTENT — every write converges on the same rows when repeated. The
    // client-generated ids below (stable for the life of this ViewModel) are what
    // make the weight and GLP-1 writes safe to retry; a plain INSERT added a fresh
    // starting-weight row on every attempt.
    //
    // ORDERED — profiles.full_name is written LAST, because it is the flag
    // AppState.needsOnboarding reads to decide onboarding is done. Writing it
    // first meant that killing the app mid-save left a user marked "onboarded"
    // with no daily_goals row: straight to the Today screen with no targets, and
    // no way back into onboarding to create them.
    private let startingWeightLogId = UUID()
    private let initialGLP1LogId    = UUID()

    @discardableResult
    func save(userId: UUID, saveFocus: Bool = false) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }

        // No onboarding mutation is allowed until this session can read its
        // trigger-created profile. A complete profile means this is a returning user.
        let activeUserId = try await supabase.auth.session.user.id
        guard activeUserId == userId else { throw OnboardingSaveError.sessionExpired }
        let existing: [UserProfile] = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        guard let existingProfile = existing.first else {
            throw OnboardingSaveError.profileUnavailable
        }
        if existingProfile.fullName != nil { return existingProfile }

        guard canContinueBasics, areTargetsValid, isFocusValid else { throw OnboardingSaveError.invalidSetup }
        let goals = selectedGoals

        // 1. Record starting weight (idempotent on the client-generated id)
        try await supabase
            .from("weight_logs")
            .upsert(OnboardingWeightLog(
                id: startingWeightLogId,
                userId: userId,
                weightKg: weightKg
            ), onConflict: "id")
            .execute()

        // 2. Create initial daily goal. The conflict target must be named explicitly:
        //    a bare upsert() resolves on the primary key (a fresh uuid every call),
        //    so it never saw the UNIQUE (user_id, effective_date) collision and a
        //    second run of onboarding died on a duplicate-key error.
        try await supabase
            .from("daily_goals")
            .upsert(NewDailyGoal(
                userId: userId,
                effectiveDate: Date().isoDateString,
                calories: goals.calories,
                proteinG: goals.proteinG,
                carbsG: goals.carbsG,
                fatG: goals.fatG,
                fiberG: goals.fiberG,
                waterMlTarget: goals.waterMlTarget
            ), onConflict: "user_id,effective_date")
            .execute()

        // Record the weight these goals were computed from, so Today's drift check has a
        // baseline to compare the rolling average against.
        if weightKg > 0 {
            UserDefaults.standard.set(weightKg, forKey: GoalCalculator.weightBaselineKey)
        }

        // 3. GLP-1 log (optional — skipped if user didn't set it up)
        if isOnGLP1 {
            let nextDue = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: glp1LastInjected) ?? glp1LastInjected
            try await supabase
                .from("glp1_logs")
                .upsert(OnboardingGLP1Log(
                    id: initialGLP1LogId,
                    userId: userId,
                    injectedAt: glp1LastInjected,
                    medication: glp1Medication.rawValue,
                    doseMg: glp1DoseMg,
                    site: InjectionSite.leftAbdomen.rawValue,
                    nextDueAt: nextDue
                ), onConflict: "id")
                .execute()

            // The GLP-1 onboarding step promises "Pulse tracks your injection schedule",
            // but only ProfileViewModel.logInjection ever scheduled reminders — so a user
            // who set GLP-1 up here got none until they happened to log an injection
            // manually. Failing to schedule must not fail the save, hence no `try`.
            await NotificationManager.shared.scheduleGLP1Reminders(nextDueAt: nextDue)
        }

        // 3.6 What Pulse knows (optional, skippable step — empty when the user skipped it).
        //     Unlike the writes above, this never blocks onboarding: a coaching preference
        //     is not worth stranding the user in a retry loop over, so failures are swallowed
        //     rather than thrown. The user can always fill this in later from AboutYouView.
        if !pulseAboutYou.isEmpty {
            // Never blocks onboarding, but never drops allergies either: a failed save waits on
            // the device and is merged in on the next successful load.
            await PulseProfileStore.shared.savePreferencesOrQueue(pulseAboutYou)
        }

        // 3.5 Record the chosen direction. Separate from the UpdateProfile commit below
        //     (whose shape several flows share) and safe to repeat.
        try await supabase
            .from("profiles")
            .update(["weight_goal": goal.rawValue])
            .eq("id", value: userId)
            .execute()

        // An explicit choice is required independently of AI consent. No provider is called.
        guard supabase.auth.currentSession?.user.id == userId,
              PulseProfileStore.shared.accountId == userId else { throw OnboardingSaveError.sessionExpired }
        try await persistFocus(userId: userId, requested: saveFocus, allowed: pulseAllowed())
        guard supabase.auth.currentSession?.user.id == userId else { throw OnboardingSaveError.sessionExpired }

        // 4. Commit the profile last — this is what marks onboarding complete.
        //    Returning the saved row lets the caller update AppState without a
        //    second network round trip that could fail and strand the user.
        let savedProfile: UserProfile = try await supabase
            .from("profiles")
            .update(UpdateProfile(
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                dob: dob.isoDateString,
                sex: sex.rawValue,
                heightCm: heightCm,
                activityLevel: activityLevel.rawValue
            ))
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value

        // The name now lives on the profile row; the one-shot Apple stash has done its job.
        UserDefaults.standard.removeObject(forKey: AuthViewModel.pendingAppleFullNameKey)

        // Persist the unit choice to the app-wide @AppStorage("unitSystem") key that
        // Today/Profile/BodyComposition read. Without this, a user who onboarded in imperial
        // (the US default) landed on a metric UI until they found the Profile units picker.
        UserDefaults.standard.set(useImperialUnits ? "imperial" : "metric", forKey: "unitSystem")

        return savedProfile
    }
}

enum OnboardingSaveError: LocalizedError {
    case sessionExpired
    case profileUnavailable
    case invalidSetup

    var errorDescription: String? {
        switch self {
        case .sessionExpired:
            "Your session changed. Please sign in again."
        case .invalidSetup:
            "Please review your profile details, focus length, and nutrition targets before starting."
        case .profileUnavailable:
            "We couldn't securely load your account. No setup changes were saved. Please try signing in again."
        }
    }
}

// ─── Idempotent insert payloads ──────────────────────────────────────────────
// Identical to NewWeightLog / NewGLP1Log but carrying a client-supplied primary
// key, so an interrupted onboarding can be retried without duplicating rows.

private struct OnboardingWeightLog: Encodable {
    let id: UUID
    let userId: UUID
    let weightKg: Double
    var source: String = "manual"

    enum CodingKeys: String, CodingKey {
        case id
        case userId   = "user_id"
        case weightKg = "weight_kg"
        case source
    }
}

private struct OnboardingGLP1Log: Encodable {
    let id: UUID
    let userId: UUID
    let injectedAt: Date
    let medication: String
    let doseMg: Double
    let site: String
    let nextDueAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case injectedAt = "injected_at"
        case medication
        case doseMg     = "dose_mg"
        case site
        case nextDueAt  = "next_due_at"
    }
}
