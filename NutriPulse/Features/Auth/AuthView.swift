import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @State private var vm = AuthViewModel()

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.Colors.primaryGradient)

            Text("NutriPulse")
                .font(.largeTitle.bold())

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                TextField("Email", text: $vm.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $vm.password)
                    .textContentType(vm.isSignUp ? .newPassword : .password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
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
            // AuthenticationServices. The .onCompletion closure receives Result<ASAuthorization,Error>
            // — Swift's Result type is like Promise resolve/reject in a single enum.
            SignInWithAppleButton(vm.isSignUp ? .signUp : .signIn) { request in
                vm.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { await vm.handleAppleSignIn(result: result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                vm.isSignUp.toggle()
                vm.errorMessage = nil
            } label: {
                Text(vm.isSignUp ? "Already have an account? Sign in" : "New here? Create account")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
    }
}
