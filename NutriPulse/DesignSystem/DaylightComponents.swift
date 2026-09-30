import SwiftUI

// Daylight building blocks (docs/daylight-redesign.md). Screens compose these rather than
// re-deriving radii, shadows, and motion. Every animation here is skipped under Reduce Motion.

// MARK: - Tile

/// A Daylight tile: a filled, continuous-cornered panel. White tiles carry a hairline shadow;
/// colored tiles (hero, lime, sky) sit flat, as in the mockups.
/// Usage: `content.tile()` or `content.tile(Theme.Colors.lime, shadow: false)`
struct TileStyle: ViewModifier {
    var fill: Color = Theme.Colors.surfaceCard
    var radius: CGFloat = Theme.Radius.tile
    var padding: CGFloat = 16
    var shadow: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: shadow ? Color(hex: 0x0F172A, opacity: 0.06) : .clear, radius: 1, y: 1)
    }
}

extension View {
    func tile(_ fill: Color = Theme.Colors.surfaceCard,
              radius: CGFloat = Theme.Radius.tile,
              padding: CGFloat = 16,
              shadow: Bool = true) -> some View {
        modifier(TileStyle(fill: fill, radius: radius, padding: padding, shadow: shadow))
    }
}

/// The small uppercase label at the top of a tile ("PROTEIN", "WATER").
struct TileEyebrow: View {
    let text: String
    var color: Color = Theme.Colors.textSecondary

    init(_ text: String, color: Color = Theme.Colors.textSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(Theme.Typography.eyebrow)
            .tracking(Theme.Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Entrance

/// Tiles spring in with a slight overshoot, one after another. `order` sets the stagger
/// (0 = first). Runs once per view identity.
/// Usage: `tile.popIn(order: 2)`
struct PopIn: ViewModifier {
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let visible = shown || reduceMotion
        content
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.9)
            .offset(y: visible ? 0 : 10)
            .onAppear {
                guard !shown, !reduceMotion else { return }
                withAnimation(Theme.Motion.pop.delay(Double(order) * Theme.Motion.stagger)) {
                    shown = true
                }
            }
    }
}

extension View {
    func popIn(order: Int = 0) -> some View {
        modifier(PopIn(order: order))
    }
}

// MARK: - Meter bar

/// A rounded progress bar that draws in from the leading edge on first appear and springs to
/// new values after that. `progress` is clamped to 0…1.
struct MeterBar: View {
    let progress: Double
    var color: Color = Theme.Colors.primary
    var track: Color = Theme.Colors.surfaceInset
    var height: CGFloat = 8
    /// Wait before the first draw-in, so bars start after their tile has landed.
    var delay: Double = 0.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(track)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * clamped)
                        .scaleEffect(x: drawn || reduceMotion ? 1 : 0, anchor: .leading)
                }
                .clipShape(Capsule())
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : Theme.Motion.draw, value: clamped)
        .onAppear {
            guard !drawn, !reduceMotion else { return }
            withAnimation(Theme.Motion.draw.delay(delay)) { drawn = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Chart draw-in

/// Reveals a Swift Charts plot from the leading edge on first appear, the chart counterpart of
/// `MeterBar`'s draw-in. Under Reduce Motion it's simply shown.
/// Usage: `Chart { ... }.chartDrawIn()`
struct ChartDrawIn: ViewModifier {
    private static let outset: CGFloat = 24
    var delay: Double = 0.1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .mask(alignment: .leading) {
                // Outset past the frame: Swift Charts draws edge axis labels (the top y value)
                // slightly outside the chart's bounds, and a mask cut exactly to size clipped them.
                GeometryReader { geo in
                    Rectangle()
                        .frame(width: (geo.size.width + Self.outset * 2) * (revealed || reduceMotion ? 1 : 0),
                               height: geo.size.height + Self.outset * 2)
                        .offset(x: -Self.outset, y: -Self.outset)
                }
            }
            .onAppear {
                guard !revealed, !reduceMotion else { revealed = true; return }
                withAnimation(Theme.Motion.draw.delay(delay)) { revealed = true }
            }
    }
}

extension View {
    func chartDrawIn(delay: Double = 0.1) -> some View { modifier(ChartDrawIn(delay: delay)) }
}

// MARK: - Counting number

/// A whole number that counts up from zero on first appear, then animates between values when
/// it changes (e.g. after a log). Under Reduce Motion it just shows the value.
/// Usage: `CountingNumber(value: 112, font: Theme.Fonts.number(60))`
struct CountingNumber: View {
    let value: Int
    var font: Font = Theme.Fonts.number(24)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        CountingText(value: reduceMotion ? Double(value) : shown)
            .font(font)
            .onAppear { animate(to: value) }
            .onChange(of: value) { _, new in animate(to: new) }
            .accessibilityLabel("\(value)")
    }

    private func animate(to target: Int) {
        guard !reduceMotion else { shown = Double(target); return }
        withAnimation(Theme.Motion.fill) { shown = Double(target) }
    }
}

/// Interpolates the displayed number frame by frame so the digits tick rather than cross-fade.
private struct CountingText: View, Animatable {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))")
    }
}

// MARK: - Flow layout

/// Lays children out left to right, wrapping onto new lines — for chip rows whose count or
/// label widths vary (Pulse's topics, filter chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

// MARK: - Previews

#Preview("Daylight components") {
    ScrollView {
        VStack(spacing: Theme.Spacing.tileGap) {
            HStack(spacing: Theme.Spacing.tileGap) {
                VStack(alignment: .leading, spacing: 8) {
                    TileEyebrow("Protein", color: Theme.Colors.heroLabel)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        CountingNumber(value: 112, font: Theme.Fonts.number(60))
                        Text("g").font(Theme.Fonts.display(22))
                    }
                    .foregroundStyle(.white)
                    Text("28g to go")
                        .font(Theme.Fonts.body(14, .semibold))
                        .foregroundStyle(Theme.Colors.heroSubtext)
                }
                .frame(height: 200, alignment: .topLeading)
                .tile(Theme.Colors.heroDeep, shadow: false)
                .popIn(order: 0)

                VStack(alignment: .leading, spacing: 10) {
                    TileEyebrow("Calories")
                    MeterBar(progress: 0.77, color: Theme.NutrientColor.calories)
                    MeterBar(progress: 0.69, color: Theme.NutrientColor.carbs, height: 5)
                    MeterBar(progress: 0.74, color: Theme.NutrientColor.fat, height: 5)
                    MeterBar(progress: 0.64, color: Theme.NutrientColor.fiber, height: 5)
                }
                .frame(height: 200, alignment: .topLeading)
                .tile()
                .popIn(order: 1)
            }
            Text("Day 3 of 7")
                .font(Theme.Fonts.display(22, .bold))
                .foregroundStyle(Theme.Colors.limeInk)
                .tile(Theme.Colors.lime, shadow: false)
                .popIn(order: 2)
        }
        .padding(Theme.Spacing.page)
    }
    .background(Theme.Colors.ground)
}
