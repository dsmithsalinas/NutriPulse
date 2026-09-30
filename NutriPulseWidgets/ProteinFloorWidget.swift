import WidgetKit
import SwiftUI
import AppIntents

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

// The views live in Shared/ProteinFloorWidgetViews.swift (Daylight), so the app can preview them.
struct ProteinFloorWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ProteinFloorEntry

    var body: some View {
        ProteinFloorWidgetView(snapshot: entry.snapshot, family: family)
    }
}

// MARK: - Widget

struct ProteinFloorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: proteinFloorWidgetKind, provider: ProteinFloorProvider()) { entry in
            ProteinFloorWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    ContainerBackground(snapshot: entry.snapshot)
                }
        }
        .configurationDisplayName("Protein Floor")
        .description("Your protein for today and how much is left to protect your muscle.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

/// Small: the protein tile's indigo and liquid fill. Medium: the Today page ground, with the tile
/// drawn inside. Lock Screen families ignore this (the system tints them).
private struct ContainerBackground: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: ProteinFloorSnapshot

    var body: some View {
        if family == .systemSmall {
            ProteinFloorWidgetBackground(snapshot: snapshot)
        } else {
            Theme.Colors.ground
        }
    }
}

@main
struct FootingWidgetBundle: WidgetBundle {
    var body: some Widget {
        ProteinFloorWidget()
    }
}
