import Darwin
import Foundation

// Lightweight crash visibility without a full crash SDK: a fatal-signal /
// uncaught-exception handler drops a sentinel file before the process dies, and
// the next launch reports it as a TelemetryDeck signal. Native, symbolicated
// crash logs still land in App Store Connect / Xcode Organizer automatically for
// every TestFlight build — this just surfaces "did the last session crash" in our
// own analytics too, without waiting on Organizer sync.
//
// Two rules govern everything in the signal handler below, and breaking either
// one turns a crash into something worse than a crash:
//
//  1. RE-RAISE. Returning from a handler for a hardware fault (SIGSEGV/SIGBUS/
//     SIGILL/SIGFPE) re-executes the faulting instruction, which faults again,
//     which re-enters the handler — an infinite loop. The user gets a frozen app
//     instead of a crash, and because the process never dies abnormally, iOS
//     never writes a crash log. We restore the default disposition and re-raise
//     so the process dies the way the OS expects.
//
//  2. STAY ASYNC-SIGNAL-SAFE. A handler may run in the middle of malloc or
//     CoreFoundation, holding their locks. UserDefaults (which allocates, takes
//     locks, and XPCs to cfprefsd) can deadlock there, and its write frequently
//     doesn't flush before death anyway. Only open/write/close are used below —
//     all on the POSIX async-signal-safe list — against a path that was strdup'd
//     ahead of time so the handler allocates nothing.
enum CrashReporter {

    // strdup'd once at install time and intentionally never freed: the handler
    // needs a valid C string with no allocation at signal time.
    private static var sentinelPath: UnsafeMutablePointer<CChar>?

    private static var sentinelURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("crash.sentinel")
    }

    static func install() {
        let url = sentinelURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // A sentinel left behind means last run died without a clean exit.
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
            Task { @MainActor in Telemetry.previousSessionCrashed() }
        }

        sentinelPath = strdup(url.path)

        NSSetUncaughtExceptionHandler { _ in
            // An uncaught ObjC exception proceeds to abort() → SIGABRT, which the
            // handler below catches and re-raises. Just leave the breadcrumb.
            CrashReporter.writeSentinel()
        }

        for sig in [SIGABRT, SIGILL, SIGSEGV, SIGTRAP, SIGBUS, SIGFPE] {
            signal(sig) { received in
                CrashReporter.writeSentinel()
                signal(received, SIG_DFL)
                raise(received)
            }
        }
    }

    // Async-signal-safe: no allocation, no locks, no Foundation.
    private static func writeSentinel() {
        guard let path = sentinelPath else { return }
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else { return }
        var byte: UInt8 = 1
        _ = withUnsafeBytes(of: &byte) { write(fd, $0.baseAddress, 1) }
        close(fd)
    }
}
