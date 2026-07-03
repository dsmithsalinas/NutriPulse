import UIKit

// SwiftUI synthesises an AppDelegate automatically, but its async handling of
// handleEventsForBackgroundURLSession crashes when the Supabase SDK registers
// a background URLSession. Providing a real AppDelegate takes over that slot.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Supabase uses background URLSessions for auth token refresh.
        // Calling the completionHandler immediately tells iOS we've acknowledged
        // the events; Supabase's URLSession delegate handles the actual work.
        completionHandler()
    }
}
