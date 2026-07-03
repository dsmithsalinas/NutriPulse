import SwiftUI

struct ManualEntryView: View {
    // SWIFT CONCEPT — @Bindable lets a view that RECEIVES an @Observable object
    // (rather than owning it with @State) create two-way bindings via $vm.property.
    // Think of it as the SwiftUI equivalent of passing a ref to a React child component.
    @Bindable var vm: FoodLoggingViewModel
    let date: Date
    let onLogged: () -> Void

    var body: some View {
        Form {
            Section {
                // Meal picker
                Picker("Meal", selection: $vm.selectedMeal) {
                    ForEach(Meal.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { meal in
                        Label(meal.displayName, systemImage: meal.icon).tag(meal)
                    }
                }

                // Servings stepper — custom label so we can show the current value inline
                HStack {
                    Text("Servings")
                    Spacer()
                    Text(vm.quantity.formatted())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper("", value: $vm.quantity, in: 0.25...20, step: 0.25)
                        .labelsHidden()
                }
            } header: { Text("Log details") }

            Section {
                TextField("Food name", text: $vm.name)
                    .autocorrectionDisabled()
                TextField("Brand (optional)", text: $vm.brand)
                    .autocorrectionDisabled()
                TextField("Serving size", text: $vm.servingDesc)
            } header: { Text("Food") }

            Section {
                MacroField(label: "Calories",  value: $vm.calories,  unit: "kcal")
                MacroField(label: "Protein",   value: $vm.proteinG,  unit: "g")
                MacroField(label: "Carbs",     value: $vm.carbsG,    unit: "g")
                MacroField(label: "Fat",       value: $vm.fatG,      unit: "g")
                MacroField(label: "Fiber",     value: $vm.fiberG,    unit: "g")
            } header: { Text("Nutrition per serving") }
        }
        .safeAreaInset(edge: .bottom) {
            logButton
        }
    }

    private var logButton: some View {
        Button {
            Task {
                do {
                    try await vm.logManualFood(on: date)
                    onLogged()
                } catch {
                    vm.errorMessage = error.localizedDescription
                }
            }
        } label: {
            Group {
                if vm.isLoading {
                    ProgressView()
                } else {
                    Text("Log \(vm.quantity.formatted()) × \(vm.name.isEmpty ? "food" : vm.name)")
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(vm.canLog ? Theme.NutrientColor.calories : Color(.systemFill))
            .foregroundStyle(vm.canLog ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!vm.canLog || vm.isLoading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
        .background(.bar)    // matches the system "floating bar" material
    }
}

// Reusable numeric field row for the nutrition section
private struct MacroField: View {
    let label: String
    @Binding var value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            // SWIFT CONCEPT — TextField(value:format:) in iOS 15+ binds directly to a
            // numeric type and handles keyboard/parsing automatically.
            // It's like <input type="number"> but type-safe.
            TextField("0", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
    }
}
