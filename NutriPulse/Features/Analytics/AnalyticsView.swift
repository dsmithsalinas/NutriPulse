import SwiftUI
import Charts

struct AnalyticsView: View {
    let embeddedInNavigation: Bool
    @State private var vm: AnalyticsViewModel
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    init(
        embeddedInNavigation: Bool = false,
        initialRange: AnalyticsViewModel.TimeRange = .week
    ) {
        self.embeddedInNavigation = embeddedInNavigation
        _vm = State(initialValue: AnalyticsViewModel(selectedRange: initialRange))
    }

    @ViewBuilder
    var body: some View {
        if embeddedInNavigation {
            content
        } else {
            NavigationStack { content }
        }
    }

    private var content: some View {
            // The spinner used to REPLACE the ScrollView — and the range Picker lives inside
            // it — so every tap on a range flashed the whole screen, picker included, to a
            // bare ProgressView. Keep the content mounted and overlay the spinner instead.
            ScrollView {
                VStack(spacing: Theme.Spacing.tileGap) {
                    DaylightPageTitle("Analytics")
                        .popIn(order: 0)
                    Picker("Range", selection: $vm.selectedRange) {
                        ForEach(AnalyticsViewModel.TimeRange.allCases) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .popIn(order: 1)

                    if vm.cycleInsights.count >= 2 {
                        CycleAwareAnalyticsCard(
                            insights: vm.cycleInsights,
                            proteinGoal: vm.goalProteinG
                        )
                        .popIn(order: 2)
                    }

                    if !vm.loggedDays.isEmpty {
                        AnalyticsSummaryCard(
                            avgProtein:   vm.averageProteinG,
                            goalProtein:  vm.goalProteinG,
                            avgCalories:  vm.averageCalories,
                            goalCalories: vm.goalCalories
                        )
                        .popIn(order: 3)
                    }

                    CaloriesChartCard(
                        summaries:    vm.summaries,
                        goalCalories: vm.goalCalories,
                        average:      vm.averageCalories
                    )
                    .popIn(order: 4)

                    MacrosChartCard(summaries: vm.summaries)
                        .popIn(order: 5)

                    if !vm.activeDays.isEmpty {
                        MovementChartCard(
                            movement: vm.movement,
                            sessions: vm.totalWorkoutSessions,
                            avgMinutes: vm.avgMinutesPerActiveDay
                        )
                        .popIn(order: 6)
                    }

                    if !vm.weightLogs.isEmpty {
                        WeightChartCard(
                            logs:   vm.weightLogs,
                            change: vm.weightChange,
                            units:  units
                        )
                        .popIn(order: 7)
                    }

                    if !vm.bodyFatLogs.isEmpty {
                        BodyFatChartCard(logs: vm.bodyFatLogs)
                            .popIn(order: 8)
                    }

                    if !vm.glp1History.isEmpty {
                        GLP1DoseChartCard(logs: vm.glp1History)
                            .popIn(order: 9)
                    }

                    if vm.loggedDays.isEmpty && !vm.isLoading {
                        emptyState
                    }
                }
                .padding(Theme.Spacing.page)
                .padding(.bottom, Theme.Spacing.xl)
                .opacity(vm.isLoading ? 0.35 : 1)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .overlay {
                if vm.isLoading { ProgressView() }
            }
            .daylightSubpage("Analytics")
            .task(id: vm.selectedRange) {
                await vm.loadData()
            }
        .tint(Theme.Colors.primary)
    }

    private var emptyState: some View {
        BrandedEmptyState(
            icon: "chart.line.uptrend.xyaxis",
            title: "No trends yet",
            message: "Log a few days of meals and your protein, calorie, and weight trends will grow here."
        )
    }
}

// MARK: - Summary hero

// Opens Analytics with the thesis, not a chart: average protein (the priority metric for a
// GLP-1 user) as the hero, with average calories alongside.
private struct AnalyticsSummaryCard: View {
    let avgProtein: Double
    let goalProtein: Double?
    let avgCalories: Double
    let goalCalories: Double?

    private var proteinPct: Int? {
        guard let g = goalProtein, g > 0, avgProtein > 0 else { return nil }
        return Int((avgProtein / g * 100).rounded())
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.tileGap) {
            tile(
                title: "Avg protein",
                value: Int(avgProtein.rounded()),
                unit: "g",
                sub: proteinPct.map { "\($0)% of goal" } ?? "Set a goal",
                valueColor: Theme.Colors.primaryText
            )
            tile(
                title: "Avg calories",
                value: Int(avgCalories.rounded()),
                unit: nil,
                sub: goalCalories.map { "Goal \(Int($0))" } ?? "No goal set",
                valueColor: Theme.Colors.textPrimary
            )
        }
    }

    private func tile(title: String, value: Int, unit: String?, sub: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TileEyebrow(title)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                // CountingNumber owns the roll animation when the range changes (7 → 14 → 30
                // days), so the tile doesn't need its own `.animation`.
                CountingNumber(value: value, font: Theme.Fonts.number(30, .bold, relativeTo: .title))
                    .foregroundStyle(valueColor)
                if let unit {
                    Text(unit)
                        .font(Theme.Fonts.display(18, relativeTo: .title3))
                        .foregroundStyle(valueColor)
                }
            }
            Text(sub)
                .font(Theme.Fonts.body(12, .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tile()
    }
}


// MARK: - Calories chart

private struct CaloriesChartCard: View {
    let summaries: [DailySummary]
    let goalCalories: Double?
    let average: Double

    private var xAxisStride: Int {
        switch summaries.count {
        case ..<8:  return 1
        case ..<15: return 2
        default:    return 7
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Calories")
                    .font(Theme.Fonts.body(17, .bold, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if average > 0 {
                    Text("Avg \(Int(average)) kcal / day")
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Chart {
                ForEach(summaries) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("kcal", day.calories)
                    )
                    .foregroundStyle(Theme.NutrientColor.calories.gradient)
                    .cornerRadius(3)
                }
                if let goal = goalCalories {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(Theme.Colors.textFaint.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        // overflowResolution keeps the label inside the plot area — at
                        // .topLeading it used to spill past the left edge and render clipped
                        // ("oal" instead of "Goal").
                        .annotation(
                            position: .top,
                            alignment: .leading,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            Text("Goal")
                                .font(Theme.Fonts.body(11))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xAxisStride)) {
                    AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                        .foregroundStyle(Theme.Colors.textFaint)
                    AxisGridLine().foregroundStyle(Theme.Colors.hairline)
                }
            }
            .frame(height: 160)
            .chartDrawIn()
        }
        .tile()
    }
}

// MARK: - Macros chart

private struct MacrosChartCard: View {
    let summaries: [DailySummary]

    private struct MacroPoint: Identifiable {
        let id = UUID()
        let date: Date
        let macro: String
        let value: Double
    }

    private var chartData: [MacroPoint] {
        // Only include days where the user logged food
        summaries.filter(\.hasData).flatMap { day in [
            MacroPoint(date: day.date, macro: "Protein", value: day.proteinG),
            MacroPoint(date: day.date, macro: "Carbs",   value: day.carbsG),
            MacroPoint(date: day.date, macro: "Fat",     value: day.fatG),
        ]}
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Macros")
                .font(Theme.Fonts.body(17, .bold, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.textPrimary)

            if chartData.isEmpty {
                Text("No data")
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.textFaint)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(chartData) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("g", point.value)
                    )
                    .foregroundStyle(by: .value("Macro", point.macro))
                    .interpolationMethod(.catmullRom)
                    .symbol(by: .value("Macro", point.macro))
                    .symbolSize(30)
                }
                .chartForegroundStyleScale([
                    "Protein": Theme.NutrientColor.protein,
                    "Carbs":   Theme.NutrientColor.carbs,
                    "Fat":     Theme.NutrientColor.fat,
                ])
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel("\(value.as(Double.self).map { Int($0) } ?? 0)g")
                            .foregroundStyle(Theme.Colors.textFaint)
                        AxisGridLine().foregroundStyle(Theme.Colors.hairline)
                    }
                }
                .frame(height: 160)
                .chartDrawIn()
            }
        }
        .tile()
    }
}

// MARK: - Movement chart

// Minutes per day, deliberately goal-free: movement has no target line or "should have"
// framing anywhere in the app — the chart shows what happened, nothing else.
private struct MovementChartCard: View {
    let movement: [DailyMovement]
    let sessions: Int
    let avgMinutes: Double

    private var xAxisStride: Int {
        switch movement.count {
        case ..<8:  return 1
        case ..<15: return 2
        default:    return 7
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Movement")
                    .font(Theme.Fonts.body(17, .bold, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(sessions) session\(sessions == 1 ? "" : "s") · avg \(Int(avgMinutes.rounded())) min")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Chart(movement) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("min", day.minutes)
                )
                .foregroundStyle(Theme.Colors.primary.gradient)
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xAxisStride)) {
                    AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                        .foregroundStyle(Theme.Colors.textFaint)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel("\(value.as(Double.self).map { Int($0) } ?? 0)m")
                        .foregroundStyle(Theme.Colors.textFaint)
                    AxisGridLine().foregroundStyle(Theme.Colors.hairline)
                }
            }
            .frame(height: 140)
            .chartDrawIn()
        }
        .tile()
    }
}

// MARK: - Weight chart

// MARK: - Body fat chart

private struct BodyFatChartCard: View {
    let logs: [(date: Date, pct: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Body Fat %")
                .font(Theme.Fonts.body(17, .bold, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.textPrimary)

            Chart(logs, id: \.date) { entry in
                LineMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("%", entry.pct)
                )
                .foregroundStyle(Theme.Colors.accent)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("%", entry.pct)
                )
                .foregroundStyle(Theme.Colors.accent)
                .symbolSize(40)
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel("\(value.as(Double.self).map { String(format: "%.0f", $0) } ?? "")%")
                        .foregroundStyle(Theme.Colors.textFaint)
                    AxisGridLine().foregroundStyle(Theme.Colors.hairline)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 140)
            .chartDrawIn()
        }
        .tile()
    }
}

// MARK: - GLP-1 dose titration chart

private struct GLP1DoseChartCard: View {
    let logs: [GLP1Log]

    // Up to four medications get their own line; the Daylight family, not raw system hues.
    private static let palette: [Color] = [
        Theme.Colors.primary, Theme.Colors.accent, Theme.NutrientColor.fiber, Theme.NutrientColor.water,
    ]

    private var sortedMedications: [String] {
        Array(Set(logs.map(\.medication))).sorted()
    }

    private func color(for medication: String) -> Color {
        let idx = sortedMedications.firstIndex(of: medication) ?? 0
        return Self.palette[idx % Self.palette.count]
    }

    // A titration "curve" needs at least two doses. With one, Swift Charts' automatic
    // domain degenerates: the y-axis inverts (higher dose plots lower) and a single-day
    // x-domain renders hours-of-the-day ticks — which is exactly what a just-started GLP-1
    // user, the person this card is FOR, sees. Show an encouraging summary until there's a
    // real trend to plot.
    private var hasTrend: Bool { logs.count >= 2 }

    // An explicit ascending domain, padded around the logged doses, so the axis can never
    // invert and a flat (same-dose) stretch still reads sensibly.
    private var doseDomain: ClosedRange<Double> {
        let doses = logs.map(\.doseMg)
        let lo = max(0, (doses.min() ?? 0) - 0.5)
        let hi = (doses.max() ?? 1) + 0.5
        return lo...(hi > lo ? hi : lo + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(hasTrend ? "GLP-1 Dose Titration" : "GLP-1 Dose")
                .font(Theme.Fonts.body(17, .bold, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.textPrimary)

            if hasTrend {
                chart
            } else {
                singleDoseSummary
            }

            if sortedMedications.count > 1 {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(sortedMedications, id: \.self) { med in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color(for: med))
                                .frame(width: 8, height: 8)
                            Text(med)
                                .font(Theme.Fonts.body(11))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .tile()
    }

    private var chart: some View {
        Chart(logs) { log in
            // `series:` splits the line per medication. Without it, all logs joined into
            // one connected line, so switching Ozempic 2.0 mg → Zepbound 2.5 mg drew a
            // continuous step implying a dose continuity that doesn't exist — they're
            // different molecules and the milligrams aren't comparable. The legend below
            // already implied separate series.
            LineMark(
                x: .value("Date", log.injectedAt, unit: .day),
                y: .value("mg", log.doseMg),
                series: .value("Medication", log.medication)
            )
            .foregroundStyle(color(for: log.medication))
            .interpolationMethod(.stepEnd)

            PointMark(
                x: .value("Date", log.injectedAt, unit: .day),
                y: .value("mg", log.doseMg)
            )
            .foregroundStyle(color(for: log.medication))
            .symbolSize(40)
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel("\(value.as(Double.self)?.glp1DoseString ?? "")mg")
                    .foregroundStyle(Theme.Colors.textFaint)
                AxisGridLine().foregroundStyle(Theme.Colors.hairline)
            }
        }
        .chartYScale(domain: doseDomain)
        .frame(height: 160)
        .chartDrawIn()
    }

    // Shown until a second dose exists. Leads with the current dose and frames the empty
    // chart as something that fills in — not a failure, not "no data".
    private var singleDoseSummary: some View {
        let latest = logs.max(by: { $0.injectedAt < $1.injectedAt })
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let latest {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(latest.doseMg.glp1DoseString) mg")
                        .font(Theme.Typography.title)
                        .foregroundStyle(color(for: latest.medication))
                    Text(latest.medication)
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Text("Current dose · started \(latest.injectedAt.formatted(.dateTime.month().day()))")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Text("Your titration curve builds here as you log each dose.")
                .font(Theme.Fonts.body(13))
                .foregroundStyle(Theme.Colors.textFaint)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Weight chart

private struct WeightChartCard: View {
    let logs: [WeightLog]
    let change: Double?
    let units: UnitSystem

    // weightInput is linear (kg or kg·2.20462), so it converts a delta as correctly as an
    // absolute value. Sign is preserved, so the green/orange test still keys off raw `change`.
    private var unit: String { units.weightUnit }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Weight")
                    .font(Theme.Fonts.body(17, .bold, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if let change {
                    Text(String(format: "%+.1f \(unit)", units.weightInput(from: change)))
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(change <= 0 ? .green : .orange)
                }
            }

            Chart(logs) { log in
                LineMark(
                    x: .value("Date", log.loggedAt, unit: .day),
                    y: .value(unit, units.weightInput(from: log.weightKg))
                )
                .foregroundStyle(Theme.NutrientColor.protein)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", log.loggedAt, unit: .day),
                    y: .value(unit, units.weightInput(from: log.weightKg))
                )
                .foregroundStyle(Theme.NutrientColor.protein)
                .symbolSize(40)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 140)
            .chartDrawIn()
        }
        .tile()
    }
}
