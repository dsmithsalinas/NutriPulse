import SwiftUI

struct HeightWeightStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    // Local imperial display state — derived from vm.heightCm / vm.weightKg
    // and synced back via .onChange. The VM always stores metric internally.
    @State private var heightFt: Int    = 5
    @State private var heightIn: Int    = 7
    @State private var weightLbs: Double = 165.0

    var body: some View {
        OnboardingStepLayout(
            step: 4,
            title: "Height & weight",
            subtitle: "Used to calculate your basal metabolic rate.",
            onContinue: onContinue
        ) {
            VStack(spacing: Theme.Spacing.lg) {
                // Unit toggle
                Picker("Units", selection: $vm.useImperialUnits) {
                    Text("Imperial (ft / lbs)").tag(true)
                    Text("Metric (cm / kg)").tag(false)
                }
                .pickerStyle(.segmented)

                // ── Height ───────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Height")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if vm.useImperialUnits {
                        HStack(spacing: Theme.Spacing.md) {
                            StepperField(
                                label: "ft",
                                value: $heightFt,
                                range: 4...8
                            )
                            StepperField(
                                label: "in",
                                value: $heightIn,
                                range: 0...11
                            )
                        }
                        .onChange(of: heightFt) { _, ft in
                            updateHeight(feet: ft, inches: heightIn)
                        }
                        .onChange(of: heightIn) { _, inches in
                            updateHeight(feet: heightFt, inches: inches)
                        }
                    } else {
                        MetricStepperField(
                            label: "cm",
                            value: $vm.heightCm,
                            range: 100...250,
                            step: 1,
                            format: "%.0f"
                        )
                    }
                }

                // ── Weight ───────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Weight")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if vm.useImperialUnits {
                        DoubleStepperField(
                            label: "lbs",
                            value: $weightLbs,
                            range: 50...700,
                            step: 1
                        )
                        .onChange(of: weightLbs) { _, lbs in
                            updateWeight(pounds: lbs)
                        }
                    } else {
                        MetricStepperField(
                            label: "kg",
                            value: $vm.weightKg,
                            range: 30...300,
                            step: 0.5,
                            format: "%.1f"
                        )
                    }
                }
            }
        }
        .onAppear { syncImperialFromVM() }
        // Re-sync when the user switches unit systems
        .onChange(of: vm.useImperialUnits) { _, _ in syncImperialFromVM() }
    }

    // Round the TOTAL inches, then split. Flooring the feet and separately rounding the
    // remainder produced "5 ft 12 in" for 182 cm (71.65 in → 5 ft + 11.65 → rounds to 12).
    // The 0...11 range only constrains stepper taps, not programmatic writes, so the
    // impossible value stuck — and one tap on the ft stepper then wrote
    // (6 × 12 + 12) × 2.54 = 213.4 cm.
    private func syncImperialFromVM() {
        let totalInches = UnitSystem.totalInches(fromCm: vm.heightCm)
        heightFt  = totalInches / 12
        heightIn  = totalInches % 12
        weightLbs = (vm.weightKg * 2.20462).rounded()
    }

    // These run on every write to heightFt/heightIn — including the programmatic ones from
    // syncImperialFromVM(), which is what made merely switching Metric → Imperial rewrite a
    // height the user entered in centimetres. Convert only when the entered value actually
    // describes a different height than the one we're holding.
    private func updateHeight(feet: Int, inches: Int) {
        let entered = feet * 12 + inches
        guard entered != UnitSystem.totalInches(fromCm: vm.heightCm) else { return }
        vm.heightCm = Double(entered) * 2.54
    }

    private func updateWeight(pounds: Double) {
        guard pounds != (vm.weightKg * 2.20462).rounded() else { return }
        vm.weightKg = pounds / 2.20462
    }
}

// ─── Local helper components ──────────────────────────────────────────────────

// Int-valued stepper with a label (used for ft and in)
private struct StepperField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text("\(value) \(label)")
                .font(.title3.monospacedDigit())
                .frame(minWidth: 60, alignment: .trailing)
            Stepper("", value: $value, in: range)
                .labelsHidden()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// Double-valued stepper (lbs, whole numbers)
private struct DoubleStepperField: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack {
            Text("\(Int(value)) \(label)")
                .font(.title3.monospacedDigit())
                .frame(minWidth: 80, alignment: .trailing)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// Double-valued stepper for metric fields (cm, kg)
private struct MetricStepperField: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        HStack {
            Text(String(format: "\(format) \(label)", value))
                .font(.title3.monospacedDigit())
                .frame(minWidth: 80, alignment: .trailing)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
