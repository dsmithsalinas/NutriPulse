import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: MainTab = .today
    // Owned here so the tab bar's Log action can log to the exact day Today is showing.
    @State private var todayVM = TodayViewModel()
    @State private var showLogger = false
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

            AnalyticsView()
                .tag(MainTab.analytics)

            CoachView(isActive: selectedTab == .pulse)
                .tag(MainTab.pulse)

            ProfileView()
                .tag(MainTab.profile)
        }
        // Hide the native bar and pin our custom one as a bottom safe-area inset so tab
        // content is never obscured and each tab keeps its own state.
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MainTabBar(selected: $selectedTab, onLog: { showLogger = true })
        }
        .onPreferenceChange(TabBarHeightKey.self) { tabBarHeight = $0 }
        .environment(\.tabBarHeight, tabBarHeight)
        .sheet(isPresented: $showLogger, onDismiss: {
            Task { await todayVM.loadData() }
        }) {
            FoodLoggingView(selectedDate: logDate)
        }
        // A nudge (or any surface) handing a prompt to the coach jumps to the Pulse tab;
        // CoachView sends it and clears it.
        .onChange(of: appState.pendingCoachPrompt) { _, prompt in
            if prompt != nil { selectedTab = .pulse }
        }
    }
}
