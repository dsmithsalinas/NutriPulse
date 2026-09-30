import SwiftUI

// SWIFT CONCEPT — @Environment reads a value injected by an ancestor view's .environment().
// This is SwiftUI's equivalent of React's useContext() — no prop drilling needed.
// The type (AppState.self) acts as the key that uniquely identifies which value to pull.

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if AppStoreScreenshotMode.active {
                storeScreenshotPreview
            } else if isStrongWeekPreview {
                strongWeekPreview
            } else if isWaterPickerPreview {
                waterPickerPreview
            } else if isLogSheetPreview {
                logSheetPreview
            } else if isShotDayPreview {
                shotDayPreview
            } else if isProfilePreview {
                profilePreview
            } else if isGoalBuilderPreview {
                CreateGoalView(
                    vm: GoalsViewModel(),
                    initialDraft: GoalDraft(template: .protein)
                )
            } else if isGoalsPreview {
                GoalsView()
            } else if isProgressPreview {
                MainTabView()
            } else if appState.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.isPasswordRecoveryFlow {
                ResetPasswordView()
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
            if !isStrongWeekPreview && !AppStoreScreenshotMode.active { await appState.startObservingAuth() }
        }
    }

    @ViewBuilder private var storeScreenshotPreview: some View {
        #if DEBUG
        AppStoreScreenshotPreview()
        #else
        EmptyView()
        #endif
    }

    private var isStrongWeekPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--strong-week-preview")
        #else
        false
        #endif
    }

    @ViewBuilder private var strongWeekPreview: some View {
        #if DEBUG
        StrongWeekPreview()
        #else
        EmptyView()
        #endif
    }

    private var isWaterPickerPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--water-preview")
        #else
        false
        #endif
    }

    @ViewBuilder private var waterPickerPreview: some View {
        #if DEBUG
        WaterPickerPreview()
        #else
        EmptyView()
        #endif
    }

    // `--log-preview`: the Log sheet, interactive, with no account (lists show empty states).
    private var isLogSheetPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--log-preview")
        #else
        false
        #endif
    }

    @ViewBuilder private var logSheetPreview: some View {
        #if DEBUG
        FoodLoggingView(selectedDate: .now)
        #else
        EmptyView()
        #endif
    }

    // `--shot-preview`: the Shot day screen after a sample dose a week ago (saving needs an account).
    private var isShotDayPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--shot-preview")
        #else
        false
        #endif
    }

    @ViewBuilder private var shotDayPreview: some View {
        #if DEBUG
        let lastShot = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        InjectionRitualView(latest: GLP1Log(
            id: UUID(), userId: UUID(), injectedAt: lastShot, medication: "Zepbound", doseMg: 5,
            site: "Left Abdomen", nextDueAt: .now
        )) { _ in }
        #else
        EmptyView()
        #endif
    }

    // `--profile-preview`: Profile from fixtures (ProfileView.preview()), no account or network.
    private var isProfilePreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--profile-preview")
        #else
        false
        #endif
    }

    @ViewBuilder private var profilePreview: some View {
        #if DEBUG
        ProfileView.preview()
        #else
        EmptyView()
        #endif
    }

    private var isGoalsPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--goals-preview")
        #else
        false
        #endif
    }

    private var isGoalBuilderPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--goal-builder-preview")
        #else
        false
        #endif
    }

    private var isProgressPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--progress-preview")
            || ProcessInfo.processInfo.arguments.contains("--pulse-preview")
        #else
        false
        #endif
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
