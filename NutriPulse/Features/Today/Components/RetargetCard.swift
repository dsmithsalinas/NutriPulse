import SwiftUI

// The weight-drift recalc offer. Deliberately an offer, not an announcement: the user's
// targets never change unless they tap Update. Copy stays neutral about direction — "lower/
// higher than when your targets were set" — because drifting up is data, not a failure.
struct RetargetCard: View {
    let suggestion: TodayViewModel.RetargetSuggestion
    let units: UnitSystem
    let onAccept: () -> Void
    let onKeep: () -> Void

    private var deltaText: String {
        let deltaKg = suggestion.avgWeightKg - suggestion.baselineKg
        let display = abs(units.weightInput(from: deltaKg))
        let direction = deltaKg < 0 ? "lower" : "higher"
        return "\(String(format: "%.1f", display)) \(units.weightUnit) \(direction)"
    }

    private var isMaintenance: Bool { suggestion.kind == .maintenance }

    private var titleText: String {
        // Calm, factual, and it earns no exclamation mark — the moment is the reward.
        isMaintenance ? "You're at your goal weight" : "Update your targets?"
    }

    private var bodyText: String {
        if isMaintenance {
            let goalText = suggestion.goalWeightKg.map {
                "\(String(format: "%.1f", units.weightInput(from: $0))) \(units.weightUnit)"
            } ?? "your goal"
            return "Your average weight is right around the \(goalText) goal you set. Shifting to maintenance would be about \(Int(suggestion.goals.calories)) kcal a day (currently \(Int(suggestion.currentCalories)))."
        }
        return "Your average weight is \(deltaText) than when your targets were set. Recalculated, that's \(Int(suggestion.goals.calories)) kcal a day (currently \(Int(suggestion.currentCalories)))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: isMaintenance ? "checkmark.seal" : "arrow.triangle.2.circlepath")
                    .foregroundStyle(Theme.Colors.primary)
                Text(titleText)
                    .font(Theme.Fonts.body(16, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Text(bodyText)
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.sm) {
                Button(action: onAccept) {
                    Text(isMaintenance ? "Shift to maintenance" : "Update targets")
                        .font(Theme.Fonts.body(14, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                Button(action: onKeep) {
                    Text("Keep current")
                        .font(Theme.Fonts.body(14, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .tile(radius: Theme.Radius.tileSmall, padding: Theme.Spacing.md)
    }
}
