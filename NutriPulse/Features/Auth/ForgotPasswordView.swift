import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = PasswordRecoveryViewModel()
    let initialEmail: String

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: vm.emailSent ? "envelope.badge.fill" : "key.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.Colors.primary)

                Text(vm.emailSent ? "Check your email" : "Reset your password")
                    .font(.title2.bold())

                Text(vm.emailSent
                    ? "If an account exists for that address, we've sent a password-reset link."
                    : "Enter the email address you use for Footing.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                if !vm.emailSent {
                    TextField("Email", text: $vm.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await vm.requestReset() }
                    } label: {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Send reset link")
                        }
                    }
                    .buttonStyle(.brandPrimary)
                    .disabled(vm.isLoading || vm.email.isEmpty)
                } else {
                    Button("Done") { dismiss() }
                        .buttonStyle(.brandPrimary)
                }

                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .navigationTitle("Password help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if vm.email.isEmpty {
                    vm.email = initialEmail
                }
            }
        }
    }
}
