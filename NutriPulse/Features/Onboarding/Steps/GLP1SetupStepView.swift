import SwiftUI

struct GLP1SetupStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    // nil until the user answers, so the screen opens as just the question.
    @State private var answered: Bool? = nil

    var body: some View {
        NarratedStepLayout(
            step: 8,
            eyebrow: "Built for this",
            eyebrowGlow: true,
            question: "Are you currently using a GLP-1 medication?",
            subtitle: "It's what NutriPulse was made for — but it works just as well if you're not.",
            onAdvance: onContinue
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    choiceButton("Yes", isOn: answered == true) { choose(true) }
                    choiceButton("No",  isOn: answered == false) { choose(false) }
                }

                if answered == true {
                    yesContent.transition(.opacity.combined(with: .move(edge: .top)))
                } else if answered == false {
                    noContent.transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.35), value: answered)
        }
        .onAppear { if vm.isOnGLP1 { answered = true } }
    }

    private func choose(_ yes: Bool) {
        answered = yes
        vm.isOnGLP1 = yes
    }

    private func choiceButton(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(isOn ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.surfaceInset,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isOn ? Theme.Colors.primary.opacity(0.55) : .clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
    }

    private var yesContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Medication")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(GLP1Medication.allCases) { med in
                    OnboardingPill(title: med.rawValue, isSelected: vm.glp1Medication == med) {
                        vm.glp1Medication = med
                        vm.glp1DoseMg = med.availableDoses.first ?? 0.5
                    }
                }
            }

            sectionLabel("Weekly dose")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(vm.glp1Medication.availableDoses, id: \.self) { dose in
                    OnboardingPill(title: String(format: "%.2g mg", dose), isSelected: vm.glp1DoseMg == dose) {
                        vm.glp1DoseMg = dose
                    }
                }
            }

            sectionLabel("Last dose")
            DatePicker("Last dose", selection: $vm.glp1LastInjected, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            infoNote("When your appetite drops, protein protects your muscle. I'll watch your **protein floor** for you.")

            Text("Pulse coaches around your shot — it doesn't advise on dosing and isn't medical advice. Always follow your doctor.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.Colors.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noContent: some View {
        infoNote("All good — I'll coach your protein, movement, and habits just the same. You can add a medication later in Profile if that changes.")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(Theme.Colors.textFaint)
    }

    private func infoNote(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.primary)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
