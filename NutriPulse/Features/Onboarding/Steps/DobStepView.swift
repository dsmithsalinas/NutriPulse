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
        OnboardingStepLayout(
            step: 3,
            title: "Date of birth",
            subtitle: "Age factors into your daily calorie target.",
            onContinue: onContinue
        ) {
            // SWIFT CONCEPT — DatePicker(.graphical) renders a full calendar.
            // Binding(get:set:) creates a two-way connection to vm.dob.
            DatePicker(
                "Date of birth",
                selection: $vm.dob,
                in: dobRange,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }
}
