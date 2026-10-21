import SwiftUI

enum OnboardingSupport: String, CaseIterable, Identifiable {
    case strength = "Keep my strength"
    case meals = "Make meals simpler"
    case routine = "Find a steady routine"
    case other = "Something else"
    var id: String { rawValue }
    var prompt: String {
        switch self {
        case .strength: return "What would you like Pulse to help you with as you protect your strength?"
        case .meals: return "What would make meals feel simpler for you?"
        case .routine: return "What would make a steady routine easier for you?"
        case .other: return "What would you like Pulse to help you with?"
        }
    }
}

/// One grouped form instead of a route per answer. Metric values stay canonical.
struct OnboardingBasicsView: View {
    @Bindable var vm: OnboardingViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set a starting point.").font(Theme.Fonts.display(30, .extraBold, relativeTo: .largeTitle))
            Text("A few details for estimated nutrition targets. You can change these later.")
                .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
            VStack(spacing: 16) {
                TextField("First name", text: $vm.fullName).textContentType(.givenName)
                    .accessibilityLabel("First name")
                Divider()
                DatePicker("Date of birth", selection: $vm.dob, in: vm.adultDOBRange, displayedComponents: .date)
                HStack {
                    Text("Sex for estimates")
                    Spacer()
                    Picker("Sex for estimates", selection: $vm.sex) {
                        ForEach(BiologicalSex.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden()
                }
                Text("Used only for the nutrition estimate. For non-binary / other, Footing averages the two formula constants.")
                    .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                Picker("Units", selection: $vm.useImperialUnits) {
                    Text("Imperial").tag(true); Text("Metric").tag(false)
                }.pickerStyle(.segmented)
                numberField(vm.useImperialUnits ? "Height (inches)" : "Height (cm)", value: Binding(
                    get: { vm.useImperialUnits ? vm.heightCm / 2.54 : vm.heightCm },
                    set: { vm.heightCm = vm.useImperialUnits ? $0 * 2.54 : $0 }))
                numberField(vm.useImperialUnits ? "Weight (lb)" : "Weight (kg)", value: Binding(
                    get: { vm.useImperialUnits ? vm.weightKg * 2.20462 : vm.weightKg },
                    set: { vm.weightKg = vm.useImperialUnits ? $0 / 2.20462 : $0 }))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity")
                    Picker("Activity", selection: $vm.activityLevel) {
                        ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden()
                }
                HStack {
                    Text("Weight direction")
                    Spacer()
                    Picker("Weight direction", selection: $vm.goal) {
                        ForEach(WeightGoal.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden()
                }
            }
            .font(Theme.Fonts.body(16)).padding(16)
            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
            if !vm.canContinueBasics {
                Text("Enter a name, an adult birth date, height (100–250 cm) and weight (30–300 kg).")
                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
    private func numberField(_ label: String, value: Binding<Double>) -> some View {
        OnboardingNumberField(label: label, value: value).id("\(vm.useImperialUnits)-\(label)")
    }

}

struct OnboardingTargetsView: View {
    @State private var resetID = UUID()
    @Bindable var vm: OnboardingViewModel
    var body: some View {
        Form {
            Section {
                Text("These are starting estimates. Adjust them to suit you or advice from your clinician.")
            }
            Section("Daily targets") {
                target("Calories (kcal)", keyPath: \.calories)
                target("Protein (g)", keyPath: \.proteinG)
                target("Carbs (g)", keyPath: \.carbsG)
                target("Fat (g)", keyPath: \.fatG)
                target("Fiber (g)", keyPath: \.fiberG)
                target("Water (ml)", keyPath: \.waterMlTarget)
            }
            Section {
                Button("Use calculated estimates") { vm.customGoals = nil; resetID = UUID() }
            }
        }
        .navigationTitle("Nutrition targets").navigationBarTitleDisplayMode(.inline)
    }
    private func target(_ label: String, keyPath: WritableKeyPath<CalculatedGoals, Double>) -> some View {
        OnboardingNumberField(label: label, value: Binding(get: { vm.selectedGoals[keyPath: keyPath] }, set: { newValue in
            var goals = vm.selectedGoals
            goals[keyPath: keyPath] = newValue
            vm.customGoals = goals
        })).id("\(resetID)-\(label)")
    }
}

/// Text is the edit buffer: update the draft on each keystroke, including invalid/empty input.
/// A value-based TextField can drop the final edit when its sheet is dismissed before commit.
private struct OnboardingNumberField: View {
    let label: String
    @Binding var value: Double
    @State private var text = ""
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, text: $text)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110)
                .accessibilityLabel(label)
                .onAppear {
                    text = value.isFinite ? value.formatted(.number.grouping(.never).precision(.fractionLength(0...1))) : ""
                }
                .onChange(of: text) { _, draft in
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .decimal
                    value = formatter.number(from: draft)?.doubleValue ?? .nan
                }
        }
    }
}
