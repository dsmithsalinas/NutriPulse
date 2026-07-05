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
}
