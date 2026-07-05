import SwiftUI

struct GoalStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepLayout(
            step: 6,
            title: "Your goal",
            subtitle: "This adjusts your daily calorie target.",
            onContinue: onContinue
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(WeightGoal.allCases) { goal in
                    GoalCard(goal: goal, isSelected: vm.goal == goal) {
                        vm.goal = goal
                    }
                }
            }
        }
    }
}

private struct GoalCard: View {
    let goal: WeightGoal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.Colors.primary : .secondary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.displayName)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Theme.Colors.primary : .primary)
                    Text(goal.detail)
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
