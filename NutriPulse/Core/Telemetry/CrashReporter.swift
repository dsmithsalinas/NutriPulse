import Darwin
import Foundation

// Lightweight crash visibility without a full crash SDK: an uncaught-exception
// / fatal-signal handler persists a flag before the process dies, and the next
// launch reports it as a TelemetryDeck signal. Native, symbolicated crash logs
// still land in App Store Connect / Xcode Organizer automatically for every
// TestFlight build — this just surfaces "did the last session crash" in our
// own analytics too, without waiting on Organizer sync.
enum CrashReporter {
    private static let lastRunCrashedKey = "CrashReporter.lastRunCrashed"

    static func install() {
        if UserDefaults.standard.bool(forKey: lastRunCrashedKey) {
            UserDefaults.standard.set(false, forKey: lastRunCrashedKey)
            Task { @MainActor in Telemetry.previousSessionCrashed() }
        }

        NSSetUncaughtExceptionHandler { _ in CrashReporter.markCrashed() }
        for sig in [SIGABRT, SIGILL, SIGSEGV, SIGTRAP, SIGBUS, SIGFPE] {
            signal(sig) { _ in CrashReporter.markCrashed() }
        }
    }

    private static func markCrashed() {
        UserDefaults.standard.set(true, forKey: lastRunCrashedKey)
    }
}
