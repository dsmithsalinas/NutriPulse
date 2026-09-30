import SwiftUI
import UIKit

// Daylight's signature interaction (docs/daylight-redesign.md, Shot day): press and hold ~1.5s to
// confirm, with a ring that fills around a dark circular button and a small overshoot pop on
// completion. Reserved for moments that deserve deliberate confirmation rather than a plain tap.

/// The press/cancel/complete state machine behind `HoldToConfirmButton`, kept free of SwiftUI and
/// UIKit so it can be unit tested without driving a real gesture, animation, or timer. It only
/// answers one question at each step: given what just happened, is this hold now confirmed?
///
/// The three properties that matter for a hold-to-confirm control are exactly the three this type
/// guards: a hold that's released early must not confirm, a confirmation only fires once, and a
/// stale completion (e.g. a timer that fires after the user already released) is ignored.
struct HoldToConfirmProgress: Equatable {
    private(set) var isHolding = false
    private(set) var isComplete = false

    /// Starts a hold. Returns `false` (no-op) once this instance has already confirmed — a
    /// completed hold doesn't restart.
    @discardableResult
    mutating func beginHold() -> Bool {
        guard !isComplete else { return false }
        isHolding = true
        return true
    }

    /// The press was released before completing. No-op if there's nothing to cancel, or if the
    /// hold already confirmed (a release arriving after completion shouldn't undo it).
    mutating func cancelHold() {
        guard !isComplete else { return }
        isHolding = false
    }

    /// The hold has been sustained for the full duration. Returns `true` exactly once — the
    /// caller's cue to fire its action — and `false` if the hold was already released
    /// (`cancelHold`) or had already completed, so a stale timer can never double-confirm.
    @discardableResult
    mutating func complete() -> Bool {
        guard isHolding, !isComplete else { return false }
        isHolding = false
        isComplete = true
        return true
    }

    /// Back to the beginning — e.g. after a save fails and the user needs to try again. Prefer
    /// giving the view a fresh identity (`.id(_:)`) over calling this from outside; it exists
    /// mainly so tests can reuse one instance across cases.
    mutating func reset() {
        isHolding = false
        isComplete = false
    }
}

/// A large circular button that confirms on a sustained hold rather than a tap: a ring fills in
/// around it as the hold progresses, the button itself scales down slightly while pressed, and
/// releasing early cancels and springs the ring back to empty. Completion fires a success haptic,
/// a small overshoot pop, then `onConfirm`.
///
/// Accessibility: hold gestures aren't usable with VoiceOver or Switch Control, so this exposes a
/// plain accessibility action that logs immediately — VoiceOver's double-tap and Switch Control's
/// select both reach it without holding anything.
///
/// Reduce Motion: the ring doesn't animate progressively (it stays empty, then jumps to full the
/// instant the hold completes) but the hold timing itself is unchanged.
struct HoldToConfirmButton: View {
    var duration: TimeInterval = 1.5
    var diameter: CGFloat = 168
    var ringLineWidth: CGFloat = 12
    var fill: Color = Theme.Colors.limeInk
    var labelColor: Color = Theme.Colors.lime
    var ringTrack: Color = Theme.Colors.limeInk.opacity(0.12)
    let label: Text
    var accessibilityLabel: String = "Log dose"
    var accessibilityHint: String = "Double tap to log immediately"
    /// Fires once — either after a full hold, or right away via the accessibility action.
    var onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state = HoldToConfirmProgress()
    @State private var ringProgress: CGFloat = 0
    @State private var isPressed = false
    @State private var overshoot = false
    @State private var confirmWork: DispatchWorkItem?

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringTrack, lineWidth: ringLineWidth)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(fill, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(fill)
                .frame(width: diameter, height: diameter)
                .shadow(color: fill.opacity(0.3), radius: 24, y: 10)
                .scaleEffect(scale)
                .animation(.easeOut(duration: 0.2), value: isPressed)
                .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.5), value: overshoot)
                .overlay {
                    label
                        .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                        .foregroundStyle(labelColor)
                        .padding(20)
                }
        }
        .frame(width: diameter + ringLineWidth * 2, height: diameter + ringLineWidth * 2)
        .contentShape(Circle())
        .gesture(holdGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { logImmediately() }
    }

    private var scale: CGFloat {
        if overshoot { return 1.06 }
        return isPressed ? 0.94 : 1
    }

    // MARK: Gesture

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressed else { return }
                beginHold()
            }
            .onEnded { _ in endHold() }
    }

    private func beginHold() {
        guard state.beginHold() else { return }
        isPressed = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if reduceMotion {
            ringProgress = 0
        } else {
            withAnimation(.linear(duration: duration)) { ringProgress = 1 }
        }
        let work = DispatchWorkItem { complete() }
        confirmWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func endHold() {
        guard isPressed else { return }
        isPressed = false
        state.cancelHold()
        confirmWork?.cancel()
        confirmWork = nil
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { ringProgress = 0 }
    }

    private func complete() {
        guard state.complete() else { return }
        isPressed = false
        confirmWork = nil
        ringProgress = 1
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        overshoot = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { overshoot = false }
        onConfirm()
    }

    /// VoiceOver / Switch Control path: no hold required, logs straight away.
    private func logImmediately() {
        guard state.beginHold() else { return }
        ringProgress = 1
        _ = state.complete()
        confirmWork?.cancel()
        confirmWork = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if !reduceMotion {
            overshoot = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { overshoot = false }
        }
        onConfirm()
    }
}

#Preview("Hold to confirm") {
    HoldToConfirmButton(label: Text("Hold to\nlog dose")) {}
        .padding(60)
        .background(Theme.Colors.lime)
}
