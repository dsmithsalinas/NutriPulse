import SwiftUI
import WidgetKit

// The Protein Floor widget's views, in Daylight (docs/daylight-redesign.md): the same deep
// indigo protein tile with its liquid fill as Today, Bricolage numbers, lime for logging and
// sky for water. In Shared/ so the app can render them too (DEBUG `--widget-preview`); the
// widget extension wraps them in its timeline and container background.

struct ProteinFloorWidgetView: View {
    let snapshot: ProteinFloorSnapshot
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:    circular
        case .accessoryRectangular: rectangular
        case .accessoryInline:      inline
        case .systemMedium:         medium
        default:                    small
        }
    }

    private var status: String {
        snapshot.cleared ? "Floor cleared" : "\(snapshot.remaining)g to go"
    }

    // MARK: Home Screen

    // Small: the Today protein tile on its own. The liquid fill is the background, drawn by
    // `ProteinFloorWidgetBackground`.
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PROTEIN")
                    .font(Theme.Fonts.body(11, .bold, relativeTo: nil))
                    .tracking(1)
                    .foregroundStyle(Theme.Colors.heroLabel)
                Spacer(minLength: 4)
                Text("floor \(Int(snapshot.proteinGoal.rounded()))")
                    .font(Theme.Fonts.body(11, .semibold, relativeTo: nil))
                    .foregroundStyle(Theme.Colors.heroLabel)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(Int(snapshot.proteinToday.rounded()))")
                    .font(Theme.Fonts.display(46, .extraBold, relativeTo: nil))
                    .monospacedDigit()
                Text("g")
                    .font(Theme.Fonts.display(18, .extraBold, relativeTo: nil))
            }
            .foregroundStyle(.white)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .widgetAccentable()
            Text(status)
                .font(Theme.Fonts.body(13, .semibold, relativeTo: nil))
                .foregroundStyle(snapshot.cleared ? Theme.Colors.lime : Theme.Colors.heroSubtext)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Protein \(Int(snapshot.proteinToday.rounded())) of \(Int(snapshot.proteinGoal.rounded())) grams. \(status)")
    }

    // Medium: the protein tile beside the quick actions, on the page ground like Today.
    private var medium: some View {
        HStack(spacing: 10) {
            ZStack {
                ProteinFloorWidgetBackground(snapshot: snapshot)
                small.padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 8) {
                Button(intent: FootingQuickActionIntent(action: primaryAction)) {
                    HStack(spacing: 6) {
                        Image(systemName: primaryIcon)
                            .font(.system(size: 15, weight: .bold))
                        Text(primaryLabel)
                            .font(Theme.Fonts.body(14, .bold, relativeTo: nil))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Theme.Colors.limeInk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.lime, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(primaryLabel)

                HStack(spacing: 8) {
                    quickAction(.addWater, icon: "drop.fill", label: "Add water",
                                fill: Theme.Colors.sky, ink: Theme.Colors.skyAction)
                    quickAction(.logDose, icon: "syringe.fill", label: "Log dose",
                                fill: Theme.Colors.surfaceCard, ink: Theme.Colors.hero)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var primaryAction: FootingQuickAction {
        !snapshot.cleared && snapshot.remaining <= 45 ? .logFavorite : .talkToLog
    }
    private var primaryIcon: String { primaryAction == .logFavorite ? "star.fill" : "plus" }
    private var primaryLabel: String { primaryAction == .logFavorite ? "Close floor" : "Log food" }

    private func quickAction(_ action: FootingQuickAction, icon: String, label: String,
                             fill: Color, ink: Color) -> some View {
        Button(intent: FootingQuickActionIntent(action: action)) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Lock Screen (system-tinted; fonts and shapes carry the design)

    private var circular: some View {
        Gauge(value: snapshot.pct) {
            PulseMark(lineWidthRatio: 0.18).frame(width: 10, height: 10)
        } currentValueLabel: {
            Text("\(Int(snapshot.proteinToday.rounded()))")
                .font(Theme.Fonts.display(17, .extraBold, relativeTo: nil))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityLabel("Protein \(Int(snapshot.proteinToday.rounded())) grams. \(status)")
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("PROTEIN FLOOR")
                .font(Theme.Fonts.body(11, .bold, relativeTo: nil))
                .tracking(0.8)
                .widgetAccentable()
            Text("\(Int(snapshot.proteinToday.rounded())) / \(Int(snapshot.proteinGoal.rounded()))g")
                .font(Theme.Fonts.display(19, .extraBold, relativeTo: nil))
                .monospacedDigit()
            Text(status)
                .font(Theme.Fonts.body(12, .semibold, relativeTo: nil))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Text(snapshot.cleared
             ? "Protein floor cleared"
             : "Protein \(Int(snapshot.proteinToday.rounded()))/\(Int(snapshot.proteinGoal.rounded()))g")
    }
}

/// The small widget's background: deep indigo with today's protein as liquid, the same as the
/// Today tile (still, since widgets don't animate).
struct ProteinFloorWidgetBackground: View {
    let snapshot: ProteinFloorSnapshot

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.heroDeep
            StillLiquid(level: snapshot.pct).fill(Theme.Colors.hero)
        }
    }
}

private struct StillLiquid: Shape {
    let level: Double

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(level, 0), 1)
        guard clamped > 0 else { return Path() }
        let surface = rect.maxY - rect.height * CGFloat(clamped)
        let wavelength = rect.width / 1.4
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: surface))
        var x = rect.minX
        while x <= rect.maxX {
            let angle = Double(x / wavelength) * 2 * .pi
            path.addLine(to: CGPoint(x: x, y: surface + CGFloat(sin(angle)) * 4))
            x += 2
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
