import SwiftUI

// The "make it forward" piece: on dose day (or overdue), a prominent Daylight lime card on
// Today that opens the injection ritual. Only shown when a dose is actually due — the rest of
// the time Today stays clean. Flat lime fill, in the same family as the Shot cycle tile and
// the ritual screen itself (InjectionRitualView) rather than the old aurora gradient.
struct DoseDayCard: View {
    let medication: String
    let doseText: String       // e.g. "2.5 mg"
    var overdue: Bool = false
    var completed: Bool = false
    var onTap: () -> Void = {}
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if completed {
                card    // a celebration display — not a button
            } else {
                Button(action: onTap) { card }
                    .buttonStyle(.pressable)
            }

            // A sibling of the main button (not nested), so dismissing never triggers the tap.
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.limeInk)
                        .frame(width: 32, height: 32)
                        .background(Theme.Colors.surfaceCard, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(12)
                .accessibilityLabel("Dismiss")
            }
        }
    }

    private var card: some View {
        ZStack(alignment: .leading) {
            Theme.Colors.lime
            if completed { completedContent } else { promptContent }
        }
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
    }

    private var promptContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                PulseDot()
                TileEyebrow(overdue ? "Shot planned" : "It\u{2019}s dose day", color: Theme.Colors.limeLabel)
            }

            Text(overdue ? "Your shot log" : "Time for your shot")
                .font(Theme.Fonts.display(24, .bold, relativeTo: .title3))
                .foregroundStyle(Theme.Colors.limeInk)
                .padding(.top, 8)
            Text("\(medication) \u{00B7} \(doseText)")
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(Theme.Colors.limeLabel)
                .padding(.top, 1)

            HStack(spacing: 7) {
                Text("Log your shot")
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
            }
            .font(Theme.Fonts.body(15, .bold))
            .foregroundStyle(Theme.Colors.lime)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(Theme.Colors.limeInk, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .padding(.top, 16)
        }
        .padding(20)
    }

    private var completedContent: some View {
        HStack(spacing: 14) {
            CompletedCheck()
            VStack(alignment: .leading, spacing: 3) {
                TileEyebrow("Shot logged", color: Theme.Colors.limeLabel)
                Text("You took your shot")
                    .font(Theme.Fonts.display(22, .bold, relativeTo: .title3))
                    .foregroundStyle(Theme.Colors.limeInk)
                    .padding(.top, 6)
                Text("\(medication) \u{00B7} \(doseText) \u{00B7} logged today")
                    .font(Theme.Fonts.body(13, .semibold))
                    .foregroundStyle(Theme.Colors.limeLabel)
                    .padding(.top, 1)
                Text("Protecting your muscle \u{2014} see you next week.")
                    .font(Theme.Fonts.body(12.5))
                    .foregroundStyle(Theme.Colors.limeLabel)
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}

// A checkmark medallion that pops in — the little celebration.
private struct CompletedCheck: View {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(Theme.Colors.limeInk).frame(width: 46, height: 46)
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Colors.lime)
        }
        .scaleEffect(shown || reduceMotion ? 1 : 0.4)
        .opacity(shown || reduceMotion ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: shown)
        .onAppear { shown = true }
    }
}

// Softly pulsing dot — the "live" signal on the card.
private struct PulseDot: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(Theme.Colors.limeInk)
            .frame(width: 8, height: 8)
            .overlay(
                Circle().stroke(Theme.Colors.limeInk, lineWidth: 2)
                    .scaleEffect(pulse ? 2.4 : 1)
                    .opacity(pulse ? 0 : 0.6)
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
            .onAppear { pulse = true }
    }
}
