import SwiftUI
import SwiftData

@main
struct NutriPulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    static let modelContainer: ModelContainer = {
        let schema = Schema([SDFoodLog.self, SDWaterLog.self, SDDailyGoal.self])

        // 1) Normal on-disk store — the common path.
        if let container = try? ModelContainer(for: schema) {
            return container
        }

        // 2) The on-disk store is corrupt or schema-incompatible (e.g. a failed
        //    migration after an update). Delete it and rebuild so persistence keeps
        //    working from here forward, rather than silently degrading to memory-only
        //    on every future launch. The local store is only a cache — SyncEngine
        //    re-pulls from Supabase — so dropping it is recoverable, not data loss.
        Task { @MainActor in Telemetry.localStoreFallback() }
        let storeURL = ModelConfiguration().url
        for sidecar in ["", "-wal", "-shm"] {
            let name = storeURL.lastPathComponent + sidecar
            let url = storeURL.deletingLastPathComponent().appendingPathComponent(name)
            try? FileManager.default.removeItem(at: url)
        }
        if let container = try? ModelContainer(for: schema) {
            return container
        }

        // 3) Last resort: in-memory for this session only (data won't persist across
        //    launches). If even this throws, the schema itself is invalid — a
        //    programming error that would surface in development, not on a user's device.
        let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: memoryConfig) else {
            fatalError("Could not create an in-memory ModelContainer — the SwiftData schema is invalid.")
        }
        return container
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
