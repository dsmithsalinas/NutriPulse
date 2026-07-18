import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: MainTab = .today
    // Owned here so the tab bar's Log action can log to the exact day Today is showing.
    @State private var todayVM = TodayViewModel()
    @State private var showLogger = false
    @State private var keyboardVisible = false

    // Log to the day being viewed on Today; anywhere else, log to today.
    private var logDate: Date {
        selectedTab == .today ? todayVM.selectedDate : .now
    }

    // The raised Log (+) button floats above the bar into content. Scrolling tabs slide under
    // it harmlessly, but Pulse's pinned composer can't — and when the keyboard rises it gets
    // shoved right under the FAB. So while typing to the coach, drop the whole bar (the standard
    // iOS chat pattern), letting the composer reclaim the space and sit above the keyboard.
    private var hideTabBar: Bool {
        keyboardVisible && selectedTab == .pulse
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
            if !hideTabBar {
                MainTabBar(selected: $selectedTab, onLog: { showLogger = true })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = false }
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
