import Foundation

// Mifflin-St Jeor, extracted from OnboardingViewModel so Profile can reuse it when the
// user's stats change. Editing weight, activity, sex or DOB used to leave the calorie and
// macro targets untouched, so a user who lost 20 lb kept eating for their old body.
enum GoalCalculator {

    // Never recommend below this, however aggressive the deficit.
    static let calorieFloor: Double = 1200

    //  Male:   10W + 6.25H − 5A + 5
    //  Female: 10W + 6.25H − 5A − 161
    //  Other:  the average of the two — there's no single validated formula.
    static func bmr(sex: BiologicalSex, ageYears: Double, heightCm: Double, weightKg: Double) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears
        switch sex {
        case .male:   return base + 5
        case .female: return base - 161
        case .other:  return base + (5 - 161) / 2
        }
    }

    static func tdee(
        sex: BiologicalSex,
        ageYears: Double,
        heightCm: Double,
        weightKg: Double,
        activity: ActivityLevel
    ) -> Double {
        bmr(sex: sex, ageYears: ageYears, heightCm: heightCm, weightKg: weightKg) * activity.multiplier
    }

    // Macro split: 30% protein / 40% carbs / 30% fat. Fiber 14g per 1000 kcal (min 25g).
    // Water 35 ml per kg body weight (min 2 L).
    static func macros(calories: Double, weightKg: Double) -> CalculatedGoals {
        CalculatedGoals(
            calories:      calories,
            proteinG:      (calories * 0.30 / 4).rounded(),
            carbsG:        (calories * 0.40 / 4).rounded(),
            fatG:          (calories * 0.30 / 9).rounded(),
            fiberG:        max(25, calories / 1000 * 14).rounded(),
            waterMlTarget: max(2000, weightKg * 35).rounded()
        )
    }

    static func goals(
        sex: BiologicalSex,
        ageYears: Double,
        heightCm: Double,
        weightKg: Double,
        activity: ActivityLevel,
        weightGoal: WeightGoal
    ) -> CalculatedGoals {
        let target = max(
            calorieFloor,
            tdee(sex: sex, ageYears: ageYears, heightCm: heightCm, weightKg: weightKg, activity: activity)
                + weightGoal.calorieAdjustment
        ).rounded()
        return macros(calories: target, weightKg: weightKg)
    }

    // Recomputes a target after a stats change while PRESERVING whatever adjustment the user
    // is currently living with — the deficit they picked at onboarding, or a target they
    // hand-tuned in Edit Goals. `profiles` has no weight-goal column, so the intent has to be
    // inferred from the gap between their current target and their old maintenance number.
    // Blindly re-deriving from WeightGoal would silently discard a manual edit.
    static func retargeted(
        currentCalories: Double,
        oldTDEE: Double,
        newTDEE: Double,
        newWeightKg: Double
    ) -> CalculatedGoals {
        let adjustment = currentCalories - oldTDEE
        let target = max(calorieFloor, newTDEE + adjustment).rounded()
        return macros(calories: target, weightKg: newWeightKg)
    }

    static func ageYears(fromDOB dob: Date, now: Date = .now) -> Double {
        Double(Calendar.current.dateComponents([.year], from: dob, to: now).year ?? 30)
    }
}
