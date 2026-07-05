import SwiftUI

struct ActivityStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepLayout(
            step: 5,
            title: "Activity level",
            subtitle: "How active are you on a typical week?",
            onContinue: onContinue
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(ActivityLevel.allCases) { level in
                    ActivityCard(level: level, isSelected: vm.activityLevel == level) {
                        vm.activityLevel = level
                    }
                }
            }
        }
    }
}

private struct ActivityCard: View {
    let level: ActivityLevel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Theme.Colors.primary : .primary)
                    Text(level.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.Colors.primary : Color.secondary)
                    .font(.title3)
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
