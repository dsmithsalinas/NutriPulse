import Observation
import AuthenticationServices
import Supabase

@Observable
@MainActor
final class AuthViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String? = nil
    var isSignUp = false

    func submitEmail() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if isSignUp {
                try await supabase.auth.signUp(email: email, password: password)
            } else {
                try await supabase.auth.signIn(email: email, password: password)
            }
            // AppState.startObservingAuth() picks up the new session automatically
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // SWIFT CONCEPT — Apple Sign In uses AuthenticationServices. We get an identity token
    // (a short-lived JWT) from Apple and pass it straight to Supabase, which verifies it
    // and creates/updates the user. The app never sees a password.
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple Sign In credential was invalid."
                return
            }
            try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
