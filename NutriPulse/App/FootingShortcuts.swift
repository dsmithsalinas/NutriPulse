import AppIntents

struct FootingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureWaterIntent(),
            phrases: ["Record water in \(.applicationName)"],
            shortTitle: "Record water", systemImageName: "drop.circle"
        )
        AppShortcut(
            intent: CaptureDayNoteIntent(),
            phrases: ["Save a note in \(.applicationName)"],
            shortTitle: "Save a note", systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: OpenOffScriptIntent(),
            phrases: ["Today went sideways in \(.applicationName)"],
            shortTitle: "Today went sideways", systemImageName: "arrow.triangle.branch"
        )
        AppShortcut(
            intent: FootingQuickActionIntent(action: .addWater),
            phrases: ["Add water in \(.applicationName)", "Log water in \(.applicationName)"],
            shortTitle: "Add water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: FootingQuickActionIntent(action: .talkToLog),
            phrases: ["Talk to Log in \(.applicationName)", "Log food in \(.applicationName)"],
            shortTitle: "Talk to Log",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: FootingQuickActionIntent(action: .logFavorite),
            phrases: ["Log a favorite in \(.applicationName)"],
            shortTitle: "Log favorite",
            systemImageName: "star.fill"
        )
        AppShortcut(
            intent: FootingQuickActionIntent(action: .logDose),
            phrases: ["Log my dose in \(.applicationName)"],
            shortTitle: "Log dose",
            systemImageName: "syringe.fill"
        )
    }
}
