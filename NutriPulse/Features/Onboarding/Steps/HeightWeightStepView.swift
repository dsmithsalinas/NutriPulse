import SwiftUI

struct HeightWeightStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    // Imperial display state — total inches + pounds. The VM always stores metric internally;
    // these are re-synced from it on appear and whenever the unit system changes.
    @State private var heightInches = 67
    @State private var weightLbs = 165.0

    var body: some View {
        NarratedStepLayout(
            step: 4,
            question: "Your height and weight",
            subtitle: "Used to set your metabolic rate — nothing here is shared.",
            onAdvance: onContinue
        ) {
            VStack(spacing: 12) {
                OnboardingSegmented(options: ["Imperial", "Metric"], selection: unitBinding)

                if vm.useImperialUnits {
                    MeasureField(label: "Height", value: formatImperialHeight(heightInches),
                                 onMinus: { setInches(heightInches - 1) },
                                 onPlus:  { setInches(heightInches + 1) })
                    MeasureField(label: "Weight", value: "\(Int(weightLbs)) lb",
                                 onMinus: { setPounds(weightLbs - 1) },
                                 onPlus:  { setPounds(weightLbs + 1) })
                } else {
                    MeasureField(label: "Height", value: "\(Int(vm.heightCm)) cm",
                                 onMinus: { vm.heightCm = max(100, vm.heightCm - 1) },
                                 onPlus:  { vm.heightCm = min(250, vm.heightCm + 1) })
                    MeasureField(label: "Weight", value: String(format: "%.1f kg", vm.weightKg),
                                 onMinus: { vm.weightKg = max(30, vm.weightKg - 0.5) },
                                 onPlus:  { vm.weightKg = min(300, vm.weightKg + 0.5) })
                }
            }
        }
        .onAppear(perform: syncImperialFromVM)
        .onChange(of: vm.useImperialUnits) { _, _ in syncImperialFromVM() }
    }

    private var unitBinding: Binding<Int> {
        Binding(get: { vm.useImperialUnits ? 0 : 1 },
                set: { vm.useImperialUnits = ($0 == 0) })
    }

    private func syncImperialFromVM() {
        heightInches = UnitSystem.totalInches(fromCm: vm.heightCm)
        weightLbs = (vm.weightKg * 2.20462).rounded()
    }

    private func setInches(_ v: Int) {
        heightInches = min(96, max(48, v))
        vm.heightCm = Double(heightInches) * 2.54
    }

    private func setPounds(_ v: Double) {
        weightLbs = min(700, max(70, v))
        vm.weightKg = weightLbs / 2.20462
    }

    private func formatImperialHeight(_ inches: Int) -> String {
        "\(inches / 12)′ \(inches % 12)″"
    }
}

// A labelled value with a compact −/+ control that fits the row — replaces the two
// side-by-side native steppers that used to overflow the screen edge.
private struct MeasureField: View {
    let label: String
    let value: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
            }
            Spacer(minLength: 6)
            HStack(spacing: 0) {
                Button(action: onMinus) {
                    Image(systemName: "minus").frame(width: 40, height: 38)
                }
                Divider().frame(height: 20)
                Button(action: onPlus) {
                    Image(systemName: "plus").frame(width: 40, height: 38)
                }
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.primary)
            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .padding(14)
        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
