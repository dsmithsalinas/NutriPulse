import SwiftUI

// Central token system — change a value here and it updates everywhere.
// Same idea as a Tailwind theme or CSS custom properties.
enum Theme {

    // MARK: - Brand

    /// Brand palette, sourced from the app icon gradient (indigo → violet).
    enum Colors {
        /// Primary brand color — buttons, links, selected states.
        static let primary = Color(hex: 0x6366F1)
        /// Secondary brand color — gradient endpoint, subtler accents.
        static let accent = Color(hex: 0x8B5CF6)

        /// The app icon's indigo → violet sweep. Reserve for hero moments:
        /// primary CTAs, the celebration beat — not every accent in the UI.
        static let primaryGradient = LinearGradient(
            colors: [primary, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Surfaces, built on system colors so light/dark mode keep working for free.
        static let background = Color(.systemBackground)
        static let surface = Color(.secondarySystemBackground)
        static let surfaceElevated = Color(.tertiarySystemBackground)

        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
    }

    /// Ring/chart colors, tuned as one family instead of raw system colors.
    enum NutrientColor {
        static let calories = Color(hex: 0xF97316)
        static let protein  = Color(hex: 0x6366F1)
        static let carbs    = Color(hex: 0x8B5CF6)
        static let fiber    = Color(hex: 0x22C55E)
        static let fat      = Color(hex: 0xF59E0B)
        static let water    = Color(hex: 0x0EA5E9)
    }

    // MARK: - Typography

    /// One scale for the whole app. New screens should reach for these
    /// instead of raw `.font(...)` calls.
    enum Typography {
        static let display  = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title    = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body     = Font.system(size: 17, weight: .regular)
        static let caption  = Font.system(size: 13, weight: .regular)
    }

    // MARK: - Layout

    enum Spacing {
        static let xs: CGFloat  =  4
        static let sm: CGFloat  =  8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
    }

    enum Radius {
        static let card: CGFloat   = 16
        static let button: CGFloat = 14
    }

    enum Ring {
        static let size: CGFloat      = 72
        static let lineWidth: CGFloat =  8
    }
}

// MARK: - Component styles

/// Primary call-to-action button — filled brand gradient, white label.
/// Respects `.disabled()` — falls back to a flat grey fill, same convention
/// every hand-rolled CTA button in the app used before this style existed.
/// Usage: `Button("Log it") { ... }.buttonStyle(.brandPrimary)`
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? .white : Color(.secondaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                if isEnabled {
                    Theme.Colors.primaryGradient
                } else {
                    Color(.systemFill)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var brandPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

/// The rounded-rect + surface-fill wrapper already used ad hoc across
/// Today/Analytics cards, promoted to a single reusable modifier.
/// Usage: `content.card()`
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

extension View {
    func card() -> some View {
        modifier(CardStyle())
    }
}

/// The brand "hero moment" reserved in `Colors.primaryGradient` — a brief scale
/// + glow pulse fired by incrementing `trigger`. Used for the ring-closing
/// celebration: free, fires every time, no badge or trophy-case iconography.
/// Usage: `content.celebrationBeat(trigger: someIntState)`
struct CelebrationBeat: ViewModifier {
    let trigger: Int
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.07 : 1.0)
            .shadow(color: Theme.Colors.primary.opacity(isPulsing ? 0.5 : 0),
                    radius: isPulsing ? 28 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: isPulsing)
            .onChange(of: trigger) { _, newValue in
                guard newValue > 0 else { return }
                isPulsing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    isPulsing = false
                }
            }
    }
}

extension View {
    func celebrationBeat(trigger: Int) -> some View {
        modifier(CelebrationBeat(trigger: trigger))
    }
}

// MARK: - Color(hex:)

extension Color {
    /// e.g. `Color(hex: 0x6366F1)`
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
