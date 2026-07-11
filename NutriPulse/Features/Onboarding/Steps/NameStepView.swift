import SwiftUI

struct NameStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        NarratedStepLayout(
            step: 1,
            question: "What should I call you?",
            subtitle: "Just your first name is perfect.",
            canAdvance: vm.canContinueName,
            onAdvance: advance
        ) {
            TextField("Your name", text: $vm.fullName)
                .font(.title3)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(focused ? Theme.Colors.primary.opacity(0.55) : .clear, lineWidth: 1.5)
                }
                .autocorrectionDisabled()
                .textContentType(.givenName)
                .submitLabel(.next)
                .focused($focused)
                .onSubmit(advance)
        }
        .onAppear { focused = true }
    }

    private func advance() {
        if vm.canContinueName { onContinue() }
    }
}
