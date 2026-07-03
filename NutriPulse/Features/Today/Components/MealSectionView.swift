import SwiftUI

struct MealSectionView: View {
    let meal: Meal
    let logs: [FoodLog]

    private var mealCalories: Double { logs.reduce(0) { $0 + $1.totalCalories } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Label(meal.displayName, systemImage: meal.icon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(mealCalories)) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Color(.tertiarySystemBackground))

            // Food log rows
            // SWIFT CONCEPT — ForEach over an Identifiable collection. SwiftUI uses the `id`
            // property to efficiently diff and animate list changes, the same role `key` plays in React.
            ForEach(logs) { log in
                FoodLogRowView(log: log)
                    .padding(.horizontal, Theme.Spacing.md)
                if log != logs.last {
                    Divider().padding(.leading, Theme.Spacing.md)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct FoodLogRowView: View {
    let log: FoodLog

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(servingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(log.totalCalories)) kcal")
                    .font(.subheadline.weight(.medium))
                Text("P \(Int(log.totalProteinG))g · C \(Int(log.totalCarbsG))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var servingText: String {
        let qty = log.quantity == log.quantity.rounded() ? "\(Int(log.quantity))" : String(format: "%.1f", log.quantity)
        let desc = log.foodItems?.servingDesc ?? "serving"
        return "\(qty) × \(desc)"
    }
}
