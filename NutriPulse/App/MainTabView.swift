import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: MainTab = ProcessInfo.processInfo.arguments.contains("--progress-preview")
        ? .progress : ProcessInfo.processInfo.arguments.contains("--pulse-preview") ? .pulse : .today
    // Owned here so the tab bar's Log action can log to the exact day Today is showing.
    @State private var todayVM = Self.makeTodayViewModel()
    @State private var showLogger = false
    @State private var loggerInitialTab: FoodLoggingViewModel.LogTab = .talk
    @State private var tabBarHeight: CGFloat = 0
    @State private var tabBarCompact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Read directly rather than through @Environment: it's a device-cached singleton (like
    // SyncEngine), not something a preview or test needs to substitute per-view.
    private var pulseStore: PulseProfileStore { PulseProfileStore.shared }

    private static func makeTodayViewModel() -> TodayViewModel {
        #if DEBUG
        if DebugLaunch.tour { return AppStoreScreenshotPreview.todayModel() }
        #endif
        return TodayViewModel()
    }

    // Log to the day being viewed on Today; anywhere else, log to today.
    private var logDate: Date {
        selectedTab == .today ? todayVM.selectedDate : .now
    }

    // Today only celebrates the protein goal once it's actually on screen — the tab is
    // selected and the logging sheet is down. Logging is what pushes protein over the line,
    // so without this the floor-cleared moment plays behind the sheet and is over before the user sees it.
    private var todayIsFrontmost: Bool {
        selectedTab == .today && !showLogger
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(vm: todayVM, isFrontmost: todayIsFrontmost)
                .tag(MainTab.today)
                .toolbar(.hidden, for: .tabBar)

            ProgressDashboardView()
                .tag(MainTab.progress)
                .toolbar(.hidden, for: .tabBar)

            CoachView(isActive: selectedTab == .pulse)
                .tag(MainTab.pulse)
                .toolbar(.hidden, for: .tabBar)

            ProfileView()
                .tag(MainTab.profile)
                .toolbar(.hidden, for: .tabBar)
        }
        // Hide the native bar and pin our custom one as a bottom safe-area inset so tab
        // content is never obscured and each tab keeps its own state. The hide has to be on
        // each tab's content: on iOS 26, hiding it on the TabView alone leaves the Liquid Glass
        // bar drawn behind our floating one.
        // The bar floats over the page, and a TabView doesn't pass the safe-area inset on to
        // its tabs' scroll views, so every scrolling page gets that room at its end directly:
        // the last rows can always be scrolled clear of the bar. Pulse opts out (its composer
        // already clears the bar itself; see CoachView).
        .contentMargins(.bottom, tabBarHeight, for: .scrollContent)
        // Scrolling down shrinks the bar; scrolling back up restores it. A drag, not scroll
        // offsets, so it works on every tab and iOS 17 without per-page plumbing. Simultaneous,
        // so it never takes a scroll or a tap from the page.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard selectedTab != .pulse,
                          abs(value.translation.height) > abs(value.translation.width) else { return }
                    setTabBarCompact(value.translation.height < 0)
                }
        )
        .onChange(of: selectedTab) { _, _ in setTabBarCompact(false) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MainTabBar(selected: $selectedTab, showsPulse: pulseStore.pulseEnabled, compact: tabBarCompact, onLog: {
                loggerInitialTab = .talk
                showLogger = true
            })
        }
        .onPreferenceChange(TabBarHeightKey.self) { tabBarHeight = $0 }
        .environment(\.tabBarHeight, tabBarHeight)
        .sheet(isPresented: $showLogger, onDismiss: {
            Task { await todayVM.loadData() }
        }) {
            FoodLoggingView(selectedDate: logDate, initialTab: loggerInitialTab)
        }
        // A nudge (or any surface) handing a prompt to the coach jumps to the Pulse tab;
        // CoachView sends it and clears it. `pendingCoachPrompt`'s setter already dropped this
        // (or routed to the consent sheet) if Pulse can't actually take it — see AppState.
        .onChange(of: appState.pendingCoachPrompt) { _, prompt in
            if prompt != nil { selectedTab = .pulse }
        }
        // Landing on the Pulse tab is itself a hand-off: show the consent sheet the first time,
        // same as asking Pulse something from elsewhere.
        .onChange(of: selectedTab) { _, tab in
            if tab == .pulse, pulseStore.needsConsent { appState.showPulseConsentSheet = true }
        }
        // Pulse turned off (from Profile, or another device) while its tab was showing —
        // there's nowhere left to send anything on it, so back out to Today.
        .onChange(of: pulseStore.pulseEnabled) { _, enabled in
            if !enabled, selectedTab == .pulse { selectedTab = .today }
        }
        // The consent sheet waits for the settings to load: the cached copy can be stale (a new
        // device, or consent given on another one), and "Not now" turns Pulse off.
        .onChange(of: pulseStore.isLoaded) { reconcileConsentSheet() }
        .onChange(of: pulseStore.aiConsentAt) { reconcileConsentSheet() }
        .onChange(of: pulseStore.pulseEnabled) { reconcileConsentSheet() }
        .sheet(isPresented: Binding(
            get: { appState.showPulseConsentSheet && pulseStore.isLoaded },
            set: { appState.showPulseConsentSheet = $0 }
        ), onDismiss: {
            // Closed without answering (the X, or a swipe): leave the setting alone so consent
            // is asked again next time, and just drop whatever prompt was waiting on it.
            appState.pendingConsentPrompt = nil
        }) {
            PulseConsentSheet(
                onAgree: {
                    try? await pulseStore.recordConsent(agreed: true)
                    appState.showPulseConsentSheet = false
                    if let prompt = appState.pendingConsentPrompt {
                        appState.pendingConsentPrompt = nil
                        appState.pendingCoachPrompt = prompt
                    }
                },
                onDecline: {
                    try? await pulseStore.recordConsent(agreed: false)
                    appState.pendingConsentPrompt = nil
                    appState.showPulseConsentSheet = false
                }
            )
        }
        .task {
            handleQuickAction()
            handleSmartNotificationRoute()
            handleWeeklyReminderRoute()
            await NotificationManager.shared.reconcileWeeklyReminder()
            #if DEBUG
            if DebugLaunch.tour { appState.profile = ProfileView.tourProfile }
            #endif
            await pulseStore.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .strongWeekReminderOpened)) { _ in
            handleWeeklyReminderRoute()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await NotificationManager.shared.reconcileWeeklyReminder() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            handleQuickAction()
            handleSmartNotificationRoute()
            handleWeeklyReminderRoute()
            Task { await NotificationManager.shared.reconcileWeeklyReminder() }
        }
        // Another surface (Profile's toggles, the consent sheet) changed a Pulse setting —
        // reload so this device's cache matches the server copy that saved it.
        .onReceive(NotificationCenter.default.publisher(for: .pulseProfileChanged)) { _ in
            Task { await pulseStore.load() }
        }
    }

    // Asked for while the settings were still loading, and the loaded settings say it's no
    // longer due: consent was already given (send the waiting prompt on), or Pulse is off (drop it).
    private func reconcileConsentSheet() {
        guard appState.showPulseConsentSheet, pulseStore.isLoaded, !pulseStore.needsConsent else { return }
        let prompt = appState.pendingConsentPrompt
        appState.pendingConsentPrompt = nil
        appState.showPulseConsentSheet = false
        if let prompt { appState.pendingCoachPrompt = prompt }
    }

    private func setTabBarCompact(_ compact: Bool) {
        guard compact != tabBarCompact else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
            tabBarCompact = compact
        }
    }

    private func handleWeeklyReminderRoute() {
        guard let userId = appState.session?.user.id,
              StrongWeekReminder.consumeRoute(userId: userId) else { return }
        selectedTab = .today
        showLogger = false
        appState.pendingStrongWeekReminder = true
    }

    private func handleQuickAction() {
        guard let action = QuickActionStore.consume() else { return }
        selectedTab = .today
        switch action {
        case .addWater:
            // The user's usual amount, always on today (not whichever day Today is showing).
            todayVM.goToToday()
            Task {
                await todayVM.addWater(WaterUnit.currentUsualMl)
                await todayVM.loadData()
            }
        case .talkToLog:
            loggerInitialTab = .talk
            showLogger = true
        case .logFavorite:
            loggerInitialTab = .favorites
            showLogger = true
        case .logDose:
            appState.pendingQuickAction = .logDose
        }
    }

    private func handleSmartNotificationRoute() {
        guard let route = SmartNotificationRouteStore.consume() else { return }
        selectedTab = .today
        switch route.action {
        case .addWater:
            // The user's usual amount, always on today (not whichever day Today is showing).
            todayVM.goToToday()
            Task {
                await todayVM.addWater(WaterUnit.currentUsualMl)
                await todayVM.loadData()
            }
        case .closeProtein:
            appState.pendingSmartNotificationRoute = route
        case .repeatMeal:
            guard let sourceDate = route.sourceDate, let meal = route.meal else { return }
            Task { await todayVM.repeatMeal(from: sourceDate, meal: meal) }
        case .reviewMeal:
            appState.pendingSmartNotificationRoute = route
        case .viewPreparation:
            appState.pendingSmartNotificationRoute = route
        }
    }
}
