import SwiftUI

// A living indigo/violet aurora — a few large, blurred, screen-blended blobs that drift on a
// dark ground. Reserved for the injection ritual and the dose-day card; not a general surface.
// Honors Reduce Motion (blobs hold still).
struct AuroraView: View {
    var animated: Bool = true

    @State private var phase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Blob {
        let color: Color, size: CGFloat
        let from: CGPoint, to: CGPoint, dur: Double
    }

    // Positions/sizes are fractions of the container.
    private let blobs: [Blob] = [
        Blob(color: Color(hex: 0x6366F1), size: 0.95, from: CGPoint(x: 0.22, y: 0.24), to: CGPoint(x: 0.42, y: 0.38), dur: 7.5),
        Blob(color: Color(hex: 0x8B5CF6), size: 1.05, from: CGPoint(x: 0.80, y: 0.30), to: CGPoint(x: 0.60, y: 0.46), dur: 9.5),
        Blob(color: Color(hex: 0xC471F5), size: 0.85, from: CGPoint(x: 0.30, y: 0.86), to: CGPoint(x: 0.46, y: 0.70), dur: 8.5),
        Blob(color: Color(hex: 0x4F9DFF), size: 0.75, from: CGPoint(x: 0.76, y: 0.82), to: CGPoint(x: 0.60, y: 0.64), dur: 10.5),
    ]

    var body: some View {
        GeometryReader { geo in
            let s = max(geo.size.width, geo.size.height)
            ZStack {
                Color(hex: 0x0A0912)
                ForEach(blobs.indices, id: \.self) { i in
                    let b = blobs[i]
                    let active = animated && !reduceMotion && phase
                    Circle()
                        .fill(b.color)
                        .frame(width: s * b.size, height: s * b.size)
                        .position(
                            x: (active ? b.to.x : b.from.x) * geo.size.width,
                            y: (active ? b.to.y : b.from.y) * geo.size.height
                        )
                        .blur(radius: s * 0.11)
                        .blendMode(.screen)
                        .opacity(0.85)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: b.dur).repeatForever(autoreverses: true),
                            value: phase
                        )
                }
            }
            .drawingGroup()
        }
        .onAppear { phase = true }
    }
}
