import SwiftUI

struct ManualEntryView: View {
    // SWIFT CONCEPT — @Bindable lets a view that RECEIVES an @Observable object
    // (rather than owning it with @State) create two-way bindings via $vm.property.
    // Think of it as the SwiftUI equivalent of passing a ref to a React child component.
    @Bindable var vm: FoodLoggingViewModel
    let date: Date
    let onLogged: (LogSource) -> Void

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
                    onLogged(.manual)
                } catch {
                    vm.errorMessage = error.localizedDescription
                }
            }
        } label: {
            if vm.isLoading {
                ProgressView().tint(.white)
            } else {
                Text("Log \(vm.quantity.formatted()) × \(vm.name.isEmpty ? "food" : vm.name)")
                    .lineLimit(1)
            }
        }
        .buttonStyle(.brandPrimary)
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

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            // Bound to a String, not a Double. TextField(value:format:) commits to its
            // binding only on submit or focus loss, and .decimalPad has no return key —
            // so typing "250" into Calories and tapping Log left `calories` at 0, leaving
            // the button disabled with no explanation. Editing a macro last and then
            // tapping Log silently discarded that correction.
            //
            // Parsing per keystroke keeps the ViewModel in sync, which also lets `canLog`
            // enable the Log button the moment calories are entered. See DecimalInput.
            TextField("0", text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 80)
                .onChange(of: text) { _, newText in
                    let cleaned = DecimalInput.sanitize(newText)
                    if cleaned != newText { text = cleaned }
                    value = DecimalInput.value(from: cleaned)
                }
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
        .onAppear { text = DecimalInput.text(from: value) }
    }
}
