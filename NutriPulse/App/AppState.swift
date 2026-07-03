import Observation
import Supabase

// SWIFT CONCEPT — @Observable (iOS 17, Observation framework) is the modern replacement
// for ObservableObject + @Published. Any view that reads a property automatically
// re-renders when that property changes — no manual @Published annotations needed.
//
// @MainActor pins all methods and property mutations to the main thread, which is
// required for UI updates. Think of it as "every method runs in the main queue dispatch."

@Observable
@MainActor
final class AppState {
    var session: Session? = nil
    var isLoading = true

    var isAuthenticated: Bool { session != nil }

    // Subscribes to Supabase auth state changes as an AsyncStream.
    // Called from RootView.task{} so it runs for the lifetime of the root view.
    func startObservingAuth() async {
        for await (_, session) in supabase.auth.authStateChanges {
            self.session = session
            self.isLoading = false
        }
    }
}
