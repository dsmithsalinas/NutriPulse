import SwiftUI

struct FamiliarFoodReview: View {
    @Environment(\.foodSaveUndo) private var undo
    let food: FoodLog
    let date: Date
    let meal: Meal
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var quantity: Double
    @State private var saving = false
    @State private var error: String?
    init(food: FoodLog, date: Date, meal: Meal, onSaved: @escaping () -> Void) {
        self.food = food; self.date = date; self.meal = meal; self.onSaved = onSaved
        _quantity = State(initialValue: food.quantity)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SheetHeader(title: "Review your food", onClose: { dismiss() })
            Text(food.displayName).font(Theme.Fonts.display(24, .bold, relativeTo: .title2))
            Text("Last logged \(food.logDate). Adding to \(meal.displayName.lowercased()) on \(date.formatted(date: .abbreviated, time: .omitted)).")
                .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            Text(food.foodItems?.servingDesc ?? "1 serving").font(Theme.Fonts.body(16))
            Stepper("\(quantity.formatted()) servings", value: $quantity, in: 0.25...20, step: 0.25)
            Text("\(Int((food.caloriesSnapshot * quantity).rounded())) kcal · \(Int((food.proteinGSnapshot * quantity).rounded()))g protein")
                .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
            if let error { Text(error).foregroundStyle(Theme.Colors.danger) }
            Button(saving ? "Saving…" : "Save for this day") {
                saving = true
                Task {
                    let vm = FavoritesViewModel()
                    if (await FoodSaveUndo.$current.withValue(undo) { await vm.logAgain(food, meal: meal, date: date, quantity: quantity) }) {
                        dismiss(); onSaved()
                    } else { error = vm.errorMessage }
                    saving = false
                }
            }.buttonStyle(.brandPrimary).disabled(saving)
            Spacer()
        }.padding(Theme.Spacing.page).background(Theme.Colors.ground)
            .interactiveDismissDisabled(saving).presentationDetents([.medium, .large])
    }
}
