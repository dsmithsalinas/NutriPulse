import SwiftUI

struct ResetPasswordView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = PasswordRecoveryViewModel()

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: vm.passwordUpdated ? "checkmark.circle.fill" : "lock.rotation")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.primary)

            Text(vm.passwordUpdated ? "Password updated" : "Choose a new password")
                .font(.title2.bold())

            if vm.passwordUpdated {
                Text("You can continue using Footing with your new password.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Button("Continue") {
                    appState.finishPasswordRecovery()
                }
                .buttonStyle(.brandPrimary)
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    SecureField("New password", text: $vm.newPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("Confirm new password", text: $vm.confirmedPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("Use at least 8 characters.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
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
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.ground.ignoresSafeArea())
    }
}
