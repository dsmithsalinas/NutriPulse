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

        // MARK: Redesign palette (2026 Today refresh)
        // Indigo-biased neutrals — a chosen family, not the default system greys — that give the
        // app a branded ground and premium depth. Adaptive so light and dark both look considered.
        // Sourced from the approved Today concept.
        static let ground       = Color(light: 0xF2F0FB, dark: 0x0E0D1A)
        static let groundGlow   = Color(light: 0xE7E3FB, dark: 0x171532)
        static let surfaceCard  = Color(light: 0xFFFFFF, dark: 0x1A1826)
        static let surfaceInset = Color(light: 0xF6F4FE, dark: 0x232032)
        static let hairline     = Color(light: 0xE7E3F3, dark: 0x2E2B40)
        static let ringTrack    = Color(light: 0xECE8F7, dark: 0x262336)
        static let textFaint    = Color(light: 0x9A95AD, dark: 0x6F6B86)
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

/// A springy press effect for icon buttons and chips — scales down on touch and bounces back.
/// Keeps taps feeling physical without the flat "nothing happened" of `.plain`.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.9
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// The rounded-rect + surface-fill wrapper already used ad hoc across
/// Today/Analytics cards, promoted to a single reusable modifier.
/// Usage: `content.card()`
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
            }
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

/// The protein hero moment. When protein alone crosses its goal, concentric brand-gradient
/// rings radiate from the protein ring and wash outward across the card — bigger and more
/// specific than `celebrationBeat`, reserved for "did I hit protein?" landing yes. Fired by
/// incrementing `trigger`. Honors Reduce Motion (no ripple; pair with `celebrationBeat` so the
/// subtle scale+glow still marks the moment). Usage: `card.proteinRipple(trigger:, anchorY:)`
struct ProteinRipple: ViewModifier {
    let trigger: Int
    /// Vertical center of the protein ring within the modified view, in points — the ripple's origin.
    var anchorY: CGFloat = 132

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var waves: [Int] = []
    @State private var washID: Int? = nil
    @State private var nextID = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        if let washID { RippleWash().id(washID) }
                        ForEach(waves, id: \.self) { id in RippleWave().id(id) }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    // Anchor the origin on the ring center regardless of the card's height.
                    .position(x: geo.size.width / 2, y: anchorY)
                }
                .allowsHitTesting(false)
            }
            .onChange(of: trigger) { _, newValue in
                guard newValue > 0, !reduceMotion else { return }
                // A soft bloom, then three staggered rings expanding out from the ring.
                let bloom = nextID; nextID += 1
                washID = bloom
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    if washID == bloom { washID = nil }
                }
                for i in 0..<3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.16) {
                        let id = nextID; nextID += 1
                        waves.append(id)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                            waves.removeAll { $0 == id }
                        }
                    }
                }
            }
    }
}

/// One expanding ring of the brand sweep — self-animates on appear, then the parent removes it.
private struct RippleWave: View {
    @State private var animate = false
    var body: some View {
        Circle()
            .strokeBorder(Theme.Colors.primaryGradient, lineWidth: animate ? 1.5 : 7)
            .frame(width: animate ? 760 : 44, height: animate ? 760 : 44)
            .opacity(animate ? 0 : 0.85)
            .onAppear {
                withAnimation(.easeOut(duration: 1.25)) { animate = true }
            }
    }
}

/// A soft violet bloom behind the rings that fades out — gives the ripple a filled center.
private struct RippleWash: View {
    @State private var out = false
    var body: some View {
        Circle()
            .fill(RadialGradient(
                colors: [Theme.Colors.accent.opacity(0.5), .clear],
                center: .center, startRadius: 4, endRadius: 300))
            .frame(width: 560, height: 560)
            .opacity(out ? 0 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) { out = true }
            }
    }
}

extension View {
    func proteinRipple(trigger: Int, anchorY: CGFloat = 132) -> some View {
        modifier(ProteinRipple(trigger: trigger, anchorY: anchorY))
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

    /// A light/dark adaptive color from two hex literals — resolves per trait collection so a
    /// single token renders correctly in both appearances. e.g. `Color(light: 0xFFFFFF, dark: 0x1A1826)`
    init(light: UInt, dark: UInt) {
        self = Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
