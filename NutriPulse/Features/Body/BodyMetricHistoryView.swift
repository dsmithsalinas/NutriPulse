import SwiftUI
import Charts

// Which metric a hub row (and its history screen) is about. Weight/body-fat/lean come
// from their existing tables; measurement sites from body_measurement_logs.
enum BodyMetric: Hashable, Identifiable {
    case weight
    case bodyFat
    case leanMass
    case site(MeasurementSite)

    var id: String {
        switch self {
        case .weight:          return "weight"
        case .bodyFat:         return "bodyFat"
        case .leanMass:        return "leanMass"
        case .site(let site):  return "site.\(site.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .weight:         return "Weight"
        case .bodyFat:        return "Body fat"
        case .leanMass:       return "Lean mass"
        case .site(let site): return site.displayName
        }
    }

    var systemImage: String {
        switch self {
        case .weight:   return "scalemass"
        case .bodyFat:  return "percent"
        case .leanMass: return "dumbbell.fill"
        case .site:     return "ruler"
        }
    }

    var color: Color {
        switch self {
        case .weight:   return Theme.Colors.primary
        case .bodyFat:  return Theme.Colors.accent
        // Lean mass shares fiber's green deliberately — both are floors.
        case .leanMass: return Theme.NutrientColor.fiber
        case .site:     return Theme.NutrientColor.water
        }
    }

    // Storage value → display string ("184.6 lb", "28.4%", "38.2 in").
    func format(_ value: Double, units: UnitSystem) -> String {
        switch self {
        case .weight, .leanMass:
            return String(format: "%.1f %@", units.weightInput(from: value), units.weightUnit)
        case .bodyFat:
            return String(format: "%.1f%%", value)
        case .site:
            return String(format: "%.1f %@", units.lengthInput(fromCm: value), units.lengthUnit)
        }
    }

    func formatDelta(_ magnitude: Double, units: UnitSystem) -> String {
        switch self {
        case .bodyFat: return String(format: "%.1f", magnitude)
        default:       return format(magnitude, units: units)
        }
    }

    // "goal" for targets, "floor" for lean mass — the word carries the semantics.
    var goalNoun: String {
        if case .leanMass = self { return "floor" }
        return "goal"
    }
}

// Full history for one metric: a real chart plus the entries behind it. Self-contained —
// fetches its own data so it can be pushed from anywhere. This is also where goal lines
// will land in the goals phase.
struct BodyMetricHistoryView: View {
    let metric: BodyMetric

    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    struct Entry: Identifiable {
        let id: UUID
        let date: Date
        let value: Double        // storage units
        let source: String       // "manual" | "healthkit"
        let deletable: Bool      // only measurement rows support delete today
    }

    @State private var entries: [Entry] = []
    @State private var goalValue: Double? = nil   // storage units; nil for measurement sites
    @State private var isLoading = false

    private let measurementRepo = BodyMeasurementRepository()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if entries.count >= 2 {
                    chartCard
                }
                entriesCard
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
        .task { await load() }
        .overlay { if isLoading && entries.isEmpty { ProgressView() } }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Chart(entries) { entry in
                LineMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value(metric.title, displayValue(entry.value))
                )
                .foregroundStyle(metric.color)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value(metric.title, displayValue(entry.value))
                )
                .foregroundStyle(metric.color)
                .symbolSize(40)

                // The goal line — same dashed grammar as the calorie goal in Analytics.
                // Deliberately no shading above or below it: a line to approach, not a
                // zone to be in or out of.
                if let goalValue {
                    RuleMark(y: .value(metric.goalNoun.capitalized, displayValue(goalValue)))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .annotation(
                            position: .top,
                            alignment: .leading,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            Text(metric.goalNoun.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 180)
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("ENTRIES")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.Colors.textFaint)

            if entries.isEmpty && !isLoading {
                Text("Nothing logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.Spacing.sm)
            }

            // Newest first, capped — this is a recent-history readout, not an archive.
            ForEach(entries.suffix(30).reversed()) { entry in
                HStack {
                    Text(entry.date.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.subheadline)
                    Spacer()
                    Text(metric.format(entry.value, units: units))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                    sourceBadge(entry.source)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .contextMenu {
                    if entry.deletable {
                        Button(role: .destructive) {
                            Task { await delete(entry) }
                        } label: {
                            Label("Delete entry", systemImage: "trash")
                        }
                    }
                }
                Divider()
            }
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    private func sourceBadge(_ source: String) -> some View {
        Text(source == "healthkit" ? "Health" : "Manual")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(source == "healthkit" ? Color.pink : Theme.Colors.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background((source == "healthkit" ? Color.pink : Theme.Colors.primary).opacity(0.12))
            .clipShape(Capsule())
    }

    // The chart plots display units so the axis labels read naturally.
    private func displayValue(_ storage: Double) -> Double {
        switch metric {
        case .weight, .leanMass: return units.weightInput(from: storage)
        case .bodyFat:           return storage
        case .site:              return units.lengthInput(fromCm: storage)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        let goals = try? await BodyGoalsRepository().fetch()
        switch metric {
        case .weight:   goalValue = goals?.weightKgTarget
        case .bodyFat:  goalValue = goals?.bodyFatPctTarget
        case .leanMass: goalValue = goals?.leanMassKgFloor
        case .site:     goalValue = nil
        }

        switch metric {
        case .weight:
            let logs = (try? await AnalyticsRepository().fetchWeightLogs(days: 1095)) ?? []
            entries = logs.map {
                Entry(id: $0.id, date: $0.loggedAt, value: $0.weightKg, source: $0.source, deletable: false)
            }
        case .bodyFat:
            let logs = (try? await BodyCompositionRepository().fetchHistory(days: 1095)) ?? []
            entries = logs.compactMap { log in
                guard let pct = log.bodyFatPct, let date = Date.fromISODateString(log.logDate) else { return nil }
                return Entry(id: log.id, date: date, value: pct, source: log.source, deletable: false)
            }
        case .leanMass:
            let logs = (try? await BodyCompositionRepository().fetchHistory(days: 1095)) ?? []
            entries = logs.compactMap { log in
                guard let kg = log.leanBodyMassKg, let date = Date.fromISODateString(log.logDate) else { return nil }
                return Entry(id: log.id, date: date, value: kg, source: log.source, deletable: false)
            }
        case .site(let site):
            let logs = (try? await measurementRepo.fetchHistory(site: site, days: 1095)) ?? []
            entries = logs.compactMap { log in
                guard let date = Date.fromISODateString(log.logDate) else { return nil }
                return Entry(id: log.id, date: date, value: log.valueCm, source: log.source, deletable: true)
            }
        }
    }

    private func delete(_ entry: Entry) async {
        guard entry.deletable else { return }
        try? await measurementRepo.delete(id: entry.id)
        await load()
    }
}
