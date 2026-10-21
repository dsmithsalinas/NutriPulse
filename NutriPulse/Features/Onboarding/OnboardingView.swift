import SwiftUI

/// Five surfaces: support, optional words, basics, permission, and review.
struct OnboardingView: View {
    @State private var vm = OnboardingViewModel()
    @State private var step = 0
    @State private var showConsent = false
    @State private var editingFocus = false
    @State private var editingTargets = false
    @State private var connectingHealth = false
    @State private var healthMessage: String?
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var debugFixture = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    if step > 0 {
                        Button { step -= 1 } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(Theme.Fonts.body(15))
                                .frame(minHeight: 44)
                        }.disabled(vm.isLoading)
                    }
                    if step > 0 { Spacer() }
                    Image(colorScheme == .dark ? "FootingWordmark-dark" : "FootingWordmark").resizable().scaledToFit().frame(width: 116, height: 44)
                        .accessibilityLabel("Footing")
                    if step == 0 { Spacer() }
                }.padding(.horizontal, Theme.Spacing.page)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch step {
                        case 0: welcome
                        case 1: focusEditor
                        case 2: OnboardingBasicsView(vm: vm)
                        case 3: permission
                        default: ready
                        }
                    }
                    .padding(Theme.Spacing.page)
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxHeight: .infinity)
                .clipped()
                actions
            }
            .tint(Theme.Colors.primary)
            .foregroundStyle(Theme.Colors.textPrimary)
            .background(Theme.Colors.ground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showConsent) {
                if debugFixture {
                    PulseConsentSheet()
                } else {
                    PulseConsentSheet(onAgree: {
                        try await PulseProfileStore.shared.recordConsent(agreed: true)
                        showConsent = false; step = 4
                    }, onDecline: {
                        try await PulseProfileStore.shared.recordConsent(agreed: false)
                        showConsent = false; step = 4
                    })
                }
            }
            .sheet(isPresented: $editingFocus) {
                NavigationStack {
                    ScrollView { focusEditor.padding(Theme.Spacing.page) }
                        .background(Theme.Colors.ground)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { editingFocus = false } } }
                }
            }
            .sheet(isPresented: $editingTargets) {
                NavigationStack {
                    OnboardingTargetsView(vm: vm)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { editingTargets = false } } }
                }
            }
            .alert("Couldn’t finish setup", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
        }
        .onChange(of: appState.session?.user.id) { _, _ in
            vm = OnboardingViewModel(); step = 0; editingFocus = false; editingTargets = false; showConsent = false
        }
        #if DEBUG
        .onAppear {
            guard debugFixture else { return }
            if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--onboarding-step"),
               ProcessInfo.processInfo.arguments.indices.contains(index + 1),
               let value = Int(ProcessInfo.processInfo.arguments[index + 1]) {
                vm.fullName = "Alex"; vm.focusDraft = "Keep meals simple and protect my muscle, especially when I’m busy."
                vm.adultConfirmed = value > 0; vm.previewPulseAllowed = true; step = min(4, max(0, value))
            }
        }
        #endif
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("CoveOnboarding").resizable().scaledToFit()
                .frame(maxWidth: .infinity).frame(height: 170).accessibilityHidden(true)
            heading("What would feel easier?").frame(maxWidth: 300, alignment: .leading)
            helper("Choose where you’d like support.")
            ForEach(OnboardingSupport.allCases) { choice in
                Button { vm.support = choice } label: {
                    HStack(spacing: 12) {
                        Image(systemName: vm.support == choice ? "largecircle.fill.circle" : "circle")
                        Text(choice.rawValue).font(Theme.Fonts.body(16, .semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13))
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(vm.support == choice ? Theme.Colors.lime : Theme.Colors.surfaceCard,
                                in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).accessibilityAddTraits(vm.support == choice ? [.isSelected] : [])
            }
            Toggle("I’m 18 or older", isOn: $vm.adultConfirmed)
                .font(Theme.Fonts.body(15)).tint(Theme.Colors.primary)
            helper("Footing is for adults 18 and over.")
        }
    }

    private var focusEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("Your goal, in your words.")
            helper(vm.support.prompt)
            TextEditor(text: $vm.focusDraft)
                .font(Theme.Fonts.body(17)).scrollContentBackground(.hidden)
                .frame(minHeight: 160).padding(12)
                .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Your goal, in your words")
            Text("\(vm.focusDraft.unicodeScalars.count)/300")
                .font(Theme.Fonts.body(13)).frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(vm.isFocusValid ? Theme.Colors.textSecondary : Theme.Colors.danger)
            helper("A sentence is enough. Nothing goes to AI during setup. You’ll choose whether to save this at the end.")
        }
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Choose Pulse’s help.")
            helper("Pulse is Footing’s optional AI coach. Review what’s shared before choosing.")
            helper("With your permission, Pulse sends your messages and relevant food, goal, health and preference context to Anthropic to write replies. Shot information is included only if you use tracking.")
            Button("What is shared & privacy") { showConsent = true }
                .font(Theme.Fonts.body(15, .semibold)).frame(minHeight: 44)
            helper("You can withdraw this in Profile. AI food logging asks separately at first use.")

        }
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("A starting point that’s yours.")
            if !vm.trimmedFocus.isEmpty {
                Text(vm.trimmedFocus).font(Theme.Fonts.body(18, .semibold)).padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
            }
            Text("Make it yours").font(Theme.Fonts.body(17, .bold))
            VStack(spacing: 0) {
                setupRow("Set nutrition targets", detail: vm.areTargetsValid ? "\(vm.selectedGoals.proteinG.formatted(.number.precision(.fractionLength(0))))g protein · \(vm.selectedGoals.calories.formatted(.number.precision(.fractionLength(0)))) kcal" : "Review your targets", icon: "fork.knife") { editingTargets = true }
                Divider()
                setupRow("Tell Pulse what matters", detail: vm.trimmedFocus.isEmpty ? "Optional · Add a focus" : "Review your focus", icon: "person") { editingFocus = true }
                Divider()
                setupRow("Connect Apple Health", detail: "Optional · Connect when you’re ready", icon: "heart.fill") { connectHealth() }
                    .disabled(connectingHealth)
            }.background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
            if !vm.isFocusValid { helper("Keep your focus to 300 characters, or shorten it in Tell Pulse what matters.") }
            if !vm.areTargetsValid { helper("Review nutrition targets before starting: calories 800–10,000, macros 0–1,500g, and water 250–10,000ml.") }
            if let healthMessage { helper(healthMessage) }
            helper(vm.pulseAllowed(preview: debugFixture)
                   ? "Your focus is saved only if you choose below. You can edit or forget it in What Pulse knows."
                   : "Pulse is off. Your focus won’t be saved or shared. You can turn Pulse on later in Profile.")
            helper("Food preferences and shot tracking can be set up later in Profile.")
            Text("Footing supports wellness; it isn’t a medical device. Pulse isn’t a medical professional. Talk to your clinician about medication and health decisions.")
                .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    @ViewBuilder private var actions: some View {
        if step == 3 {
            VStack(spacing: 8) {
                Button {
                    if debugFixture { vm.previewPulseAllowed = true; step = 4 }
                    else { showConsent = true }
                } label: {
                    Text("Review & allow Pulse").fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center).padding(.vertical, 8)
                }.buttonStyle(.brandPrimary).disabled(vm.isLoading)
                Button("Continue without Pulse") {
                    if debugFixture { vm.previewPulseAllowed = false; step = 4; return }
                    vm.isLoading = true
                    Task {
                        defer { vm.isLoading = false }
                        do { try await PulseProfileStore.shared.recordConsent(agreed: false); step = 4 }
                        catch { vm.errorMessage = "Couldn’t save your choice. Check your connection and try again." }
                    }
                }.frame(minHeight: 44).disabled(vm.isLoading)
            }.font(Theme.Fonts.body(16, .semibold))
                .padding(Theme.Spacing.page).background(Theme.Colors.ground)
        } else {
            VStack(spacing: 8) {
                Button {
                    if step == 4 { finish(saveFocus: vm.canSaveFocus(preview: debugFixture)) }
                    else { step += 1 }
                } label: {
                    if vm.isLoading { ProgressView() }
                    else {
                        Text(step == 4 ? (vm.canSaveFocus(preview: debugFixture) ? "Save focus & start" : "Start with today") : (step == 2 ? "Review my setup" : "Continue"))
                            .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center).padding(.vertical, 8)
                    }
                }
                .buttonStyle(.brandPrimary)
                .disabled(vm.isLoading || (step == 0 && !vm.adultConfirmed) || (step == 1 && !vm.isFocusValid) || (step == 2 && !vm.canContinueBasics) || (step == 4 && (!vm.isFocusValid || !vm.areTargetsValid)))
                if step == 1 {
                    Button("Skip for now") { vm.focusDraft = ""; step = 2 }.frame(minHeight: 44)
                } else if step == 4 && vm.canSaveFocus(preview: debugFixture) {
                    Button("Start without saving focus") { finish(saveFocus: false) }.frame(minHeight: 44).disabled(vm.isLoading || !vm.areTargetsValid)
                }
            }
            .font(Theme.Fonts.body(16, .semibold))
            .padding(.horizontal, Theme.Spacing.page).padding(.vertical, 12)
            .background(Theme.Colors.ground)
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(Theme.Fonts.display(34, .extraBold, relativeTo: .largeTitle))
            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }
    private func helper(_ text: String) -> some View {
        Text(text).font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
    }
    private func setupRow(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(Theme.Colors.primary).frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(Theme.Fonts.body(16, .semibold))
                    Text(detail).font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13))
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private func connectHealth() {
        guard !debugFixture else { healthMessage = "Preview only — no Health permissions requested."; return }
        connectingHealth = true
        Task {
            defer { connectingHealth = false }
            do {
                try await HealthKitManager.shared.requestAuthorization()
                healthMessage = "Health permissions reviewed. You can change them in Apple Health. Read access stays private to Apple Health."
            } catch { healthMessage = "Couldn’t open Apple Health. You can try again or connect later in Profile." }
        }
    }
    private func finish(saveFocus: Bool) {
        guard !debugFixture else { step = 0; return }
        guard !vm.isLoading, let userId = appState.session?.user.id else { return }
        Task {
            do {
                let profile = try await vm.save(userId: userId, saveFocus: saveFocus)
                guard appState.session?.user.id == userId else { return }
                appState.setProfile(profile)
            } catch { vm.errorMessage = error.localizedDescription }
        }
    }
}

#if DEBUG
extension OnboardingView {
    static func preview() -> some View { OnboardingView(debugFixture: true) }
}
#endif
