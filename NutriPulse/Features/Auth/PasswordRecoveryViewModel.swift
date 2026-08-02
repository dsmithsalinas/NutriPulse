import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class PasswordRecoveryViewModel {
    var email = ""
    var newPassword = ""
    var confirmedPassword = ""
    var isLoading = false
    var emailSent = false
    var passwordUpdated = false
    var errorMessage: String?

    private static let redirectURL = URL(string: "footing://reset-password")!

    nonisolated static func passwordValidationError(
        password: String,
        confirmation: String
    ) -> String? {
        if password.count < 8 {
            return "Use at least 8 characters."
        }
        if password != confirmation {
            return "Those passwords don't match."
        }
        return nil
    }

    func requestReset() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Enter the email address you use for Footing."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.auth.resetPasswordForEmail(
                trimmedEmail,
                redirectTo: Self.redirectURL
            )
            // Keep this neutral so the screen never confirms whether an address
            // belongs to an account.
            emailSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePassword() async {
        if let validationError = Self.passwordValidationError(
            password: newPassword,
            confirmation: confirmedPassword
        ) {
            errorMessage = validationError
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            passwordUpdated = true
            newPassword = ""
            confirmedPassword = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
