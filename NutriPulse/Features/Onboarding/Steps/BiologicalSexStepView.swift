import SwiftUI

struct BiologicalSexStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepLayout(
            step: 2,
            title: "Biological sex",
            subtitle: "Used only for BMR calculation — your entries stay private.",
            onContinue: onContinue
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(BiologicalSex.allCases) { option in
                    SexCard(option: option, isSelected: vm.sex == option) {
                        vm.sex = option
                    }
                }
            }
        }
    }
}

private struct SexCard: View {
    let option: BiologicalSex
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(option.displayName)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.Colors.primary : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.primary)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.quaternary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isSelected ? Theme.Colors.primary : .clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
