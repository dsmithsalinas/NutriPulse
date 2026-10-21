import SwiftUI
import AuthenticationServices

// The first screen most people ever see (docs/daylight-redesign.md): the same ground, wordmark,
// and approved Cove wordmark, so sign-in reads as the front door of one connected
// experience rather than a bolted-on login form.
struct AuthView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var vm = AuthViewModel()
    @State private var showForgotPassword = false
    @AppStorage("appleDisconnectHelpNeeded") private var appleDisconnectHelpNeeded = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if appleDisconnectHelpNeeded {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Footing account was deleted.").font(Theme.Fonts.body(16, .bold))
                        Text("Finish by disconnecting Footing from Sign in with Apple in your Apple Account settings.")
                            .font(Theme.Fonts.body(14))
                        Link("Open Apple’s instructions", destination: URL(string: "https://support.apple.com/en-us/102571")!)
                        Button("Done") { appleDisconnectHelpNeeded = false }
                    }
                    .foregroundStyle(Theme.Colors.textPrimary).tile()
                }
                Spacer(minLength: 40)

                VStack(spacing: 4) {
                    Image(colorScheme == .dark ? "FootingWordmark-dark" : "FootingWordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 230, height: 100)
                        .accessibilityLabel("Footing")
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
                        .foregroundStyle(Theme.Colors.danger)
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
                    .buttonStyle(.brandPrimary)
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
