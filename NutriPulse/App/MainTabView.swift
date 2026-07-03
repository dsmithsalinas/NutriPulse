import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "house.fill") }

            // Placeholder tabs — features built incrementally
            Text("Log Food")
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }

            Text("Analytics")
                .tabItem { Label("Analytics", systemImage: "chart.line.uptrend.xyaxis") }

            Text("Coach")
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right.fill") }

            Text("Profile")
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}
