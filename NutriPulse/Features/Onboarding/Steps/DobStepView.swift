import SwiftUI

struct DobStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    // Limit picker to ages 13–120
    private var dobRange: ClosedRange<Date> {
        let cal = Calendar.current
        let oldest  = cal.date(byAdding: .year, value: -120, to: .now) ?? .now
        let youngest = cal.date(byAdding: .year, value: -13, to: .now) ?? .now
        return oldest...youngest
    }

    var body: some View {
        NarratedStepLayout(
            step: 3,
            question: "When were you born?",
            subtitle: "Age factors into your daily calorie target.",
            onAdvance: onContinue
        ) {
            DatePicker(
                "Date of birth",
                selection: $vm.dob,
                in: dobRange,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
