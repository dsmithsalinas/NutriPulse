import SwiftUI

// A Daylight sheet like PulseConsentSheet/AboutYouView: SheetHeader, white tiles on the cool
// neutral ground, one indigo primary action.
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = PasswordRecoveryViewModel()
    let initialEmail: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SheetHeader(title: "Password help", onClose: { dismiss() })

                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: vm.emailSent ? "envelope.badge.fill" : "key.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Theme.Colors.primary)

                    Text(vm.emailSent ? "Check your email" : "Reset your password")
                        .font(Theme.Fonts.display(22, .bold, relativeTo: .title2))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text(vm.emailSent
                        ? "If an account exists for that address, we've sent a password-reset link."
                        : "Enter the email address you use for Footing.")
                        .font(Theme.Fonts.body(14))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    if !vm.emailSent {
                        TextField("Email", text: $vm.email)
                            .font(Theme.Fonts.body(16))
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
                            }

                        if let error = vm.errorMessage {
                            Text(error)
                                .font(Theme.Fonts.body(13))
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
                        .buttonStyle(.daylightPrimary)
                        .disabled(vm.isLoading || vm.email.isEmpty)
                    } else {
                        Button("Done") { dismiss() }
                            .buttonStyle(.daylightPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(Theme.Spacing.page)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .onAppear {
            if vm.email.isEmpty {
                vm.email = initialEmail
            }
        }
    }
}
