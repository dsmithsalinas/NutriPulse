import SwiftUI

// The "make it forward" piece: on dose day (or overdue), a prominent living-gradient card on
// Today that opens the injection ritual. Only shown when a dose is actually due — the rest of
// the time Today stays clean.
struct DoseDayCard: View {
    let medication: String
    let doseText: String       // e.g. "2.5 mg"
    var overdue: Bool = false
    var completed: Bool = false
    var onTap: () -> Void = {}

    var body: some View {
        if completed {
            card    // a celebration display — not a button
        } else {
            Button(action: onTap) { card }
                .buttonStyle(.pressable)
        }
    }

    private var card: some View {
        ZStack(alignment: .leading) {
            AuroraView()
                .opacity(0.9)
                .overlay(Color.black.opacity(0.12))

            if completed { completedContent } else { promptContent }
        }
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 18, y: 8)
    }

    private var promptContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                PulseDot()
                Text(overdue ? "DOSE OVERDUE" : "IT\u{2019}S DOSE DAY")
                    .font(.system(size: 12, weight: .bold)).tracking(0.6)
            }
            .foregroundStyle(.white.opacity(0.92))

            Text(overdue ? "Log your missed shot" : "Time for your shot")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white).padding(.top, 8)
            Text("\(medication) \u{00B7} \(doseText)")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.9)).padding(.top, 1)

            HStack(spacing: 7) {
                Text("Log your shot")
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white.opacity(0.28)))
            .padding(.top, 16)
        }
        .padding(20)
    }

    private var completedContent: some View {
        HStack(spacing: 14) {
            CompletedCheck()
            VStack(alignment: .leading, spacing: 3) {
                Text("SHOT LOGGED")
                    .font(.system(size: 12, weight: .bold)).tracking(0.6)
                    .foregroundStyle(.white.opacity(0.92))
                Text("You took your shot")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white).padding(.top, 6)
                Text("\(medication) \u{00B7} \(doseText) \u{00B7} logged today")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9)).padding(.top, 1)
                Text("Protecting your muscle \u{2014} see you next week.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.8)).padding(.top, 8)
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
            Circle().fill(.white.opacity(0.18)).frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(.white.opacity(0.4)))
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
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
            .fill(.white)
            .frame(width: 8, height: 8)
            .overlay(
                Circle().stroke(.white, lineWidth: 2)
                    .scaleEffect(pulse ? 2.4 : 1)
                    .opacity(pulse ? 0 : 0.6)
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
            .onAppear { pulse = true }
    }
}
