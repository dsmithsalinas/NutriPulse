import SwiftUI

struct RepeatedMealConfirmationSheet: View {
    let sourceDate: String
    let meal: Meal
    let vm: TodayViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var logs: [FoodLog] = []
    @State private var quantities: [UUID: Double] = [:]
    @State private var isLoading = true
    @State private var isSaving = false

    private func quantity(for log: FoodLog) -> Double {
        quantities[log.id] ?? log.quantity
    }

    private var totals: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        logs.reduce(into: (0, 0, 0, 0)) { result, log in
            let amount = quantity(for: log)
            result.0 += log.caloriesSnapshot * amount
            result.1 += log.proteinGSnapshot * amount
            result.2 += log.carbsGSnapshot * amount
            result.3 += log.fatGSnapshot * amount
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your usual meal…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if logs.isEmpty {
                    BrandedEmptyState(
                        icon: "fork.knife",
                        title: "Meal unavailable",
                        message: "The original meal is no longer available on this device."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Review before logging", systemImage: "checklist")
                                    .font(Theme.Fonts.body(15, .bold))
                                    .foregroundStyle(Theme.Colors.primaryText)
                                Text("From \(formattedSourceDate). Adjust any serving, then add it to today.")
                                    .font(Theme.Fonts.body(14))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }

                            VStack(spacing: 0) {
                                ForEach(logs) { log in
                                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(log.displayName)
                                                .font(Theme.Fonts.body(15, .bold))
                                                .foregroundStyle(Theme.Colors.textPrimary)
                                            Spacer()
                                            Text("\(Int((log.caloriesSnapshot * quantity(for: log)).rounded())) kcal")
                                                .font(Theme.Fonts.body(12))
                                                .foregroundStyle(Theme.Colors.textSecondary)
                                                .monospacedDigit()
                                        }

                                        Stepper(value: Binding(
                                            get: { quantity(for: log) },
                                            set: { quantities[log.id] = $0 }
                                        ), in: 0.5...10, step: 0.5) {
                                            Text("\(quantity(for: log).formatted(.number.precision(.fractionLength(0...1)))) servings")
                                                .font(Theme.Fonts.body(12))
                                                .foregroundStyle(Theme.Colors.textSecondary)
                                        }
                                    }
                                    .padding(Theme.Spacing.md)

                                    if log.id != logs.last?.id {
                                        Rectangle()
                                            .fill(Theme.Colors.hairline)
                                            .frame(height: 1)
                                            .padding(.leading, Theme.Spacing.md)
                                    }
                                }
                            }
                            .tile()

                            HStack(spacing: Theme.Spacing.sm) {
                                macro("Calories", totals.calories, "kcal")
                                macro("Protein", totals.protein, "g")
                                macro("Carbs", totals.carbs, "g")
                                macro("Fat", totals.fat, "g")
                            }
                        }
                        .padding(Theme.Spacing.md)
                    }
                    .safeAreaInset(edge: .bottom) {
                        Button {
                            isSaving = true
                            Task {
                                await vm.repeatMeal(from: sourceDate, meal: meal, quantities: quantities)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                if isSaving { ProgressView().tint(.white) }
                                Text("Log \(meal.displayName)")
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.brandPrimary)
                        .disabled(isSaving)
                        .padding(Theme.Spacing.md)
                        .background(.bar)
                    }
                }
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .navigationTitle("Usual \(meal.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .task {
                logs = await vm.mealLogs(from: sourceDate, meal: meal)
                quantities = Dictionary(uniqueKeysWithValues: logs.map { ($0.id, $0.quantity) })
                isLoading = false
            }
        }
        .tint(Theme.Colors.primary)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var formattedSourceDate: String {
        guard let date = Date.fromISODateString(sourceDate) else { return sourceDate }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func macro(_ label: String, _ value: Double, _ unit: String) -> some View {
        VStack(spacing: 3) {
            Text("\(Int(value.rounded()))\(unit)")
                .font(Theme.Fonts.body(13, .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
            Text(label.uppercased())
                .font(Theme.Fonts.body(10, .semibold))
                .foregroundStyle(Theme.Colors.textFaint)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .tile(radius: Theme.Radius.row, padding: 0)
    }
}
