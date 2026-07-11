import SwiftUI

struct BiologicalSexStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        NarratedStepLayout(
            step: 2,
            question: "Which best describes you?",
            subtitle: "This tunes your calorie and protein math.",
            onAdvance: onContinue
        ) {
            VStack(spacing: 10) {
                ForEach(BiologicalSex.allCases) { option in
                    OnboardingOptionCard(
                        title: option.displayName,
                        isSelected: vm.sex == option
                    ) {
                        vm.sex = option
                    }
                }
            }
        }
    }
}
