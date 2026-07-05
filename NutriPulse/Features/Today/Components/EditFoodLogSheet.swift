import SwiftUI

// Only meal + servings are user-editable — macro values are a per-serving
// snapshot from whatever source resolved them (FatSecret, Claude's estimate,
// manual entry), not something to hand-edit after the fact. Deleting lives
// on the row itself (swipe left) — not duplicated here.
struct EditFoodLogSheet: View {
    let log: FoodLog
    let onSave: (Meal, Double) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var meal: Meal
    @State private var quantity: Double
    @State private var isSaving = false

    init(log: FoodLog, onSave: @escaping (Meal, Double) async -> Void) {
        self.log = log
        self.onSave = onSave
        _meal = State(initialValue: log.meal)
        _quantity = State(initialValue: log.quantity)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(log.displayName)
                        .font(.headline)
                    Text("\(Int(log.caloriesSnapshot)) kcal · \(Int(log.proteinGSnapshot))g protein per serving")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: { Text("Food") }

                Section {
                    Picker("Meal", selection: $meal) {
                        ForEach(Meal.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { m in
                            Label(m.displayName, systemImage: m.icon).tag(m)
                        }
                    }
                    HStack {
                        Text("Servings")
                        Spacer()
                        Text(quantity.formatted())
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Stepper("", value: $quantity, in: 0.25...20, step: 0.25)
                            .labelsHidden()
                    }
                } header: { Text("Log details") }
            }
            .navigationTitle("Edit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            await onSave(meal, quantity)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}
