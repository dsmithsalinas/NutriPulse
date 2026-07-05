import SwiftUI
import SwiftData

@main
struct NutriPulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    static let modelContainer: ModelContainer = {
        let schema = Schema([SDFoodLog.self, SDWaterLog.self, SDDailyGoal.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            // A corrupt/incompatible on-disk store should never hard-crash
            // launch. Fall back to an in-memory store for this session (data
            // won't persist across launches) and log it so we know it happened.
            Task { @MainActor in Telemetry.localStoreFallback() }
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: config)
        }
    }()

    init() {
        CrashReporter.install()
        LocalStore.shared.configure(with: Self.modelContainer)
        SyncEngine.shared.configure()
        Telemetry.initialize()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(Self.modelContainer)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Telemetry.appOpened()
                Task { await SyncEngine.shared.syncNow() }
            }
        }
    }
}
