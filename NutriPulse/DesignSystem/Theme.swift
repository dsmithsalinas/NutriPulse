import SwiftUI

// Central token system — change a value here and it updates everywhere.
// Same idea as a Tailwind theme or CSS custom properties.
enum Theme {

    // MARK: - Brand

    /// Daylight palette (docs/daylight-redesign.md): a bright, cool neutral ground, white tiles,
    /// deep indigo for the hero, lime for wins and logging, sky for water. The mockups are
    /// light-only; the dark values are our own, kept in the same slate family.
    enum Colors {
        /// Primary brand color — buttons, links, selected states.
        static let primary = Color(light: 0x4F46E5, dark: 0x6366F1)
        /// Secondary brand color — subtler accents.
        static let accent = Color(hex: 0x8B5CF6)

        /// Kept for screens not yet rebuilt. Daylight fills are flat, so this is now a near-solid
        /// indigo rather than the old indigo → violet sweep; new screens should use `primary`.
        static let primaryGradient = LinearGradient(
            colors: [Color(hex: 0x4F46E5), Color(hex: 0x4338CA)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Surfaces, built on system colors so light/dark mode keep working for free.
        static let background = Color(.systemBackground)
        static let surface = Color(.secondarySystemBackground)
        static let surfaceElevated = Color(.tertiarySystemBackground)

        static let textPrimary   = Color(light: 0x0F172A, dark: 0xF1F5F9)
        static let textSecondary = Color(light: 0x475569, dark: 0x94A3B8)

        // Slate neutrals — the page, tiles, and the lines between them.
        static let ground       = Color(light: 0xEEF1F6, dark: 0x0B1120)
        static let groundGlow   = Color(light: 0xE4E9F2, dark: 0x111827)
        static let surfaceCard  = Color(light: 0xFFFFFF, dark: 0x161E2E)
        static let surfaceInset = Color(light: 0xF1F5F9, dark: 0x1F2937)
        static let hairline     = Color(light: 0xE2E8F0, dark: 0x273244)
        static let ringTrack    = Color(light: 0xF1F5F9, dark: 0x1F2937)
        static let textFaint    = Color(light: 0x64748B, dark: 0x7C8AA0)
        /// Destructive actions and errors: sign out, delete, swipe-to-delete, validation. #B91C1C
        /// on white is ~5.9:1, AA for body text.
        static let danger       = Color(light: 0xB91C1C, dark: 0xF87171)
        /// Grams and other small indigo figures on white tiles (passes AA where `primary` is tight).
        static let primaryText  = Color(light: 0x4338CA, dark: 0xA5B4FC)
        /// A light indigo fill for secondary "+"/quick-action buttons on white rows (Log sheet
        /// Search and Favorites) — one step down from `primary`, for an action that's already
        /// available elsewhere (a food you've searched before, a "log again") rather than a
        /// primary call to action. Added for the Log sheet rebuild; genuinely missing before.
        static let primarySoft   = Color(light: 0xE0E7FF, dark: 0x2A2F5C)

        /// The Talk tab's live-listening accent (the recording dot, the stop control) — a warm
        /// rose distinct from system red. Fixed like the tile colors below. Added for the Log
        /// sheet rebuild; genuinely missing before.
        static let listening       = Color(hex: 0xFB7185)
        static let listeningAction = Color(hex: 0xE11D48)

        // MARK: Daylight feature tiles
        // Fixed (non-adaptive): these tiles are saturated fills that read the same on either ground.

        /// The dark floating tab bar and other "ink" surfaces.
        static let ink          = Color(light: 0x0F172A, dark: 0x1E293B)
        static let inkIcon      = Color(hex: 0xCBD5E1)

        /// Protein hero tile: deep indigo base, liquid fill in `hero`, pale indigo labels.
        static let heroDeep     = Color(hex: 0x1E1B4B)
        static let hero         = Color(hex: 0x4F46E5)
        static let heroLabel    = Color(hex: 0xC7D2FE)
        static let heroSubtext  = Color(hex: 0xE0E7FF)

        /// Lime: wins, the shot cycle, and the Log button.
        static let lime         = Color(hex: 0xD9F99D)
        static let limeInk      = Color(hex: 0x1A2E05)
        static let limeLabel    = Color(hex: 0x365314)
        static let limeLine     = Color(hex: 0x4D7C0F)

        /// Violet: the weekly recap.
        static let violet       = Color(hex: 0xEDE9FE)
        static let violetInk    = Color(hex: 0x2E1065)
        static let violetLabel  = Color(hex: 0x5B21B6)

        /// Sky: water.
        static let sky          = Color(hex: 0xE0F2FE)
        static let skyInk       = Color(hex: 0x0C4A6E)
        static let skyLabel     = Color(hex: 0x075985)
        static let skyAction    = Color(hex: 0x0284C7)
    }

    /// Ring/chart colors, tuned as one family instead of raw system colors.
    enum NutrientColor {
        static let calories = Color(hex: 0xFF7A59)
        static let protein  = Color(hex: 0x4F46E5)
        static let carbs    = Color(hex: 0x8B5CF6)
        static let fiber    = Color(hex: 0x22C55E)
        static let fat      = Color(hex: 0xF59E0B)
        static let water    = Color(hex: 0x0284C7)
    }

    // MARK: - Typography

    /// Bricolage Grotesque for display type and numbers, Figtree for everything else. Both are
    /// bundled (Resources/Fonts; Bricolage is the 96pt display cut). Sizes scale with Dynamic Type unless `relativeTo` is nil.
    enum Fonts {
        enum DisplayWeight: String {
            case medium = "Medium", bold = "Bold", extraBold = "ExtraBold"
        }
        enum BodyWeight: String {
            case regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold"
        }

        static func display(_ size: CGFloat, _ weight: DisplayWeight = .extraBold,
                            relativeTo style: Font.TextStyle? = .largeTitle) -> Font {
            custom("BricolageGrotesque96pt-\(weight.rawValue)", size, style)
        }

        /// Display face with tabular figures, for counts that change in place.
        static func number(_ size: CGFloat, _ weight: DisplayWeight = .extraBold,
                           relativeTo style: Font.TextStyle? = .title) -> Font {
            display(size, weight, relativeTo: style).monospacedDigit()
        }

        static func body(_ size: CGFloat, _ weight: BodyWeight = .regular,
                         relativeTo style: Font.TextStyle? = .body) -> Font {
            custom("Figtree-\(weight.rawValue)", size, style)
        }

        private static func custom(_ name: String, _ size: CGFloat, _ style: Font.TextStyle?) -> Font {
            if let style { return .custom(name, size: size, relativeTo: style) }
            return .custom(name, fixedSize: size)
        }
    }

    /// One scale for the whole app. New screens should reach for these
    /// instead of raw `.font(...)` calls.
    enum Typography {
        static let display  = Fonts.display(34, .extraBold, relativeTo: .largeTitle)
        static let title    = Fonts.display(22, .bold, relativeTo: .title2)
        static let headline = Fonts.body(17, .bold, relativeTo: .headline)
        static let body     = Fonts.body(17, .regular, relativeTo: .body)
        static let caption  = Fonts.body(13, .medium, relativeTo: .caption)
        /// Uppercase tile labels ("PROTEIN", "WATER") — pair with `.textCase(.uppercase)` and
        /// `Theme.Typography.eyebrowTracking`.
        static let eyebrow  = Fonts.body(12, .bold, relativeTo: .caption)
        static let eyebrowTracking: CGFloat = 1
    }

    // MARK: - Layout

    enum Spacing {
        static let xs: CGFloat  =  4
        static let sm: CGFloat  =  8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
        /// Side margin for Daylight screens, and the gap between tiles.
        static let page: CGFloat    = 20
        static let tileGap: CGFloat = 12
    }

    enum Radius {
        static let card: CGFloat   = 16
        static let button: CGFloat = 14
        /// Daylight tiles: large grid tiles, then list rows and small tiles.
        static let tile: CGFloat      = 28
        static let tileSmall: CGFloat = 22
        static let row: CGFloat       = 18
    }

    /// Daylight motion. Every use must check Reduce Motion (the components below do).
    enum Motion {
        /// Tiles spring in with a slight overshoot (mockup: cubic-bezier(.34,1.56,.64,1), 650 ms).
        static let pop = Animation.spring(response: 0.5, dampingFraction: 0.62)
        /// Delay between consecutive tiles' entrances.
        static let stagger: Double = 0.08
        /// Bars draw in from the leading edge with a small overshoot.
        static let draw = Animation.spring(response: 0.8, dampingFraction: 0.72)
        /// Numbers count up and liquid fills rise: fast start, long settle.
        static let fill = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 1.6)
        /// The tab bar's selection pill sliding between tabs.
        static let tabSelect = Animation.spring(response: 0.38, dampingFraction: 0.8)
    }

    enum Ring {
        static let size: CGFloat      = 72
        static let lineWidth: CGFloat =  8
    }
}

// MARK: - Component styles

/// Primary call-to-action button — Daylight solid indigo, white label, 52pt tall.
/// Respects `.disabled()` — falls back to a flat grey fill, same convention
/// every hand-rolled CTA button in the app used before this style existed.
/// Usage: `Button("Log it") { ... }.buttonStyle(.brandPrimary)`
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body(17, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(isEnabled ? Theme.Colors.primary : Theme.Colors.textFaint.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
/// Today/Analytics cards, promoted to a single reusable modifier. Now a Daylight white tile —
/// soft shadow, no border; new screens should use `.tile()` for the full radius and padding.
/// Usage: `content.card()`
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color(hex: 0x0F172A, opacity: 0.06), radius: 1, y: 1)
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
