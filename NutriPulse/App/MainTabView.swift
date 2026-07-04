import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "house.fill") }

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.line.uptrend.xyaxis") }

            Text("Coach")
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right.fill") }

            Text("Profile")
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}
