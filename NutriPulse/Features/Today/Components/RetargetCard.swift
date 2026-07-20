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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Theme.Colors.primary)
                Text("Update your targets?")
                    .fontWeight(.semibold)
            }

            Text("Your average weight is \(deltaText) than when your targets were set. Recalculated, that's \(Int(suggestion.goals.calories)) kcal a day (currently \(Int(suggestion.currentCalories))).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.sm) {
                Button(action: onAccept) {
                    Text("Update targets")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.primary.opacity(0.12))
                        .foregroundStyle(Theme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button(action: onKeep) {
                    Text("Keep current")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.surfaceInset)
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(Theme.Spacing.md)
        .card()
    }
}
