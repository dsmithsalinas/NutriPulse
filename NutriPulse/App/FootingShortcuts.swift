import AppIntents

struct FootingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
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
