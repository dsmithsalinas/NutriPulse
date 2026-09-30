import SwiftUI

// Step 9 (docs/daylight-redesign.md, step 8): an optional, skippable place to tell Pulse about
// allergies and how you eat before the summary. Loves/avoids and the kitchen situation live in
// AboutYouView, reachable from Profile and Pulse's start screen, after onboarding.
struct PulseAboutYouStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    @State private var newAllergyText = ""

    var body: some View {
        NarratedStepLayout(
            step: 9,
            eyebrow: "Optional",
            question: "Anything Pulse should know?",
            subtitle: "Allergies and how you eat — Pulse keeps suggestions clear of them. You can always change this later.",
            onAdvance: onContinue
        ) {
            VStack(alignment: .leading, spacing: 22) {
                skipButton

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Allergies & intolerances")
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(CommonAllergen.all, id: \.self) { name in
                            allergenChip(name)
                        }
                    }
                    addAllergyField
                    if !CommonAllergen.custom(in: vm.pulseAllergies).isEmpty {
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(CommonAllergen.custom(in: vm.pulseAllergies), id: \.self) { item in
                                removableChip(item) { vm.pulseAllergies.removeAll { $0 == item } }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("How you eat")
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(EatingPattern.allCases) { pattern in
                            patternChip(pattern)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Skip

    private var skipButton: some View {
        Button(action: skip) {
            Text("Skip for now")
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Skips this step without saving anything")
    }

    private func skip() {
        vm.pulseAllergies = []
        vm.pulseAllergyNote = ""
        vm.pulseEatingPatterns = []
        onContinue()
    }

    // MARK: - Allergies

    private var addAllergyField: some View {
        HStack(spacing: 8) {
            TextField("Add another", text: $newAllergyText)
                .font(Theme.Fonts.body(14))
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
                }
                .onSubmit(addAllergy)
                .accessibilityLabel("Add another allergy or intolerance")
            Button(action: addAllergy) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(newAllergyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Add")
        }
    }

    private func addAllergy() {
        let trimmed = newAllergyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !vm.pulseAllergies.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            vm.pulseAllergies.append(trimmed)
        }
        newAllergyText = ""
    }

    private func allergenChip(_ name: String) -> some View {
        let isOn = vm.pulseAllergies.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        return OnboardingPill(title: name, isSelected: isOn) {
            if isOn {
                vm.pulseAllergies.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
            } else {
                vm.pulseAllergies.append(name)
            }
        }
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    // MARK: - Eating patterns

    private func patternChip(_ pattern: EatingPattern) -> some View {
        let isOn = vm.pulseEatingPatterns.contains(pattern)
        return OnboardingPill(title: pattern.label, isSelected: isOn) {
            if isOn { vm.pulseEatingPatterns.remove(pattern) } else { vm.pulseEatingPatterns.insert(pattern) }
        }
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    // MARK: - Shared

    private func removableChip(_ title: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textFaint)
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Remove \(title)")
        }
        .padding(.leading, 12)
        .frame(minHeight: 44)
        .background(Theme.Colors.surfaceInset, in: Capsule())
    }

    private func sectionLabel(_ text: String) -> some View {
        TileEyebrow(text, color: Theme.Colors.textFaint)
    }
}
