import SwiftUI

/// Canonical, unmodified vectors from marketing/characters/pulse-ring/svg.
/// Static by design, including with Reduce Motion. Use beside a visible state/Pulse label.
/// Explicit surface selection avoids choosing a dark asset on Daylight's white cards.
struct PulseRing: View {
    enum State: String, CaseIterable {
        case ready, listening, thinking, coaching
        case checkIn = "check-in"
    }

    var state: State = .ready
    var size: CGFloat = 32
    var onDarkSurface = false

    var body: some View {
        Image("PulseRing-\(state.rawValue)\(onDarkSurface ? "-dark" : "")")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: max(32, size), height: max(32, size))
            .accessibilityHidden(true)
    }
}
