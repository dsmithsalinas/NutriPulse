import SwiftUI

struct GoalStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        NarratedStepLayout(
            step: 6,
            question: "What are we working toward?",
            subtitle: "You can change this anytime.",
            onAdvance: onContinue
        ) {
            VStack(spacing: 10) {
                ForEach(WeightGoal.allCases) { goal in
                    OnboardingOptionCard(
                        title: goal.displayName,
                        detail: goal.detail,
                        isSelected: vm.goal == goal
                    ) {
                        vm.goal = goal
                    }
                }
            }
        }
    }
}
