import SwiftUI
import SwiftData

@main
struct NutriPulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    static let modelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: NutriPulseSchemaLatest.self)

        // 1) Normal on-disk store — the common path. The migration plan gives SwiftData an
        //    explicit path to migrate an existing store across schema versions instead of
        //    failing to open it. A schema change with no such path (e.g. adding the
        //    non-optional `revision` field) is what used to fail here and drop us into the
        //    destructive fallback below. See SchemaMigrations.swift before changing a model.
        if let container = try? ModelContainer(for: schema, migrationPlan: NutriPulseMigrationPlan.self) {
            return container
        }

        // 2) The store failed to open — corruption, or a schema change with no migration
        //    path. Do NOT delete it: that would permanently discard any rows that never
        //    reached Supabase (pendingCreate), the one thing here that isn't just a
        //    re-pullable cache. Move it aside into a quarantine folder instead, so the data
        //    survives — recoverable by a corrected migration in a later build, or manually —
        //    while the app keeps working from a fresh store. With the migration plan in
        //    place this path should be reached only on genuine corruption now.
        Task { @MainActor in Telemetry.localStoreFallback() }
        quarantineStore(at: ModelConfiguration().url)

        if let container = try? ModelContainer(for: schema, migrationPlan: NutriPulseMigrationPlan.self) {
            return container
        }

        // 3) Last resort: in-memory for this session only (data won't persist across
        //    launches). If even this throws, the schema itself is invalid — a
        //    programming error that would surface in development, not on a user's device.
        let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, migrationPlan: NutriPulseMigrationPlan.self, configurations: memoryConfig) else {
            fatalError("Could not create an in-memory ModelContainer — the SwiftData schema is invalid.")
        }
        return container
    }()

    // Moves a store SwiftData couldn't open into a Quarantine/ subfolder instead of
    // deleting it, turning permanent data loss into a recoverable state — unsynced rows
    // that never reached Supabase live only in this file. Keeps a single generation (the
    // prior quarantine is cleared first) so disk use stays bounded. Best-effort: if a file
    // can't be moved aside it's removed, since a store we can neither open nor relocate
    // would otherwise block launch on every future run — that's the only case that still
    // loses data, and it's genuine corruption, not schema drift.
    private static func quarantineStore(at storeURL: URL) {
        let fm = FileManager.default
        let dir = storeURL.deletingLastPathComponent()
        let quarantine = dir.appendingPathComponent("Quarantine", isDirectory: true)

        try? fm.removeItem(at: quarantine)
        let created = (try? fm.createDirectory(at: quarantine, withIntermediateDirectories: true)) != nil

        let stamp = String(Int(Date().timeIntervalSince1970))
        for sidecar in ["", "-wal", "-shm"] {
            let name = storeURL.lastPathComponent + sidecar
            let src = dir.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else { continue }
            let moved = created && ((try? fm.moveItem(
                at: src,
                to: quarantine.appendingPathComponent("\(stamp)-\(name)")
            )) != nil)
            if !moved { try? fm.removeItem(at: src) }
        }
    }

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
