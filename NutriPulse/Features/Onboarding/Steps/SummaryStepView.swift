import SwiftUI

struct SummaryStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onComplete: () -> Void

    var body: some View {
        let goals = vm.calculatedGoals

        OnboardingStepLayout(
            step: 9,
            title: "Your daily targets",
            subtitle: "Based on Mifflin-St Jeor BMR + your activity & goal.",
            continueLabel: vm.isLoading ? "Saving…" : "Start Tracking",
            canContinue: !vm.isLoading,
            onContinue: onComplete
        ) {
            VStack(spacing: Theme.Spacing.md) {
                // ── Big calorie number ─────────────────────────────────────
                VStack(spacing: Theme.Spacing.xs) {
                    Text("\(Int(goals.calories))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.NutrientColor.calories)
                    Text("calories / day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.lg)
                .card()

                // ── Macro breakdown ────────────────────────────────────────
                VStack(spacing: 0) {
                    MacroRow(color: Theme.NutrientColor.protein,
                             label: "Protein",
                             grams: goals.proteinG,
                             pct: 30)
                    Divider().padding(.horizontal)
                    MacroRow(color: Theme.NutrientColor.carbs,
                             label: "Carbs",
                             grams: goals.carbsG,
                             pct: 40)
                    Divider().padding(.horizontal)
                    MacroRow(color: Theme.NutrientColor.fat,
                             label: "Fat",
                             grams: goals.fatG,
                             pct: 30)
                    Divider().padding(.horizontal)
                    MacroRow(color: Theme.NutrientColor.fiber,
                             label: "Fiber",
                             grams: goals.fiberG,
                             pct: nil)
                }
                .card()

                // ── Water target ───────────────────────────────────────────
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Theme.NutrientColor.water)
                    Text("Water target")
                    Spacer()
                    // Int(2625/1000*10) / 10 is 26 / 10 = 2 — integer division. Every user's
                    // water target was floored to a whole litre; 2,625 ml displayed as "2 L".
                    // The `* 10 ... / 10` was clearly reaching for one decimal place.
                    Text(String(format: "%.1f L / day", goals.waterMlTarget / 1000))
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("You can adjust these targets later in Settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("NutriPulse is a wellness tracker, not a medical device, and Pulse is not a medical professional. Nothing in the app is medical advice — always talk to your doctor about medication and health decisions.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
    }
}

private struct MacroRow: View {
    let color: Color
    let label: String
    let grams: Double
    let pct: Int?

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
            Spacer()
            if let pct {
                Text("\(pct)%")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Text("\(Int(grams)) g")
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
