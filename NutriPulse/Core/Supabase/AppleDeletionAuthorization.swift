import AuthenticationServices
import UIKit

// A fresh authorization code supports existing accounts without storing Apple refresh tokens.
// This authorization never signs a different person into Supabase or changes the active user.
@MainActor
final class AppleDeletionAuthorization: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<String, Error>?
    private var controller: ASAuthorizationController?
    private var anchor: ASPresentationAnchor?

    func authorizationCode() async throws -> String {
        guard continuation == nil else { throw URLError(.requestBodyStreamExhausted) }
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { throw URLError(.cannotLoadFromNetwork) }
        anchor = window
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self; controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Held strongly from before performRequests until completion.
        anchor!
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.authorizationCode,
              let code = String(data: data, encoding: .utf8), !code.isEmpty else {
            finish(.failure(URLError(.userAuthenticationRequired))); return
        }
        finish(.success(code))
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(.failure(error))
    }
    private func finish(_ result: Result<String, Error>) {
        let pending = continuation
        continuation = nil; controller = nil; anchor = nil
        pending?.resume(with: result)
    }
}
