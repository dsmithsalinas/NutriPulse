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
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set a starting point.").font(Theme.Fonts.display(30, .extraBold, relativeTo: .largeTitle))
            Text("A few details for estimated nutrition targets. You can change these later.")
                .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
            VStack(alignment: .leading, spacing: 16) {
                TextField("First name", text: $vm.fullName).textContentType(.givenName)
                    .accessibilityLabel("First name")
                Divider()
                DatePicker("Date of birth", selection: $vm.dob, in: vm.adultDOBRange, displayedComponents: .date)
                choices("Sex for estimates", options: BiologicalSex.allCases, selection: $vm.sex) { $0.displayName }
                Text("Used only for the nutrition estimate. For non-binary / other, Footing averages the two formula constants.")
                    .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Units").font(Theme.Fonts.body(15, .semibold))
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 8) { unitChoices }
                    } else {
                        HStack(spacing: 8) { unitChoices }
                    }
                }
                if vm.useImperialUnits {
                    OnboardingImperialHeightField(heightCm: $vm.heightCm)
                } else {
                    numberField("Height (cm)", value: $vm.heightCm)
                }
                numberField(vm.useImperialUnits ? "Weight (lb)" : "Weight (kg)", value: Binding(
                    get: { vm.useImperialUnits ? vm.weightKg * 2.20462 : vm.weightKg },
                    set: { vm.weightKg = vm.useImperialUnits ? $0 / 2.20462 : $0 }))
                choices("Activity", options: ActivityLevel.allCases, selection: $vm.activityLevel) { $0.displayName }
                Text(vm.activityLevel.description)
                    .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                choices("Weight direction", options: WeightGoal.allCases, selection: $vm.goal) { $0.displayName }

            }
            .font(Theme.Fonts.body(16)).padding(16)
            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
            if !vm.canContinueBasics {
                Text(vm.useImperialUnits
                     ? "Enter a name, an adult birth date, height (3 ft 3.4 in–8 ft 2.4 in) and weight (66.2–661.4 lb)."
                     : "Enter a name, an adult birth date, height (100–250 cm) and weight (30–300 kg).")
                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
    @ViewBuilder private var unitChoices: some View {
        unitChoice("Imperial", imperial: true)
        unitChoice("Metric", imperial: false)
    }
    private func unitChoice(_ label: String, imperial: Bool) -> some View {
        Button { vm.useImperialUnits = imperial } label: {
            Text(label).font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(vm.useImperialUnits == imperial ? Theme.Colors.limeInk : Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 12).padding(.vertical, 4)
                .background(vm.useImperialUnits == imperial ? Theme.Colors.lime : Theme.Colors.surfaceInset, in: Capsule())
        }.buttonStyle(.plain)
            .accessibilityAddTraits(vm.useImperialUnits == imperial ? .isSelected : [])
    }

    private func choices<Option: Hashable & Identifiable>(_ title: String, options: [Option], selection: Binding<Option>, label: @escaping (Option) -> String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Theme.Fonts.body(15, .semibold))
            LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                ForEach(options) { option in
                    Button { selection.wrappedValue = option } label: {
                        Text(label(option)).font(Theme.Fonts.body(14, .semibold))
                            .foregroundStyle(selection.wrappedValue == option ? Theme.Colors.limeInk : Theme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 12).padding(.vertical, 4)
                            .background(selection.wrappedValue == option ? Theme.Colors.lime : Theme.Colors.surfaceInset, in: Capsule())
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding-\(title)-\(option.id)")
                        .accessibilityAddTraits(selection.wrappedValue == option ? .isSelected : [])
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func numberField(_ label: String, value: Binding<Double>) -> some View {
        OnboardingNumberField(label: label, value: value).id("\(vm.useImperialUnits)-\(label)")
    }

}

/// Keep each component's edit buffer independent so clearing feet does not erase inches.
/// Only complete, valid components update the canonical centimeter value.
private struct OnboardingImperialHeightField: View {
    @Binding var heightCm: Double
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var feet = ""
    @State private var inches = ""
    init(heightCm: Binding<Double>) {
        _heightCm = heightCm
        let total = heightCm.wrappedValue.isFinite ? (heightCm.wrappedValue / 2.54 * 10).rounded() / 10 : .nan
        _feet = State(initialValue: total.isFinite ? String(Int(total / 12)) : "")
        _inches = State(initialValue: total.isFinite ? total.truncatingRemainder(dividingBy: 12).formatted(.number.grouping(.never).precision(.fractionLength(0...1))) : "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Height").font(Theme.Fonts.body(15, .semibold))
            if typeSize.isAccessibilitySize {
                VStack(spacing: 12) { components }
            } else {
                HStack(spacing: 12) { components }
            }
        }
        .onChange(of: feet) { _, _ in updateHeight() }
        .onChange(of: inches) { _, _ in updateHeight() }
    }
    @ViewBuilder private var components: some View {
        component("Feet", text: $feet, keyboard: .numberPad)
        component("Inches", text: $inches, keyboard: .decimalPad)
    }
    private func component(_ label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack {
            TextField(label, text: text).keyboardType(keyboard)
                .accessibilityLabel("Height \(label.lowercased())")
                .accessibilityIdentifier("onboarding-height-\(label.lowercased())")
            Text(label.lowercased()).foregroundStyle(Theme.Colors.textSecondary)
        }.padding(12).background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12))
    }
    private func updateHeight() {
        let formatter = NumberFormatter(); formatter.numberStyle = .decimal
        guard let f = formatter.number(from: feet)?.doubleValue, f.isFinite, f == f.rounded(), (0...8).contains(f),
              let i = formatter.number(from: inches)?.doubleValue, i.isFinite, (0..<12).contains(i) else {
            heightCm = .nan; return
        }
        heightCm = (f * 12 + i) * 2.54
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
        .daylightReadableWidth(600)
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
