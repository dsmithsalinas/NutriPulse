import Foundation

// Reads Supabase credentials from Info.plist, which gets them from Secrets.xcconfig
// at build time. The credentials never appear in source code or the binary's string table.
// If either value is missing, the app crashes immediately at startup with a clear message
// rather than failing silently at the first network call.
enum Config {
    static let supabaseURL: String = {
        guard let value = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !value.isEmpty, value != "https://your-project-id.supabase.co" else {
            fatalError("SUPABASE_URL not configured. Copy Secrets.xcconfig.template → Secrets.xcconfig and fill in your project URL.")
        }
        return value
    }()

    static let supabaseAnonKey: String = {
        guard let value = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !value.isEmpty, value != "your-anon-key-here" else {
            fatalError("SUPABASE_ANON_KEY not configured. Copy Secrets.xcconfig.template → Secrets.xcconfig and fill in your anon key.")
        }
        return value
    }()

    // Telemetry is optional infra, unlike auth — missing config disables it
    // quietly instead of crashing the app.
    static let telemetryDeckAppID: String? = {
        guard let value = Bundle.main.infoDictionary?["TELEMETRYDECK_APP_ID"] as? String,
              !value.isEmpty, value != "your-telemetrydeck-app-id-here" else {
            return nil
        }
        return value
    }()

    // Live on GitHub Pages. The gh-pages snapshot publishes the contents of `marketing/`
    // at the site root, so the path here is /privacy.html — NOT /marketing/privacy.html,
    // which 404s. App Review fetches this URL, so a wrong path is a rejection.
    static let privacyPolicyURL = URL(string: "https://dsmithsalinas.github.io/NutriPulse/privacy.html")!

    // Apple's Standard License Agreement (LAEULA) — the EULA Apple applies to any app that
    // doesn't ship its own. It's a complete, accepted Terms of Use for a free app, which is
    // why App Review is satisfied by it. Swap for a self-hosted terms page (mirroring
    // privacyPolicyURL) if we ever add subscriptions or custom terms.
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
