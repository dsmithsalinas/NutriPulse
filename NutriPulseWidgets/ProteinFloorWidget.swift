import WidgetKit
import SwiftUI

// Brand colors, duplicated locally — the widget extension can't pull in the app's Theme.
private extension Color {
    static let pulseIndigo = Color(red: 0x63 / 255, green: 0x66 / 255, blue: 0xF1 / 255)
    static let pulseViolet = Color(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255)
}
private let pulseGradient = LinearGradient(
    colors: [.pulseIndigo, .pulseViolet], startPoint: .topLeading, endPoint: .bottomTrailing
)

// MARK: - Timeline

struct ProteinFloorEntry: TimelineEntry {
    let date: Date
    let snapshot: ProteinFloorSnapshot
}

struct ProteinFloorProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProteinFloorEntry {
        ProteinFloorEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProteinFloorEntry) -> Void) {
        completion(ProteinFloorEntry(date: .now, snapshot: SharedStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProteinFloorEntry>) -> Void) {
        let snapshot = SharedStore.load() ?? .placeholder
        let entry = ProteinFloorEntry(date: .now, snapshot: snapshot)
        // The app pushes an immediate reload on every change; this is just a safety refresh.
        let next = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct ProteinFloorWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ProteinFloorEntry
    private var snap: ProteinFloorSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryCircular:    circular
        case .accessoryRectangular: rectangular
        case .accessoryInline:      inline
        case .systemMedium:         medium
        default:                    small
        }
    }

    // Home Screen — small: the protein ring, hero.
    private var small: some View {
        VStack(spacing: 6) {
            ring(size: 74, line: 9)
            Text(snap.cleared ? "Floor cleared" : "\(snap.remaining)g to go")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(snap.cleared ? Color.green : .secondary)
                .minimumScaleFactor(0.8)
        }
    }

    // Home Screen — medium: ring + framing text side by side.
    private var medium: some View {
        HStack(spacing: 16) {
            ring(size: 92, line: 11)
            VStack(alignment: .leading, spacing: 4) {
                Text("PROTEIN FLOOR")
                    .font(.system(size: 11, weight: .bold)).tracking(0.8)
                    .foregroundStyle(Color.pulseIndigo)
                Text("\(Int(snap.proteinToday.rounded())) / \(Int(snap.proteinGoal.rounded()))g")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(snap.cleared
                     ? "Floor cleared — muscle protected."
                     : "\(snap.remaining)g to go protects your muscle.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // Lock Screen — circular gauge.
    private var circular: some View {
        Gauge(value: snap.pct) {
            Text("P")
        } currentValueLabel: {
            Text("\(Int(snap.proteinToday.rounded()))")
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    // Lock Screen — rectangular.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Protein floor").font(.system(size: 13, weight: .semibold))
            Text("\(Int(snap.proteinToday.rounded())) / \(Int(snap.proteinGoal.rounded()))g")
                .font(.system(size: 15, weight: .bold)).monospacedDigit()
            Text(snap.cleared ? "Cleared ✓" : "\(snap.remaining)g to go")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    // Lock Screen — inline (next to the clock).
    private var inline: some View {
        Text(snap.cleared
             ? "Protein floor cleared"
             : "Protein \(Int(snap.proteinToday.rounded()))/\(Int(snap.proteinGoal.rounded()))g")
    }

    // Shared ring.
    private func ring(size: CGFloat, line: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.2), lineWidth: line)
            Circle()
                .trim(from: 0, to: snap.pct)
                .stroke(pulseGradient, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(snap.proteinToday.rounded()))")
                    .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("/\(Int(snap.proteinGoal.rounded()))g")
                    .font(.system(size: size * 0.15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Widget

struct ProteinFloorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: proteinFloorWidgetKind, provider: ProteinFloorProvider()) { entry in
            ProteinFloorWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Protein Floor")
        .description("Your protein for today and how much is left to protect your muscle.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

@main
struct NutriPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        ProteinFloorWidget()
    }
}
