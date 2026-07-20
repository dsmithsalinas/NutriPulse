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

    var detail: String {
        switch self {
        case .lose:     return "500 kcal/day deficit (~1 lb/week)"
        case .maintain: return "Match your energy expenditure"
        case .gain:     return "250 kcal/day surplus (~0.5 lb/week)"
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
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let waterMlTarget: Double
}

// ─── ViewModel ───────────────────────────────────────────────────────────────

@Observable
@MainActor
final class OnboardingViewModel {
    // Step 1 – Name
    var fullName = ""

    init() {
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

    var isLoading = false
    var errorMessage: String? = nil

    var canContinueName: Bool { !fullName.trimmingCharacters(in: .whitespaces).isEmpty }

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
    func save(userId: UUID) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }

        let goals = calculatedGoals

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

        // 4. Commit the profile last — this is what marks onboarding complete.
        //    Returning the saved row lets the caller update AppState without a
        //    second network round trip that could fail and strand the user.
        let savedProfile: UserProfile = try await supabase
            .from("profiles")
            .update(UpdateProfile(
                fullName: fullName.trimmingCharacters(in: .whitespaces),
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
