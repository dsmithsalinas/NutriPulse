import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: MainTab = .today
    // Owned here so the tab bar's Log action can log to the exact day Today is showing.
    @State private var todayVM = TodayViewModel()
    @State private var showLogger = false

    // Log to the day being viewed on Today; anywhere else, log to today.
    private var logDate: Date {
        selectedTab == .today ? todayVM.selectedDate : .now
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(vm: todayVM)
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
