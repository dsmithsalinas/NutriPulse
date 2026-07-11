import SwiftUI

// ─── Step route enum ─────────────────────────────────────────────────────────
// Each case is pushed onto the NavigationStack path as the user progresses.
// SWIFT CONCEPT — NavigationStack(path:) is the iOS 16+ equivalent of a router.
// Push a value onto `path` to navigate forward; pop it to go back.
// .navigationDestination(for:) maps each route to the view that renders it.
enum OnboardingRoute: Hashable {
    case name, sex, dob, heightWeight, activity, goal, healthKit, glp1, summary
}

// ─── Top-level shell ─────────────────────────────────────────────────────────
struct OnboardingView: View {
    @State private var vm = OnboardingViewModel()
    @State private var path: [OnboardingRoute] = []
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack(path: $path) {
            // Root = the splash where Pulse introduces itself, then push into the questions.
            OnboardingSplashView { path.append(.name) }
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .name:
                        NameStepView(vm: vm) { path.append(.sex) }
                    case .sex:
                        BiologicalSexStepView(vm: vm) { path.append(.dob) }
                    case .dob:
                        DobStepView(vm: vm) { path.append(.heightWeight) }
                    case .heightWeight:
                        HeightWeightStepView(vm: vm) { path.append(.activity) }
                    case .activity:
                        ActivityStepView(vm: vm) { path.append(.goal) }
                    case .goal:
                        GoalStepView(vm: vm) { path.append(.healthKit) }
                    case .healthKit:
                        HealthKitStepView { path.append(.glp1) }
                    case .glp1:
                        GLP1SetupStepView(vm: vm) { path.append(.summary) }
                    case .summary:
                        SummaryStepView(vm: vm, onComplete: handleSave)
                    }
                }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private func handleSave() {
        Task {
            guard let userId = appState.session?.user.id else {
                vm.errorMessage = "Session expired. Please sign in again."
                return
            }
            do {
                // save() returns the persisted profile, so we apply it directly rather
                // than re-fetching. A failed re-fetch used to leave needsOnboarding true
                // even though the save succeeded, pushing the user into a retry loop.
                // Updating the profile re-evaluates AppState.needsOnboarding → RootView
                // switches to MainTabView automatically.
                let savedProfile = try await vm.save(userId: userId)
                appState.setProfile(savedProfile)
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        }
    }
}

// ─── Shared step container ───────────────────────────────────────────────────
// Used by every step view — provides progress dots, title, and the Continue button.
// SWIFT CONCEPT — a generic view with @ViewBuilder lets callers pass any SwiftUI
// content as a trailing closure, the same way HStack/VStack accept their children.
struct OnboardingStepLayout<Content: View>: View {
    let step: Int                        // 1-based, out of `totalSteps` (9)
    let title: String
    let subtitle: String
    var continueLabel: String = "Continue"
    var canContinue: Bool = true
    let onContinue: () -> Void
    @ViewBuilder let content: Content    // trailing closure filled in by each step

    private let totalSteps = 9

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                progressDots
                    .padding(.top, Theme.Spacing.sm)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(.largeTitle.bold())
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                content
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, 100)   // leave room for the floating button
        }
        .safeAreaInset(edge: .bottom) { continueButton }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(1...totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Theme.Colors.primary : Color(.systemFill))
                    .frame(width: i == step ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
    }

    private var continueButton: some View {
        Button(continueLabel, action: onContinue)
            .buttonStyle(.brandPrimary)
            .disabled(!canContinue)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)
            .background(.bar)
    }
}
