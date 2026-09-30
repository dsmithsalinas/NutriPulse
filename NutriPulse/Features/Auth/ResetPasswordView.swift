import SwiftUI

struct ResetPasswordView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = PasswordRecoveryViewModel()

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            OnboardingPulseAvatar(size: 72)

            Image(systemName: vm.passwordUpdated ? "checkmark.circle.fill" : "lock.rotation")
                .font(.system(size: 40))
                .foregroundStyle(vm.passwordUpdated ? Theme.Colors.limeLine : Theme.Colors.primary)

            Text(vm.passwordUpdated ? "Password updated" : "Choose a new password")
                .font(Theme.Fonts.display(24, .bold, relativeTo: .title2))
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if vm.passwordUpdated {
                Text("You can continue using Footing with your new password.")
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Button("Continue") {
                    appState.finishPasswordRecovery()
                }
                .buttonStyle(.brandPrimary)
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    daylightField {
                        SecureField("New password", text: $vm.newPassword)
                            .textContentType(.newPassword)
                    }

                    daylightField {
                        SecureField("Confirm new password", text: $vm.confirmedPassword)
                            .textContentType(.newPassword)
                    }
                }

                Text("Use at least 8 characters.")
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.danger)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await vm.updatePassword() }
                } label: {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Update password")
                    }
                }
                .buttonStyle(.brandPrimary)
                .disabled(
                    vm.isLoading
                        || vm.newPassword.isEmpty
                        || vm.confirmedPassword.isEmpty
                )
            }

            Spacer()
        }
        .padding(Theme.Spacing.page)
        .background(Theme.Colors.ground.ignoresSafeArea())
    }

    /// The Daylight text-field shell — a white rounded field with a hairline.
    private func daylightField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(Theme.Fonts.body(16))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
            }
    }
}
