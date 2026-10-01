import SwiftUI

// "Your first day": a short checklist on Today for a new account, in Pulse's voice, that teaches
// the core loop by doing it (log a meal, log the shot, add water, ask Pulse) instead of a tour
// of screens people swipe past. Each step ticks off when the thing actually happens, from the
// same data Today already shows, so it can't be ticked by tapping alone. The card goes away when
// dismissed, the day after it's finished, or once the account is past its first two weeks, so
// people updating from an older version never see it.

enum FirstDayStep: String, CaseIterable, Identifiable {
    case meal, shot, water, pulse
    var id: String { rawValue }

    var title: String {
        switch self {
        case .meal: "Log your first meal"
        case .shot: "Log your shot"
        case .water: "Add a glass of water"
        case .pulse: "Ask Pulse anything"
        }
    }

    var detail: String {
        switch self {
        case .meal: "Say it like you'd tell a friend. Talk to Log does the rest."
        case .shot: "Hold to log it, or check when the next one's due."
        case .water: "Pick a size once. After that, + on the water tile adds it."
        case .pulse: "What to eat, how you're trending, anything on your mind."
        }
    }

    var symbol: String {
        switch self {
        case .meal: "fork.knife"
        case .shot: "syringe"
        case .water: "drop.fill"
        case .pulse: "bubble.left.and.text.bubble.right"
        }
    }
}

/// What the card shows, worked out from plain inputs so it can be unit tested.
struct FirstDayChecklist: Equatable {
    /// How long after the account is created the card can appear.
    static let windowDays = 14

    let steps: [FirstDayStep]
    let done: Set<FirstDayStep>

    var doneCount: Int { steps.filter(done.contains).count }
    var isComplete: Bool { !steps.isEmpty && doneCount == steps.count }

    /// The steps that apply: the shot only while GLP-1 tracking is on, Pulse only while it's on.
    static func steps(tracksGLP1: Bool, pulseEnabled: Bool) -> [FirstDayStep] {
        FirstDayStep.allCases.filter { step in
            switch step {
            case .shot: tracksGLP1
            case .pulse: pulseEnabled
            case .meal, .water: true
            }
        }
    }

    /// Whether the card shows at all. A new account only; hidden once dismissed, and a finished
    /// list stays up (as a small win) only for the rest of the day it was finished.
    static func isVisible(
        accountCreated: Date?, dismissed: Bool, completedOn: String?,
        now: Date = .now, calendar: Calendar = .current
    ) -> Bool {
        guard !dismissed, let accountCreated else { return false }
        let age = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: accountCreated), to: calendar.startOfDay(for: now)
        ).day ?? .max
        guard age < windowDays else { return false }
        if let completedOn, completedOn != now.isoDateString(in: calendar.timeZone) { return false }
        return true
    }
}

/// Per-account progress on this device: which steps are done, whether the card was dismissed, and
/// the day the list was finished. Keyed by user id so a shared phone keeps accounts apart.
enum FirstDayChecklistStore {
    private static func key(_ userId: String, _ field: String) -> String { "firstDay.\(field).\(userId)" }

    static func done(userId: String, defaults: UserDefaults = .standard) -> Set<FirstDayStep> {
        Set((defaults.stringArray(forKey: key(userId, "done")) ?? []).compactMap(FirstDayStep.init(rawValue:)))
    }

    /// Records a finished step. Returns true the first time, so the caller can count it once.
    @discardableResult
    static func markDone(_ step: FirstDayStep, userId: String, defaults: UserDefaults = .standard) -> Bool {
        var current = done(userId: userId, defaults: defaults)
        guard current.insert(step).inserted else { return false }
        defaults.set(current.map(\.rawValue).sorted(), forKey: key(userId, "done"))
        return true
    }

    /// Records a step the user actually did, counting it in analytics the first time only.
    @MainActor @discardableResult
    static func recordStep(_ step: FirstDayStep, userId: String, defaults: UserDefaults = .standard) -> Bool {
        guard markDone(step, userId: userId, defaults: defaults) else { return false }
        Telemetry.firstDayStepDone(step: step.rawValue)
        return true
    }

    static func isDismissed(userId: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key(userId, "dismissed"))
    }

    static func dismiss(userId: String, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key(userId, "dismissed"))
    }

    static func completedOn(userId: String, defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: key(userId, "completedOn"))
    }

    static func markCompleted(on day: String, userId: String, defaults: UserDefaults = .standard) {
        guard completedOn(userId: userId, defaults: defaults) == nil else { return }
        defaults.set(day, forKey: key(userId, "completedOn"))
    }
}

/// The card. Each row opens the place where that step happens; done rows show a lime check.
struct FirstDayChecklistCard: View {
    let checklist: FirstDayChecklist
    let onStep: (FirstDayStep) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PulseMark()
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .frame(width: 40, height: 40)
                    .background(Theme.Colors.hero, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    TileEyebrow("Your first day · \(checklist.doneCount) of \(checklist.steps.count)",
                                color: Theme.Colors.textFaint)
                    Text(checklist.isComplete ? "You've got the basics" : "A few things to try today")
                        .font(Theme.Fonts.body(16, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if checklist.isComplete {
                        Text("That's the daily loop. I'll keep an eye on your floor from here.")
                            .font(Theme.Fonts.body(14))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Theme.Colors.surfaceInset, in: Circle())
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .accessibilityLabel(checklist.isComplete ? "Close" : "Hide first-day checklist")
            }

            if !checklist.isComplete {
                VStack(spacing: 0) {
                    ForEach(Array(checklist.steps.enumerated()), id: \.element) { index, step in
                        if index > 0 { Divider().overlay(Theme.Colors.hairline).padding(.leading, 44) }
                        row(step, done: checklist.done.contains(step))
                    }
                }
            }
        }
        .tile(radius: Theme.Radius.tileSmall, padding: 14)
    }

    private func row(_ step: FirstDayStep, done: Bool) -> some View {
        Button { onStep(step) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(done ? Theme.Colors.lime : Theme.Colors.surfaceInset)
                    Image(systemName: done ? "checkmark" : step.symbol)
                        .font(.system(size: done ? 13 : 14, weight: .bold))
                        .foregroundStyle(done ? Theme.Colors.limeInk : Theme.Colors.primaryText)
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(Theme.Fonts.body(15, .semibold))
                        .foregroundStyle(done ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                        .strikethrough(done, color: Theme.Colors.textFaint)
                    if !done {
                        Text(step.detail)
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                if !done {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Colors.textFaint)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Not .disabled: that dims the lime check. A done step just stops reacting.
        .allowsHitTesting(!done)
        .accessibilityLabel(done ? "\(step.title), done" : step.title)
        .accessibilityHint(done ? "" : step.detail)
    }
}
