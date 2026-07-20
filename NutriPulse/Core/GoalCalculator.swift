import Foundation

// Mifflin-St Jeor / Katch-McArdle, extracted from OnboardingViewModel so Profile can reuse it
// when the user's stats change. Editing weight, activity, sex or DOB used to leave the calorie
// and macro targets untouched, so a user who lost 20 lb kept eating for their old body.
//
// All of these are swaps between widely used, published formulas — computational choices, not
// health claims. Copy that surfaces the results stays neutral ("targets based on your stats"),
// and recalculations are always offered to the user, never silently applied.
enum GoalCalculator {

    // Never recommend below this, however aggressive the deficit.
    static let calorieFloor: Double = 1200

    // Protein is anchored to body weight, not to a share of calories. A percentage split
    // hands out LESS protein the deeper the deficit — exactly backwards for this app's
    // users, where lean-mass preservation is the whole point of the protein-first design.
    // 1.6 g/kg is the top of the commonly cited 1.2–1.6 range for weight loss.
    static let proteinPerKg: Double = 1.6

    // ...but never more than this share of calories, so the 1200-floor + high-body-weight
    // corner can't prescribe a plate that is half protein.
    static let proteinCalorieCap: Double = 0.35

    static let fatCalorieShare: Double = 0.30

    // 14 g per 1000 kcal within these bounds; 35 ml per kg within these bounds.
    static let fiberRangeG: ClosedRange<Double> = 25...38
    static let waterRangeMl: ClosedRange<Double> = 2000...4000

    // UserDefaults key: the (rolling-average) weight the current goals were computed from.
    // Written wherever goals are set — onboarding, Profile recalc, Edit Goals, and the
    // Today drift prompt — and read by TodayViewModel.checkWeightDrift.
    static let weightBaselineKey = "goalWeightBaselineKg"

    // Re-offer a recalc when the 7-day average weight has moved this fraction from the
    // baseline. 2.5% is ~5 lb at 200 lb — real body change, comfortably above the daily
    // water-weight noise a GLP-1 user sees.
    static let weightDriftThreshold = 0.025

    // ── BMR / TDEE ───────────────────────────────────────────────────────────

    //  With a plausible body-fat %, Katch-McArdle: 370 + 21.6 × lean mass (kg) — lean mass
    //  predicts resting burn better than total weight, especially at higher body-fat levels,
    //  which is where much of this app's audience lives. Sex/age/height drop out; that's the
    //  formula, not an omission.
    //
    //  Otherwise Mifflin-St Jeor:
    //  Male:   10W + 6.25H − 5A + 5
    //  Female: 10W + 6.25H − 5A − 161
    //  Other:  the average of the two — there's no single validated formula.
    static func bmr(
        sex: BiologicalSex,
        ageYears: Double,
        heightCm: Double,
        weightKg: Double,
        bodyFatPct: Double? = nil
    ) -> Double {
        // The range guard treats junk readings (a scale glitch reporting 1% or 75%) as
        // "unknown" rather than letting them produce an absurd lean mass.
        if let bf = bodyFatPct, (3..<60).contains(bf) {
            return 370 + 21.6 * (weightKg * (1 - bf / 100))
        }
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
        activity: ActivityLevel,
        bodyFatPct: Double? = nil
    ) -> Double {
        bmr(sex: sex, ageYears: ageYears, heightCm: heightCm, weightKg: weightKg,
            bodyFatPct: bodyFatPct) * activity.multiplier
    }

    // ── Macros ───────────────────────────────────────────────────────────────

    // The weight the protein anchor multiplies. At BMI ≤ 30 that's actual weight; above it,
    // adjusted body weight — Devine ideal weight plus a quarter of the excess — so a 150 kg
    // user isn't handed an unreachable 240 g target. Protein need tracks lean tissue, and
    // adjusted BW is the standard dietetic proxy for it when only weight/height are known.
    static func proteinAnchorWeightKg(
        weightKg: Double,
        heightCm: Double,
        sex: BiologicalSex
    ) -> Double {
        guard heightCm > 0, weightKg > 0 else { return weightKg }
        let bmi = weightKg / pow(heightCm / 100, 2)
        guard bmi > 30 else { return weightKg }
        let inchesOverFiveFeet = max(0, heightCm / 2.54 - 60)
        let ibw: Double
        switch sex {
        case .male:   ibw = 50.0 + 2.3 * inchesOverFiveFeet
        case .female: ibw = 45.5 + 2.3 * inchesOverFiveFeet
        case .other:  ibw = 47.75 + 2.3 * inchesOverFiveFeet
        }
        // min() guards very short/heavy edge cases where "adjusted" could exceed actual.
        return min(ibw + 0.25 * (weightKg - ibw), weightKg)
    }

    // Allocation order: protein first (g/kg, capped), fat as a fixed share, carbs get the
    // remainder — which also makes the displayed macros sum to the calorie goal instead of
    // drifting a few kcal from independent rounding. Callers without height/sex (legacy
    // paths) fall back to anchoring protein on actual weight.
    static func macros(
        calories: Double,
        weightKg: Double,
        heightCm: Double? = nil,
        sex: BiologicalSex? = nil
    ) -> CalculatedGoals {
        let anchorKg: Double = {
            guard let heightCm, let sex else { return weightKg }
            return proteinAnchorWeightKg(weightKg: weightKg, heightCm: heightCm, sex: sex)
        }()
        let proteinG = min(proteinPerKg * anchorKg, calories * proteinCalorieCap / 4).rounded()
        let fatG     = (calories * fatCalorieShare / 9).rounded()
        let carbsG   = max(0, (calories - proteinG * 4 - fatG * 9) / 4).rounded()
        return CalculatedGoals(
            calories:      calories,
            proteinG:      proteinG,
            carbsG:        carbsG,
            fatG:          fatG,
            fiberG:        (calories / 1000 * 14).clamped(to: fiberRangeG).rounded(),
            waterMlTarget: (weightKg * 35).clamped(to: waterRangeMl).rounded()
        )
    }

    static func goals(
        sex: BiologicalSex,
        ageYears: Double,
        heightCm: Double,
        weightKg: Double,
        activity: ActivityLevel,
        weightGoal: WeightGoal,
        bodyFatPct: Double? = nil
    ) -> CalculatedGoals {
        let target = max(
            calorieFloor,
            tdee(sex: sex, ageYears: ageYears, heightCm: heightCm, weightKg: weightKg,
                 activity: activity, bodyFatPct: bodyFatPct)
                + weightGoal.calorieAdjustment
        ).rounded()
        return macros(calories: target, weightKg: weightKg, heightCm: heightCm, sex: sex)
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
        newWeightKg: Double,
        heightCm: Double? = nil,
        sex: BiologicalSex? = nil
    ) -> CalculatedGoals {
        let adjustment = currentCalories - oldTDEE
        let target = max(calorieFloor, newTDEE + adjustment).rounded()
        return macros(calories: target, weightKg: newWeightKg, heightCm: heightCm, sex: sex)
    }

    // ── Weight drift ─────────────────────────────────────────────────────────

    // The pure trigger behind the Today "update your targets?" prompt. Direction-agnostic:
    // gaining past the threshold matters as much as losing past it.
    static func weightDriftExceeds(
        baselineKg: Double,
        recentAvgKg: Double,
        threshold: Double = weightDriftThreshold
    ) -> Bool {
        guard baselineKg > 0, recentAvgKg > 0 else { return false }
        return abs(recentAvgKg - baselineKg) / baselineKg >= threshold
    }

    static func ageYears(fromDOB dob: Date, now: Date = .now) -> Double {
        Double(Calendar.current.dateComponents([.year], from: dob, to: now).year ?? 30)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
