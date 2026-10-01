import SwiftUI
import TipKit

// One-time tips (TipKit) for gestures nobody finds on their own. TipKit shows each tip once and,
// with the daily display frequency set in FootingApp, never more than one tip a day. Both wait
// until the user has logged food, so a brand-new Today shows the first-day checklist alone.

enum FootingTips {
    /// Set once Today has food on it.
    @Parameter static var hasLoggedFood: Bool = false

    /// Called once at launch (FootingApp.init). Screenshot and fixture launches stay tip-free
    /// unless `--tips-preview` asks to see every tip.
    static func configure() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--tips-preview") {
            Tips.showAllTipsForTesting()
        } else if DebugLaunch.tour || AppStoreScreenshotMode.active {
            Tips.hideAllTipsForTesting()
        }
        #else
        if AppStoreScreenshotMode.active { Tips.hideAllTipsForTesting() }
        #endif
        try? Tips.configure([.displayFrequency(.daily)])
    }
}

/// On the first meal on Today: tapping a food edits it, swiping it left deletes it.
struct MealRowTip: Tip {
    var title: Text { Text("Change or remove a food") }
    var message: Text? { Text("Tap a food to change it, or swipe it left to delete it.") }
    var image: Image? { Image(systemName: "hand.tap") }
    var rules: [Rule] { [#Rule(FootingTips.$hasLoggedFood) { $0 }] }
}

/// On Today's date: swiping the page, or the calendar button, moves between days.
struct DaySwipeTip: Tip {
    var title: Text { Text("Look back at other days") }
    var message: Text? { Text("Swipe Today left or right, or tap the calendar, to see another day.") }
    var image: Image? { Image(systemName: "hand.draw") }
    var rules: [Rule] { [#Rule(FootingTips.$hasLoggedFood) { $0 }] }
}

extension View {
    /// Attaches the tip only when `show` is true. iOS 17's popoverTip takes a non-optional tip
    /// (the optional form is iOS 26), so a list can point one tip at a single row this way.
    @ViewBuilder
    func popoverTip(_ tip: some Tip, arrowEdge: Edge, when show: Bool) -> some View {
        if show { popoverTip(tip, arrowEdge: arrowEdge) } else { self }
    }
}
