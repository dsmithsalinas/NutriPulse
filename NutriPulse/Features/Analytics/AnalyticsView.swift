import SwiftUI
import Charts

// Analytics as questions, not a stack of charts (docs/daylight-redesign.md): a row of chips —
// one selected at a time — each opening a single focused card with a heading, a plain-English
// takeaway computed honestly from the loaded data, the chart, and a way to hand the question to
// Pulse. See AnalyticsQuestions.swift for the pure logic behind each takeaway.

enum AnalyticsQuestion: String, CaseIterable, Identifiable {
    case shotDays        = "How do shot days change my eating?"
    case proteinSources  = "Where does my protein come from?"
    case weightTrend     = "Is my weight trend real?"
    case proteinCalories = "Am I hitting protein and calories?"
    case movement        = "Am I moving more?"
    case bodyComposition = "How's my body composition?"

    var id: String { rawValue }
}

struct AnalyticsView: View {
    let embeddedInNavigation: Bool
    @State private var vm: AnalyticsViewModel
    // nil until the person taps a chip — `currentQuestion` resolves the default from data, so
    // the chip that leads (shot days, when there's GLP-1 history) tracks the data rather than
    // going stale the moment it loads.
    @State private var selectedQuestion: AnalyticsQuestion? = nil
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

    // MARK: - Question selection

    private var hasShotDaysData: Bool { !vm.glp1History.isEmpty }
    private var hasBodyCompData: Bool { !vm.bodyFatLogs.isEmpty }

    /// Fixed order (docs/daylight-redesign.md). Shot days only appears with GLP-1 history to
    /// show; body composition only once there's a reading to plot.
    private var visibleQuestions: [AnalyticsQuestion] {
        var questions: [AnalyticsQuestion] = []
        if hasShotDaysData { questions.append(.shotDays) }
        questions.append(contentsOf: [.proteinSources, .weightTrend, .proteinCalories, .movement])
        if hasBodyCompData { questions.append(.bodyComposition) }
        return questions
    }

    /// Shot days leads when it's available — the most specific, highest-signal question for
    /// someone on GLP-1; otherwise "Am I hitting protein and calories?" is the front door.
    private var defaultQuestion: AnalyticsQuestion {
        hasShotDaysData ? .shotDays : .proteinCalories
    }

    private var currentQuestion: AnalyticsQuestion {
        guard let selectedQuestion, visibleQuestions.contains(selectedQuestion) else { return defaultQuestion }
        return selectedQuestion
    }

    // Whether there's anything at all to ask a question about — independent of food logging,
    // since a weight- or movement-only user shouldn't see "log a meal" as their only empty state.
    private var hasAnyData: Bool {
        !vm.loggedDays.isEmpty || !vm.activeDays.isEmpty || !vm.weightLogs.isEmpty
            || !vm.bodyFatLogs.isEmpty || !vm.glp1History.isEmpty
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

                if !hasAnyData {
                    if !vm.isLoading { emptyState.popIn(order: 2) }
                } else {
                    questionChips
                        .popIn(order: 2)

                    // Keyed on the question so a chip switch replays the chart draw-in, the same
                    // way a fresh appearance would (ChartDrawIn only fires on first appear).
                    questionContent(for: currentQuestion)
                        .id(currentQuestion)
                        .popIn(order: 3)
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

    // MARK: - Chips

    // One scrolling row, not a wrapped stack: six full questions wrapped to six lines and
    // pushed the answer below the fold. The row runs edge to edge so the next question peeks
    // in from the right, which says "scroll me".
    private var questionChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleQuestions) { question in
                        let isSelected = question == currentQuestion
                        Button {
                            selectedQuestion = question
                            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(question, anchor: .center) }
                        } label: {
                            Text(question.rawValue)
                                .font(Theme.Fonts.body(14, .semibold))
                                .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(
                                    isSelected ? Theme.Colors.primary : Theme.Colors.surfaceCard,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                        }
                        .buttonStyle(PressableStyle(scale: 0.97))
                        .id(question)
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                        .accessibilityHint("Shows \(question.rawValue)")
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
            }
            .padding(.horizontal, -Theme.Spacing.page)
        }
    }

    // MARK: - Question content

    @ViewBuilder
    private func questionContent(for question: AnalyticsQuestion) -> some View {
        switch question {
        case .shotDays:        shotDaysQuestion
        case .proteinSources:  proteinSourcesQuestion
        case .weightTrend:     weightTrendQuestion
        case .proteinCalories: proteinCaloriesQuestion
        case .movement:        movementQuestion
        case .bodyComposition: bodyCompositionQuestion
        }
    }

    private func askPrompt(_ question: AnalyticsQuestion) -> String {
        "Looking at my Analytics for the last \(vm.selectedRange.label): \(question.rawValue.prefix(1).lowercased() + question.rawValue.dropFirst())"
    }

    private var shotDaysQuestion: some View {
        let takeaway = ShotDayEatingTakeaway.build(insights: vm.cycleInsights)
        return AnalyticsQuestionCard(question: .shotDays, takeaway: takeaway, askPrompt: askPrompt(.shotDays)) {
            CycleAwareAnalyticsCard(insights: vm.cycleInsights, proteinGoal: vm.goalProteinG, accessibilitySummary: takeaway)
        }
    }

    private var proteinSourcesQuestion: some View {
        let sources = vm.proteinSources
        let takeaway = ProteinSourceAggregator.headline(for: sources) ?? "Log a few meals and your top protein sources will show up here."
        return AnalyticsQuestionCard(question: .proteinSources, takeaway: takeaway, askPrompt: askPrompt(.proteinSources)) {
            if sources.isEmpty {
                BrandedEmptyState(
                    icon: "fork.knife",
                    title: "No foods logged yet",
                    message: "Log a few meals and your top protein sources will show up here."
                )
            } else {
                ProteinSourcesChart(sources: sources, accessibilitySummary: takeaway)
            }
        }
    }

    private var weightTrendQuestion: some View {
        let takeaway = WeightTrendEngine.takeaway(for: vm.weightLogs, units: units)
        return AnalyticsQuestionCard(question: .weightTrend, takeaway: takeaway, askPrompt: askPrompt(.weightTrend)) {
            if vm.weightLogs.isEmpty {
                BrandedEmptyState(
                    icon: "scalemass",
                    title: "No weigh-ins yet",
                    message: "Log a weight and your trend will start building here."
                )
            } else {
                WeightTrendChart(
                    logs: vm.weightLogs,
                    doseChanges: vm.doseChangesInRange,
                    shotDays: vm.shotDaysInRange,
                    units: units,
                    accessibilitySummary: takeaway
                )
            }
        }
    }

    private var proteinCaloriesQuestion: some View {
        let takeaway = NutritionSummaryTakeaway.build(
            loggedDayCount: vm.loggedDays.count,
            avgProtein: vm.averageProteinG,
            goalProtein: vm.goalProteinG,
            avgCalories: vm.averageCalories,
            goalCalories: vm.goalCalories
        )
        return AnalyticsQuestionCard(question: .proteinCalories, takeaway: takeaway, askPrompt: askPrompt(.proteinCalories)) {
            if vm.loggedDays.isEmpty {
                BrandedEmptyState(
                    icon: "fork.knife",
                    title: "No days logged yet",
                    message: "Log a few meals and your protein and calorie picture will show up here."
                )
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                    AnalyticsSummaryCard(
                        avgProtein:   vm.averageProteinG,
                        goalProtein:  vm.goalProteinG,
                        avgCalories:  vm.averageCalories,
                        goalCalories: vm.goalCalories
                    )
                    CaloriesChartContent(
                        summaries: vm.summaries,
                        goalCalories: vm.goalCalories,
                        average: vm.averageCalories,
                        accessibilitySummary: takeaway
                    )
                    MacrosChartContent(summaries: vm.summaries)
                }
            }
        }
    }

    private var movementQuestion: some View {
        let takeaway = MovementTakeaway.build(
            activeDayCount: vm.activeDays.count,
            totalDayCount: vm.movement.count,
            sessions: vm.totalWorkoutSessions,
            avgMinutes: vm.avgMinutesPerActiveDay
        )
        return AnalyticsQuestionCard(question: .movement, takeaway: takeaway, askPrompt: askPrompt(.movement)) {
            if vm.activeDays.isEmpty {
                BrandedEmptyState(
                    icon: "figure.run",
                    title: "No movement yet",
                    message: "Log a workout and your activity will show up here."
                )
            } else {
                MovementChartContent(movement: vm.movement, accessibilitySummary: takeaway)
            }
        }
    }

    private var bodyCompositionQuestion: some View {
        let takeaway = BodyFatTrendTakeaway.build(logs: vm.bodyFatLogs)
        return AnalyticsQuestionCard(question: .bodyComposition, takeaway: takeaway, askPrompt: askPrompt(.bodyComposition)) {
            if vm.bodyFatLogs.isEmpty {
                BrandedEmptyState(
                    icon: "figure",
                    title: "No readings yet",
                    message: "Log a body fat reading and your trend will start building here."
                )
            } else {
                BodyFatChartContent(logs: vm.bodyFatLogs, accessibilitySummary: takeaway)
            }
        }
    }
}

// MARK: - Question card

/// The one-tile shell every question renders inside: the question as a heading, the computed
/// takeaway, the chart(s), and a way to hand the same question to Pulse.
private struct AnalyticsQuestionCard<Content: View>: View {
    let question: AnalyticsQuestion
    let takeaway: String
    let askPrompt: String
    let content: Content
    @Environment(AppState.self) private var appState

    init(question: AnalyticsQuestion, takeaway: String, askPrompt: String, @ViewBuilder content: () -> Content) {
        self.question = question
        self.takeaway = takeaway
        self.askPrompt = askPrompt
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(question.rawValue)
                .font(Theme.Fonts.display(21, .bold, relativeTo: .title3))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(takeaway)
                .font(Theme.Fonts.body(14, .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            content

            HStack {
                Spacer(minLength: 0)
                Button {
                    appState.askPulse(askPrompt)
                } label: {
                    Text("Ask Pulse about this")
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Sends this question to Pulse")
            }
        }
        .tile()
    }
}

// MARK: - Summary hero

// Opens the "Am I hitting protein and calories?" question with the thesis, not a chart: average
// protein (the priority metric for a GLP-1 user) as the hero, with average calories alongside.
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
        .tile(Theme.Colors.surfaceInset, shadow: false)
    }
}

// MARK: - Calories chart

private struct CaloriesChartContent: View {
    let summaries: [DailySummary]
    let goalCalories: Double?
    let average: Double
    let accessibilitySummary: String

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
                    .font(Theme.Fonts.body(13, .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Calories chart")
            .accessibilityValue(accessibilitySummary)
        }
    }
}

// MARK: - Macros chart

private struct MacrosChartContent: View {
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
                .font(Theme.Fonts.body(13, .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)

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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Macros chart")
                .accessibilityValue("Protein, carbs and fat logged across the range.")
            }
        }
    }
}

// MARK: - Movement chart

// Minutes per day, deliberately goal-free: movement has no target line or "should have"
// framing anywhere in the app — the chart shows what happened, nothing else.
private struct MovementChartContent: View {
    let movement: [DailyMovement]
    let accessibilitySummary: String

    private var xAxisStride: Int {
        switch movement.count {
        case ..<8:  return 1
        case ..<15: return 2
        default:    return 7
        }
    }

    var body: some View {
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
        .frame(height: 160)
        .chartDrawIn()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Movement chart")
        .accessibilityValue(accessibilitySummary)
    }
}

// MARK: - Body fat chart

private struct BodyFatChartContent: View {
    let logs: [(date: Date, pct: Double)]
    let accessibilitySummary: String

    var body: some View {
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
        .frame(height: 160)
        .chartDrawIn()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Body fat percentage chart")
        .accessibilityValue(accessibilitySummary)
    }
}

// MARK: - Where does my protein come from?

// Top 5 foods by total protein contributed in the range, as horizontal bars that draw in —
// aggregation is pure and tested (AnalyticsQuestions.swift: ProteinSourceAggregator).
private struct ProteinSourcesChart: View {
    let sources: [ProteinSource]
    let accessibilitySummary: String

    var body: some View {
        Chart(sources) { source in
            BarMark(
                x: .value("Protein", source.gramsProtein),
                y: .value("Food", source.name)
            )
            .foregroundStyle(Theme.NutrientColor.protein.gradient)
            .cornerRadius(6)
            .annotation(position: .trailing, alignment: .leading) {
                Text("\(Int(source.gramsProtein.rounded()))g · \(Int((source.share * 100).rounded()))% · \(source.timesLogged)×")
                    .font(Theme.Fonts.body(11, .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize()
            }
        }
        .chartYScale(domain: sources.map(\.name))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let name = value.as(String.self) {
                        Text(name)
                            .font(Theme.Fonts.body(13, .medium))
                    }
                }
                .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        .frame(height: CGFloat(sources.count) * 46 + 12)
        .chartDrawIn()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Top protein sources chart")
        .accessibilityValue(accessibilitySummary)
    }
}

// MARK: - Is my weight trend real?

// A smoothed rolling average — not raw points — with shot days as small ticks along the bottom
// and dose changes as labelled vertical rules, both from `glp1History`. Smoothing and the
// takeaway are pure and tested (AnalyticsQuestions.swift: WeightTrendEngine).
private struct WeightTrendChart: View {
    let logs: [WeightLog]
    let doseChanges: [DoseChangeMark]
    let shotDays: [Date]
    let units: UnitSystem
    let accessibilitySummary: String

    private var unit: String { units.weightUnit }

    private var rawPoints: [(date: Date, value: Double)] {
        logs.sorted { $0.loggedAt < $1.loggedAt }.map { ($0.loggedAt, units.weightInput(from: $0.weightKg)) }
    }

    private var smoothedPoints: [(date: Date, value: Double)] {
        WeightTrendEngine.smoothedSeries(from: logs).map { ($0.date, units.weightInput(from: $0.value)) }
    }

    private var yDomain: ClosedRange<Double> {
        let values = rawPoints.map(\.value) + smoothedPoints.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        guard hi > lo else { return (lo - 1)...(lo + 1) }
        let pad = (hi - lo) * 0.2
        return (lo - pad)...(hi + pad)
    }

    // Shot-day ticks sit just above the axis floor rather than exactly on it, so they don't get
    // visually clipped by the plot's bottom edge.
    private var tickY: Double {
        yDomain.lowerBound + (yDomain.upperBound - yDomain.lowerBound) * 0.03
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
        Chart {
            ForEach(rawPoints, id: \.date) { point in
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(unit, point.value)
                )
                .foregroundStyle(Theme.NutrientColor.protein.opacity(0.35))
                .symbolSize(20)
            }
            ForEach(smoothedPoints, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(unit, point.value)
                )
                .foregroundStyle(Theme.NutrientColor.protein)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            ForEach(shotDays, id: \.self) { day in
                PointMark(
                    x: .value("Date", day, unit: .day),
                    y: .value(unit, tickY)
                )
                .foregroundStyle(Theme.Colors.textFaint)
                .symbol(.circle)
                .symbolSize(14)
            }
            ForEach(doseChanges) { change in
                RuleMark(x: .value("Date", change.date, unit: .day))
                    .foregroundStyle(Theme.Colors.textFaint.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                // The dose label rides an invisible point at the top of the plot, so it stays
                // inside the chart. Above it, the draw-in mask cut it off.
                PointMark(
                    x: .value("Date", change.date, unit: .day),
                    y: .value(unit, yDomain.upperBound)
                )
                .opacity(0)
                .annotation(position: .trailing, alignment: .topLeading, spacing: 3) {
                    Text("\(change.doseMg.glp1DoseString) mg")
                        .font(Theme.Fonts.body(10, .bold, relativeTo: nil))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.surfaceInset, in: Capsule())
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    // Whole numbers when the range is wide; one decimal when it's narrow, where
                    // rounding labelled two gridlines "84 kg".
                    if let v = value.as(Double.self) { Text("\(yLabel(v)) \(unit)") }
                }
                .foregroundStyle(Theme.Colors.textFaint)
                AxisGridLine().foregroundStyle(Theme.Colors.hairline)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), collisionResolution: .greedy)
                    .foregroundStyle(Theme.Colors.textFaint)
                AxisGridLine().foregroundStyle(Theme.Colors.hairline)
            }
        }
        .frame(height: 190)
        .chartDrawIn()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weight trend chart")
        .accessibilityValue(accessibilitySummary)

        if !shotDays.isEmpty || !doseChanges.isEmpty {
            HStack(spacing: 14) {
                if !shotDays.isEmpty {
                    HStack(spacing: 5) {
                        Circle().fill(Theme.Colors.textFaint).frame(width: 6, height: 6)
                        Text("Shot day")
                    }
                }
                if !doseChanges.isEmpty {
                    HStack(spacing: 5) {
                        Rectangle()
                            .stroke(Theme.Colors.textFaint, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 1, height: 12)
                        Text("Dose change")
                    }
                }
                HStack(spacing: 5) {
                    Capsule().fill(Theme.NutrientColor.protein).frame(width: 14, height: 3)
                    Text("Trend")
                }
            }
            .font(Theme.Fonts.body(12, .medium))
            .foregroundStyle(Theme.Colors.textSecondary)
            .accessibilityHidden(true)
        }
        }
    }

    private func yLabel(_ value: Double) -> String {
        let span = yDomain.upperBound - yDomain.lowerBound
        return span < 6 ? String(format: "%.1f", value) : "\(Int(value.rounded()))"
    }
}
