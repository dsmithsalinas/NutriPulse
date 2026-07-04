import SwiftUI
import SwiftData

@main
struct NutriPulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    static let modelContainer: ModelContainer = {
        let schema = Schema([SDFoodLog.self, SDWaterLog.self, SDDailyGoal.self])
        return try! ModelContainer(for: schema)
    }()

    init() {
        LocalStore.shared.configure(with: Self.modelContainer)
        SyncEngine.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(Self.modelContainer)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await SyncEngine.shared.syncNow() }
            }
        }
    }
}
