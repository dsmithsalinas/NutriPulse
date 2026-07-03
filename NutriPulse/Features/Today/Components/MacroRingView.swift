import SwiftUI

// Single circular progress ring for one macro nutrient.
struct MacroRingView: View {
    let label: String
    let value: Double
    let goal: Double
    let color: Color
    let unit: String

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ZStack {
                // Background track — the faint full circle
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: Theme.Ring.lineWidth)

                // SWIFT CONCEPT — Circle().trim(from:to:) draws an arc from 0–100%.
                // 0 = rightmost point (3 o'clock). We rotate -90° to start at 12 o'clock.
                // .animation propagates the progress change smoothly.
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color,
                            style: StrokeStyle(lineWidth: Theme.Ring.lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.5), value: progress)

                // Over-goal indicator ring
                if progress >= 1 {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .padding(2)
                }

                VStack(spacing: 0) {
                    Text(value >= 100 ? "\(Int(value))" : String(format: "%.0f", value))
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.7)
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: Theme.Ring.size, height: Theme.Ring.size)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// Four rings in a horizontal row — shown as a card on the Today screen.
struct MacroRingsSection: View {
    let calories:  Double
    let proteinG:  Double
    let carbsG:    Double
    let fiberG:    Double
    let goal:      DailyGoal?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Nutrition")
                .font(.headline)

            HStack(spacing: Theme.Spacing.md) {
                MacroRingView(
                    label: "Calories",
                    value: calories,
                    goal: goal?.calories ?? 2000,
                    color: Theme.NutrientColor.calories,
                    unit: "kcal"
                )
                MacroRingView(
                    label: "Protein",
                    value: proteinG,
                    goal: goal?.proteinG ?? 150,
                    color: Theme.NutrientColor.protein,
                    unit: "g"
                )
                MacroRingView(
                    label: "Carbs",
                    value: carbsG,
                    goal: goal?.carbsG ?? 250,
                    color: Theme.NutrientColor.carbs,
                    unit: "g"
                )
                MacroRingView(
                    label: "Fiber",
                    value: fiberG,
                    goal: goal?.fiberG ?? 25,
                    color: Theme.NutrientColor.fiber,
                    unit: "g"
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Theme.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
