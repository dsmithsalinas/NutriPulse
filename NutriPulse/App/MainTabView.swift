import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: MainTab = ProcessInfo.processInfo.arguments.contains("--progress-preview")
        ? .progress : .today
    // Owned here so the tab bar's Log action can log to the exact day Today is showing.
    @State private var todayVM = TodayViewModel()
    @State private var showLogger = false
    @State private var loggerInitialTab: FoodLoggingViewModel.LogTab = .talk
    @State private var tabBarHeight: CGFloat = 0

    // Log to the day being viewed on Today; anywhere else, log to today.
    private var logDate: Date {
        selectedTab == .today ? todayVM.selectedDate : .now
    }

    // Today only celebrates the protein goal once it's actually on screen — the tab is
    // selected and the logging sheet is down. Logging is what pushes protein over the line,
    // so without this the ripple fires behind the sheet and is over before the user sees it.
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MainTabBar(selected: $selectedTab, onLog: {
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
        // CoachView sends it and clears it.
        .onChange(of: appState.pendingCoachPrompt) { _, prompt in
            if prompt != nil { selectedTab = .pulse }
        }
        .task {
            handleQuickAction()
            handleSmartNotificationRoute()
            handleWeeklyReminderRoute()
            await NotificationManager.shared.reconcileWeeklyReminder()
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
            Task {
                await todayVM.addWater(250)
                await todayVM.loadData()
            }
        case .talkToLog:
            loggerInitialTab = .talk
            showLogger = true
        case .logFavorite:
            loggerInitialTab = .search
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
            Task {
                await todayVM.addWater(250)
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
