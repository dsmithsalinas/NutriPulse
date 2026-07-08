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
            } else if appState.profileLoadFailed {
                // We're signed in but couldn't load the profile (offline, 5xx). Showing
                // onboarding here would be a lie — and re-running it corrupts the user's
                // data. Ask to retry instead.
                ProfileLoadFailedView()
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

// Shown when we're authenticated but the profile fetch failed. Deliberately offers
// a retry (and a way out) rather than silently routing into onboarding.
private struct ProfileLoadFailedView: View {
    @Environment(AppState.self) private var appState
    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Couldn't load your profile")
                .font(.headline)
            Text("Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    isRetrying = true
                    await appState.fetchProfile()
                    isRetrying = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRetrying)

            Button("Sign Out") {
                Task { try? await supabase.auth.signOut() }
            }
            .font(.footnote)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
