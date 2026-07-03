import SwiftUI

// SWIFT CONCEPT — @main marks the app entry point. Swift finds this struct and calls it
// instead of a traditional main() function. It's analogous to index.tsx in a React app.
//
// The App protocol requires a `body: some Scene` property. WindowGroup is the standard
// scene for an iPhone app — it manages the window lifecycle for you.

@main
struct NutriPulseApp: App {
    // @UIApplicationDelegateAdaptor lets us provide a real UIApplicationDelegate
    // alongside the SwiftUI lifecycle. Required to handle Supabase's background
    // URLSession callbacks — SwiftUI's synthesized AppDelegate crashes on them.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}
