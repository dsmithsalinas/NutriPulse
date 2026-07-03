import SwiftUI

struct NameStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingStepLayout(
            step: 1,
            title: "What's your name?",
            subtitle: "We'll use this to personalise your experience.",
            canContinue: vm.canContinueName,
            onContinue: onContinue
        ) {
            TextField("Full name", text: $vm.fullName)
                .font(.title3)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .autocorrectionDisabled()
                .textContentType(.name)
                .focused($focused)
                // Submit key on the keyboard also moves forward
                .onSubmit { if vm.canContinueName { onContinue() } }
        }
        .onAppear { focused = true }
    }
}
