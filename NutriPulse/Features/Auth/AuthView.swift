import SwiftUI
import AuthenticationServices

// The first screen most people ever see (docs/daylight-redesign.md): the same ground, wordmark,
// and Pulse mark as onboarding's splash, so sign-in reads as the front door of one connected
// experience rather than a bolted-on login form.
struct AuthView: View {
    @State private var vm = AuthViewModel()
    @State private var showForgotPassword = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: 40)

                OnboardingPulseAvatar(size: 84)
                    .popIn(order: 0)

                VStack(spacing: 4) {
                    Text("Footing")
                        .font(Theme.Fonts.display(34, .extraBold, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("Coached, not scolded.")
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .popIn(order: 1)

                Spacer(minLength: 24)

                VStack(spacing: Theme.Spacing.sm) {
                    daylightField(isFocused: focusedField == .email) {
                        TextField("Email", text: $vm.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                            .focused($focusedField, equals: .email)
                    }

                    daylightField(isFocused: focusedField == .password) {
                        SecureField("Password", text: $vm.password)
                            .textContentType(vm.isSignUp ? .newPassword : .password)
                            .focused($focusedField, equals: .password)
                    }

                    if !vm.isSignUp {
                        Button("Forgot password?") {
                            showForgotPassword = true
                        }
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(minHeight: 44, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .popIn(order: 2)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button {
                        focusedField = nil
                        Task { await vm.submitEmail() }
                    } label: {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(vm.isSignUp ? "Create Account" : "Sign In")
                        }
                    }
                    .buttonStyle(.daylightPrimary)
                    .disabled(vm.isLoading || vm.email.isEmpty || vm.password.isEmpty)

                    // SWIFT CONCEPT — SignInWithAppleButton is a first-party SwiftUI view from
                    // AuthenticationServices. The .onCompletion closure receives
                    // Result<ASAuthorization,Error> — Swift's Result type is like Promise
                    // resolve/reject in a single enum. Its own styling is Apple's, required as-is;
                    // only the frame/corner radius around it are ours.
                    SignInWithAppleButton(vm.isSignUp ? .signUp : .signIn) { request in
                        vm.prepareAppleRequest(request)
                    } onCompletion: { result in
                        Task { await vm.handleAppleSignIn(result: result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .popIn(order: 3)

                Button {
                    vm.isSignUp.toggle()
                    vm.errorMessage = nil
                } label: {
                    Text(vm.isSignUp ? "Already have an account? Sign in" : "New here? Create account")
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(minHeight: 44)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.Spacing.page)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.ground.ignoresSafeArea())
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(initialEmail: vm.email)
        }
    }

    /// The Daylight text-field shell — a white rounded field with a hairline, indigo when
    /// focused — wrapping whichever field content is passed in.
    private func daylightField<Content: View>(isFocused: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .font(Theme.Fonts.body(16))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isFocused ? Theme.Colors.primary : Theme.Colors.hairline,
                                  lineWidth: isFocused ? 2 : 1)
            }
    }
}
