import Foundation

// Debug launch flags for checking screens without an account (docs/daylight-redesign.md).
// `--tour` turns on every per-screen preview at once, so the whole app can be clicked through
// with sample data. Always false in release builds.
enum DebugLaunch {
    /// Whether `flag` (e.g. "--pulse-preview") is on, directly or through `--tour`.
    static func has(_ flag: String) -> Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains(flag) || arguments.contains("--tour")
        #else
        return false
        #endif
    }

    /// The whole-app tour: every tab from fixtures, no network.
    static var tour: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--tour")
        #else
        false
        #endif
    }
}
