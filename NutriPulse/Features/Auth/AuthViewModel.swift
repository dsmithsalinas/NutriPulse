import Observation
import AuthenticationServices
import CryptoKit
import Supabase

@Observable
@MainActor
final class AuthViewModel {
    // Apple hands over the user's name ONLY on the very first authorization, ever — never
    // again, not even after deleting and reinstalling the app. It was read off the credential
    // and thrown away. Stash it so onboarding can pre-fill the name step; onboarding clears it.
    static let pendingAppleFullNameKey = "pendingAppleFullName"

    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String? = nil
    var isSignUp = false

    // The raw nonce for the in-flight Apple request. Apple signs the SHA-256 of this into the
    // identity token; Supabase re-hashes the raw value we pass to signInWithIdToken and
    // rejects the token unless they match. That binding is what stops a captured identity
    // token from being replayed into a session from another device. Held between the request
    // closure and the completion handler, cleared after use.
    private var currentNonce: String?

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

    // Called from the SignInWithAppleButton request closure: generate a fresh nonce, send its
    // hash to Apple, and keep the raw value for the token exchange.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
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
            guard let nonce = currentNonce else {
                // No nonce means the request wasn't started through prepareAppleRequest;
                // exchanging the token without it would silently drop replay protection.
                errorMessage = "Apple Sign In couldn't start securely. Please try again."
                return
            }
            // Capture the name BEFORE the network call — it's on this credential and will
            // never appear on another one.
            if let nameComponents = credential.fullName {
                let name = PersonNameComponentsFormatter.localizedString(
                    from: nameComponents, style: .default
                ).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    UserDefaults.standard.set(name, forKey: Self.pendingAppleFullNameKey)
                }
            }

            try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            currentNonce = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Nonce helpers

    // Cryptographically-random nonce. A SecRandomCopyBytes failure is unrecoverable and would
    // mean signing in without replay protection, so it's a hard stop rather than a fallback.
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            fatalError("SecRandomCopyBytes failed with OSStatus \(status)")
        }
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
