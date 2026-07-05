import Foundation
import Supabase

struct FeedbackRepository {
    func submit(category: FeedbackCategory, message: String) async throws {
        let userId = try await supabase.auth.session.user.id
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let buildNumber  = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let appVersion = [shortVersion, buildNumber.map { "(\($0))" }]
            .compactMap { $0 }
            .joined(separator: " ")

        let newFeedback = NewFeedback(
            userId: userId,
            category: category.rawValue,
            message: message,
            appVersion: appVersion.isEmpty ? nil : appVersion
        )
        try await supabase.from("feedback").insert(newFeedback).execute()
        await Telemetry.feedbackSubmitted(category: category)
    }
}
