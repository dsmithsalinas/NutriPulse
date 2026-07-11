import SwiftUI

struct ActivityStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        NarratedStepLayout(
            step: 5,
            question: "How active are you, day to day?",
            subtitle: "Roughly — I'll refine it from your Health data later.",
            onAdvance: onContinue
        ) {
            VStack(spacing: 10) {
                ForEach(ActivityLevel.allCases) { level in
                    OnboardingOptionCard(
                        title: level.displayName,
                        detail: detail(for: level),
                        isSelected: vm.activityLevel == level
                    ) {
                        vm.activityLevel = level
                    }
                }
            }
        }
    }

    // Concrete, example-led descriptions so a user can place themselves without guessing.
    private func detail(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary:  return "Desk job, mostly sitting. Errands and the occasional short walk."
        case .light:      return "On your feet a fair bit, or 1–3 light workouts a week (walks, easy gym, yoga)."
        case .moderate:   return "3–5 solid workouts a week, or an on-your-feet job (nurse, server, trades)."
        case .active:     return "Hard training 6–7 days a week, or a consistently physical job."
        case .veryActive: return "Daily training, competitive sport, or heavy labor (construction, moving)."
        }
    }
}
