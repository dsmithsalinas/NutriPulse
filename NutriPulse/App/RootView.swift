import SwiftUI

// SWIFT CONCEPT — @Environment reads a value injected by an ancestor view's .environment().
// This is SwiftUI's equivalent of React's useContext() — no prop drilling needed.
// The type (AppState.self) acts as the key that uniquely identifies which value to pull.

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !appState.isAuthenticated {
                AuthView()
            } else if appState.needsOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        // SWIFT CONCEPT — .task{} is like useEffect in React. It runs an async block
        // when the view appears and automatically cancels it when the view disappears.
        // No manual cleanup needed — Swift's structured concurrency handles it.
        .task {
            await appState.startObservingAuth()
        }
    }
}
