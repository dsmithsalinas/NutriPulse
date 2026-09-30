import SwiftUI

// The Footing "Pulse" mark (mark-indigo.svg) drawn in SwiftUI so it tints with foreground
// style — a track ring, a ~250° progress arc, and the dot where the arc ends. In Shared/ so
// the widget draws the same mark.
struct PulseMark: View {
    var lineWidthRatio: CGFloat = 0.14

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let lw = s * lineWidthRatio
            let r = (s - lw) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            // The arc (trim 0…0.694 from the top, clockwise) ends at 160°; the dot sits there.
            let end = Angle.degrees(160)
            let dot = CGPoint(
                x: center.x + r * CGFloat(cos(end.radians)),
                y: center.y + r * CGFloat(sin(end.radians))
            )
            ZStack {
                Circle()
                    .stroke(lineWidth: lw)
                    .opacity(0.28)
                    .frame(width: 2 * r, height: 2 * r)
                    .position(center)
                Circle()
                    .trim(from: 0, to: 0.694)
                    .stroke(style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 2 * r, height: 2 * r)
                    .position(center)
                Circle()
                    .frame(width: lw * 1.7, height: lw * 1.7)
                    .position(dot)
            }
        }
    }
}
