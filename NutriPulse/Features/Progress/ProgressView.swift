import SwiftUI

// Daylight Progress (docs/daylight-redesign.md): a big display title, a Goals pill, a
// week/month/3-months switcher, an indigo "floor days" hero with a day-by-day graphic that
// draws in, a quick-stat grid, two derived notice tiles, and — since the mockup doesn't cover
// Analytics, Progress summaries, or Personal experiments — a plain row list underneath so
// those destinations stay reachable.

/// Local to Progress: the "Try this" tile's warm amber, paired with "Worth noticing"'s violet
/// (`Theme.Colors.violet*`). Theme has no amber-family token yet.
private extension Theme.Colors {
    static let amberTile  = Color(hex: 0xFFEDD5)
    static let amberLabel = Color(hex: 0x9A3412)
    static let amberInk   = Color(hex: 0x431407)
}

struct ProgressDashboardView: View {
    @State private var analytics = AnalyticsViewModel()
    @State private var goals = GoalsViewModel()
    @State private var selectedRange: ProgressRange = .month
    @State private var previousSummaries: [DailySummary] = []
    @State private var experimentCount = 0
    @State private var showExperiments = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                    header
                        .popIn(order: 0)
                    rangePicker
                        .popIn(order: 1)

                    if analytics.isLoading && analytics.summaries.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 320)
                            .accessibilityLabel("Loading progress")
                    } else if analytics.errorMessage != nil {
                        progressErrorState
                    } else {
                        FloorDaysHero(
                            range: selectedRange,
                            summaries: analytics.summaries,
                            proteinGoal: analytics.goalProteinG,
                            trend: trend
                        )
                        .popIn(order: 2)

                        statGrid

                        noticeRow
                            .popIn(order: 7)

                        moreSection
                            .popIn(order: 8)
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            // No navigation bar, so cover the status bar or scrolled tiles slide under the clock
            // (same as Profile and Pulse). A ShapeStyle background extends into the safe area.
            .overlay(alignment: .top) {
                Color.clear
                    .frame(height: 0)
                    .background(Theme.Colors.ground)
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                async let analyticsLoad: Void = loadAnalytics()
                async let previousLoad: Void = loadPreviousPeriod()
                async let supportingLoad: Void = loadSupportingData()
                _ = await (analyticsLoad, previousLoad, supportingLoad)
            }
            .task(id: selectedRange) {
                async let analyticsLoad: Void = loadAnalytics()
                async let previousLoad: Void = loadPreviousPeriod()
                _ = await (analyticsLoad, previousLoad)
            }
            .task { await loadSupportingData() }
            .sheet(isPresented: $showExperiments) {
                ExperimentsView(activeGoals: goals.active)
            }
            .onChange(of: showExperiments) { _, isPresented in
                if !isPresented { Task { await loadExperimentCount() } }
            }
        }
        .tint(Theme.Colors.primary)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Progress")
                .font(Theme.Fonts.display(36, .extraBold, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            NavigationLink {
                GoalsView(embeddedInNavigation: true)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Goals")
                        .font(Theme.Fonts.body(14, .bold))
                }
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityHint("Opens your goals")
        }
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(ProgressRange.allCases) { range in
                    Button {
                        guard selectedRange != range else { return }
                        withAnimation(Theme.Motion.tabSelect) { selectedRange = range }
                    } label: {
                        Text(range.pillLabel)
                            .font(Theme.Fonts.body(14, .bold))
                            .foregroundStyle(selectedRange == range ? .white : Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background {
                                if selectedRange == range {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Theme.Colors.ink)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedRange == range ? [.isSelected] : [])
                }
            }
            .padding(4)
            .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Range")

            Text(selectedRange.dateRangeText())
                .font(Theme.Fonts.body(13, .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.leading, 4)
        }
    }

    // MARK: - Stat grid

    private var statGrid: some View {
        VStack(spacing: Theme.Spacing.tileGap) {
            HStack(spacing: Theme.Spacing.tileGap) {
                AvgProteinStatTile(summaries: analytics.summaries)
                    .popIn(order: 3)
                WeightTrendStatTile(weightLogs: analytics.weightLogs)
                    .popIn(order: 4)
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.tileGap) {
                MovedStatTile(sessions: analytics.totalWorkoutSessions)
                    .popIn(order: 5)
                LoggedStatTile(loggedDays: analytics.loggedDays.count, totalDays: analytics.summaries.count)
                    .popIn(order: 6)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Notice row

    private var noticeRow: some View {
        HStack(spacing: Theme.Spacing.tileGap) {
            NoticeTile(
                eyebrow: "Worth noticing",
                text: noticeText,
                fill: Theme.Colors.violet,
                eyebrowColor: Theme.Colors.violetLabel,
                textColor: Theme.Colors.violetInk
            )
            NoticeTile(
                eyebrow: "Try this",
                text: tryThisText,
                fill: Theme.Colors.amberTile,
                eyebrowColor: Theme.Colors.amberLabel,
                textColor: Theme.Colors.amberInk
            )
        }
    }

    private var noticeText: String {
        ProgressNoticeBuilder.text(insights: analytics.cycleInsights)
    }

    private var tryThisText: String {
        ProgressTryThisBuilder.text(.init(summaries: analytics.summaries, proteinGoal: analytics.goalProteinG))
    }

    // MARK: - More (destinations the mockup doesn't cover, kept reachable)

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TileEyebrow("More")
            VStack(spacing: 0) {
                NavigationLink {
                    AnalyticsView(
                        embeddedInNavigation: true,
                        initialRange: selectedRange.analyticsRange
                    )
                } label: {
                    ProgressDestinationRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Analytics",
                        subtitle: "Nutrition, body, movement, cycles"
                    )
                }

                Divider().padding(.leading, 70).overlay(Theme.Colors.hairline)

                NavigationLink {
                    ProgressSummariesView(initialPeriod: selectedRange.summaryPeriod)
                } label: {
                    ProgressDestinationRow(
                        icon: "doc.text",
                        title: "Progress summaries",
                        subtitle: analytics.loggedDays.count >= 3 ? "Latest summary ready" : "Builds after 3 measured days"
                    )
                }

                Divider().padding(.leading, 70).overlay(Theme.Colors.hairline)

                Button { showExperiments = true } label: {
                    ProgressDestinationRow(
                        icon: "flask.fill",
                        title: "Personal experiments",
                        subtitle: experimentCount == 1 ? "1 active" : "\(experimentCount) active"
                    )
                }
                .buttonStyle(.plain)
            }
            .tile(padding: 0)
        }
    }

    private var trend: ProgressTrend? {
        ProgressTrendBuilder.trend(
            current: .init(summaries: analytics.summaries, proteinGoal: analytics.goalProteinG),
            previous: .init(summaries: previousSummaries, proteinGoal: analytics.goalProteinG)
        )
    }

    private var progressErrorState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            BrandedEmptyState(
                icon: "arrow.clockwise.circle",
                title: "Progress couldn’t refresh",
                message: analytics.errorMessage ?? "Check your connection and try again."
            )
            Button("Try again") { Task { await loadAnalytics() } }
                .buttonStyle(.borderedProminent)
        }
        .card()
    }

    // MARK: - Loading

    private func loadAnalytics() async {
        analytics.selectedRange = selectedRange.analyticsRange
        await analytics.loadData()
    }

    private func loadPreviousPeriod() async {
        #if DEBUG
        if DebugLaunch.has("--progress-preview") {
            loadPreviewPreviousPeriod()
            return
        }
        #endif
        let window = selectedRange.previousWindow()
        previousSummaries = (try? await AnalyticsRepository().fetchDailySummaries(
            from: window.lowerBound, through: window.upperBound
        )) ?? []
    }

    #if DEBUG
    /// The preview harness has no "previous period" of its own — synthesize a plausible one
    /// (slightly worse than the current preview data) so the trend pill is visible for review.
    private func loadPreviewPreviousPeriod() {
        let calendar = Calendar.current
        let window = selectedRange.previousWindow()
        let dayCount = (calendar.dateComponents([.day], from: window.lowerBound, to: window.upperBound).day ?? 0) + 1
        previousSummaries = (0..<dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: window.lowerBound) ?? window.lowerBound
            let isBelow = offset % 3 == 0
            return DailySummary(
                date: date,
                calories: isBelow ? 1_180 : 1_460,
                proteinG: isBelow ? 94 : 128,
                carbsG: 122, fatG: 48, fiberG: 22
            )
        }
    }
    #endif

    private func loadSupportingData() async {
        await goals.load()
        await loadExperimentCount()
    }

    private func loadExperimentCount() async {
        #if DEBUG
        if DebugLaunch.has("--progress-preview") {
            experimentCount = 1
            return
        }
        #endif
        if let experiments = try? await ExperimentRepository().fetchAll() {
            experimentCount = experiments.filter {
                $0.status == .draft || $0.status == .baseline || $0.status == .running
            }.count
        }
    }
}

private extension ProgressMarkState {
    var color: Color {
        switch self {
        case .met, .logged: Theme.Colors.primary
        case .below: Theme.NutrientColor.calories
        case .unknown: .clear
        }
    }
}

// MARK: - Floor days hero

private struct FloorDaysHero: View {
    let range: ProgressRange
    let summaries: [DailySummary]
    let proteinGoal: Double?
    let trend: ProgressTrend?

    private var metrics: ProgressMetrics { .init(summaries: summaries, proteinGoal: proteinGoal) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    TileEyebrow(metrics.hasGoal ? "Floor days" : "Logged days", color: Theme.Colors.heroLabel)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        CountingNumber(
                            value: metrics.hasGoal ? metrics.metCount : metrics.logged.count,
                            font: Theme.Fonts.number(44, relativeTo: .largeTitle)
                        )
                        .foregroundStyle(.white)
                        Text("of \(metrics.hasGoal ? metrics.logged.count : summaries.count)")
                            .font(Theme.Fonts.display(20, relativeTo: .title3))
                            .foregroundStyle(Theme.Colors.heroLabel)
                    }
                }
                Spacer(minLength: 8)
                if let trend {
                    Text(trend.label)
                        .font(Theme.Fonts.body(13, .bold))
                        .foregroundStyle(Theme.Colors.limeInk)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Theme.Colors.lime, in: Capsule())
                }
            }

            FloorDaysGraphic(range: range, summaries: summaries, proteinGoal: proteinGoal)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.heroDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let base = metrics.hasGoal
            ? "Floor days, \(metrics.metCount) of \(metrics.logged.count)"
            : "Logged days, \(metrics.logged.count) of \(summaries.count)"
        guard let trend else { return base }
        return "\(base). \(trend.label) last period."
    }
}

private struct FloorDaysGraphic: View {
    let range: ProgressRange
    let summaries: [DailySummary]
    let proteinGoal: Double?

    private var metrics: ProgressMetrics { .init(summaries: summaries, proteinGoal: proteinGoal) }

    var body: some View {
        Group {
            switch range {
            case .week: weekGrid
            case .month: dayStrip
            case .quarter: weekBars
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var weekGrid: some View {
        HStack(spacing: 6) {
            ForEach(Array(summaries.enumerated()), id: \.offset) { index, summary in
                VStack(spacing: 6) {
                    dayMark(for: summary)
                        .frame(width: 36, height: 36)
                    Text(summary.date.formatted(.dateTime.weekday(.narrow)))
                        .font(Theme.Fonts.body(11, .semibold))
                        .foregroundStyle(Theme.Colors.heroLabel)
                }
                .popIn(order: index)
            }
        }
    }

    @ViewBuilder
    private func dayMark(for summary: DailySummary) -> some View {
        let state = metrics.state(for: summary)
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(state == .unknown ? Color.clear : fillColor(state))
            .overlay {
                if state == .unknown {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.Colors.hero, style: StrokeStyle(lineWidth: 2, dash: [3]))
                }
            }
    }

    private func fillColor(_ state: ProgressMarkState) -> Color {
        switch state {
        case .met, .logged: Theme.Colors.hero
        case .below: Theme.Colors.hero.opacity(0.4)
        case .unknown: .clear
        }
    }

    private var dayStrip: some View {
        HStack(spacing: 3) {
            ForEach(Array(summaries.enumerated()), id: \.offset) { _, summary in
                let state = metrics.state(for: summary)
                Capsule()
                    .fill(state == .unknown ? Color.clear : fillColor(state))
                    .overlay {
                        if state == .unknown {
                            Capsule().strokeBorder(Theme.Colors.hero.opacity(0.6), lineWidth: 1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 14)
            }
        }
    }

    private var weekBars: some View {
        let weeks = ProgressTimelineBuilder.thirteenWeeks(summaries: summaries, proteinGoal: proteinGoal)
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(weeks) { week in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(week.hasEnoughData ? Theme.Colors.hero.opacity(0.4 + 0.6 * week.fraction) : .clear)
                    .overlay {
                        if !week.hasEnoughData {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Theme.Colors.hero.opacity(0.5), lineWidth: 1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 8 + 24 * week.fraction)
            }
        }
        .frame(height: 32, alignment: .bottom)
    }

    private var accessibilitySummary: String {
        if metrics.hasGoal {
            let below = metrics.logged.count - metrics.metCount
            return "\(metrics.metCount) days met the protein floor, \(below) \(below == 1 ? "day was" : "days were") below, and \(metrics.missingCount) \(metrics.missingCount == 1 ? "day was" : "days were") not measured."
        }
        return "Nutrition was logged on \(metrics.logged.count) days and missing on \(metrics.missingCount) days."
    }
}

// MARK: - Sparkline

/// A minimal line chart that draws in from the leading edge on first appear. Reduce Motion:
/// the finished line, no animation.
private struct Sparkline: View {
    let values: [Double]
    var color: Color = Theme.Colors.primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard values.count > 1 else { return }
                // Anchor the bottom well below the data (at most 60% of the peak) instead of at
                // its minimum: min-to-max scaling stretched a 110–140 g week into full-height
                // spikes, so ordinary day-to-day wobble read as a crisis.
                let maxV = values.max() ?? 1
                let minV = min(values.min() ?? 0, maxV * 0.6)
                let range = max(maxV - minV, 0.0001)
                let stepX = geo.size.width / CGFloat(values.count - 1)
                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geo.size.height - CGFloat((value - minV) / range) * geo.size.height
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Theme.Motion.draw.delay(0.3)) { drawn = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Stat tiles

private struct AvgProteinStatTile: View {
    let summaries: [DailySummary]
    private var logged: [DailySummary] { summaries.filter(\.hasData) }
    private var average: Int {
        guard !logged.isEmpty else { return 0 }
        return Int((logged.reduce(0) { $0 + $1.proteinG } / Double(logged.count)).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TileEyebrow("Avg protein")
            if logged.count > 1 {
                // A 3-day rolling average, matching the tile's "average" label: raw daily values
                // zig-zag between high and low days and read as noise rather than a trend.
                Sparkline(values: ProgressTrendBuilder.rollingAverage(logged.map(\.proteinG), window: 3),
                          color: Theme.NutrientColor.protein)
                    .frame(height: 32)
            } else {
                Spacer(minLength: 32)
            }
            Text(logged.isEmpty ? "No data yet" : "\(average)g")
                .font(logged.isEmpty ? Theme.Fonts.body(14, .semibold) : Theme.Fonts.number(24, .bold, relativeTo: .title2))
                .foregroundStyle(logged.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .tile()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(logged.isEmpty ? "Average protein, no data yet" : "Average protein \(average) grams")
    }
}

private struct WeightTrendStatTile: View {
    let weightLogs: [WeightLog]
    private var ordered: [WeightLog] { weightLogs.sorted { $0.loggedAt < $1.loggedAt } }
    private var change: Double? {
        guard ordered.count >= 2, let first = ordered.first, let last = ordered.last else { return nil }
        return last.weightKg - first.weightKg
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TileEyebrow("Weight trend")
            if ordered.count > 1 {
                Sparkline(values: ordered.map(\.weightKg), color: Theme.Colors.textPrimary)
                    .frame(height: 32)
            } else {
                Spacer(minLength: 32)
            }
            Text(change.map(changeText) ?? "Log weight to see a trend")
                .font(change == nil ? Theme.Fonts.body(13, .semibold) : Theme.Fonts.number(24, .bold, relativeTo: .title2))
                .foregroundStyle(change == nil ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .tile()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(change.map { "Weight trend, \(changeText($0))" } ?? "Weight trend, not enough data yet")
    }

    private func changeText(_ value: Double) -> String {
        let magnitude = abs(value).formatted(.number.precision(.fractionLength(1)))
        if value < -0.05 { return "−\(magnitude) kg" }
        if value > 0.05 { return "+\(magnitude) kg" }
        return "Stable"
    }
}

private struct MovedStatTile: View {
    let sessions: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TileEyebrow("Moved", color: Theme.Colors.skyInk)
            Spacer(minLength: 0)
            Text(sessions == 0 ? "No sessions yet" : "\(sessions) \(sessions == 1 ? "session" : "sessions")")
                .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                .foregroundStyle(Theme.Colors.skyInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .tile(Theme.Colors.sky, shadow: false)
    }
}

private struct LoggedStatTile: View {
    let loggedDays: Int
    let totalDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TileEyebrow("Logged")
            Spacer(minLength: 0)
            Text("\(loggedDays) of \(totalDays) days")
                .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .tile()
    }
}

// MARK: - Notice tile

private struct NoticeTile: View {
    let eyebrow: String
    let text: String
    let fill: Color
    let eyebrowColor: Color
    let textColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(Theme.Fonts.body(12, .bold))
                .tracking(Theme.Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(eyebrowColor)
            Text(text)
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
    }
}

// MARK: - Destination row

private struct ProgressDestinationRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 40, height: 40)
                .background(Theme.Colors.surfaceInset, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.body(15, .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.textFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Progress summaries (unchanged data path, lightly themed — reached via "More")

private struct ProgressSummariesView: View {
    let initialPeriod: ProgressSummaryPeriod
    @State private var selectedPeriod: ProgressSummaryPeriod
    @State private var viewModel = ProgressSummaryViewModel()

    init(initialPeriod: ProgressSummaryPeriod) {
        self.initialPeriod = initialPeriod
        _selectedPeriod = State(initialValue: initialPeriod)
    }

    private var currentWindow: ClosedRange<Date>? {
        selectedPeriod.window(shots: viewModel.shots)
    }

    private var currentSummaries: [DailySummary] {
        guard let currentWindow else { return [] }
        let calendar = Calendar.current
        return viewModel.summaries.filter { currentWindow.contains(calendar.startOfDay(for: $0.date)) }
    }

    private var metrics: ProgressMetrics {
        .init(summaries: currentSummaries, proteinGoal: viewModel.proteinGoal)
    }

    private var history: [ProgressHistoryItem] {
        ProgressHistoryBuilder.previousPeriods(
            for: selectedPeriod,
            summaries: viewModel.summaries,
            shots: viewModel.shots
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                DaylightPageTitle("Progress summaries")
                periodPicker

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 320)
                        .accessibilityLabel("Loading progress summaries")
                } else if let error = viewModel.errorMessage {
                    summaryErrorState(error)
                } else if selectedPeriod == .sinceLastShot && currentWindow == nil {
                    noShotState
                } else {
                    currentSummary

                    if metrics.summaryReady {
                        SummaryReviewCard(
                            title: selectedPeriod.fullLabel,
                            summaries: currentSummaries,
                            proteinGoal: viewModel.proteinGoal
                        )
                    }

                    previousSummaries
                }
            }
            .padding(Theme.Spacing.page)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .daylightSubpage("Progress summaries")
        .task { await viewModel.load() }
    }

    private var periodPicker: some View {
        Picker("Summary period", selection: $selectedPeriod) {
            ForEach(ProgressSummaryPeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
    }

    private var currentSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            TileEyebrow(selectedPeriod.fullLabel)

            if let currentWindow {
                Text(periodContext(window: currentWindow))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if !metrics.summaryReady {
                BrandedEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: "Keep building this summary",
                    message: "Log at least 3 measured days in this period. You have \(metrics.logged.count)."
                )
            } else {
                Text(summaryHeadline)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)

                SummaryTimelineGraphic(
                    period: selectedPeriod,
                    summaries: currentSummaries,
                    proteinGoal: viewModel.proteinGoal
                )

                Text("Based only on logged and measured data; missing days stay unknown.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tile()
    }

    private var summaryHeadline: String {
        if metrics.hasGoal {
            return "You reached your protein floor on \(metrics.metCount) of \(metrics.logged.count) measured days."
        }
        return "You logged nutrition on \(metrics.logged.count) of \(currentSummaries.count) days."
    }

    private func periodContext(window: ClosedRange<Date>) -> String {
        let dates = ProgressDateRangeFormatter.text(from: window.lowerBound, through: window.upperBound)
        guard selectedPeriod == .sinceLastShot else { return dates }
        let cycleDay = max(Calendar.current.dateComponents([.day], from: window.lowerBound, to: window.upperBound).day ?? 0, 0)
        return "Since \(window.lowerBound.formatted(.dateTime.month(.abbreviated).day())) · Cycle day \(cycleDay) · \(dates)"
    }

    private var noShotState: some View {
        BrandedEmptyState(
            icon: "syringe.fill",
            title: "Log a shot to unlock this summary",
            message: "After your next logged dose, Footing can summarize protein and logging across the current shot cycle."
        )
        .tile()
    }

    private func summaryErrorState(_ error: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            BrandedEmptyState(
                icon: "arrow.clockwise.circle",
                title: "Summaries couldn’t refresh",
                message: error
            )
            Button("Try again") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
        }
        .tile()
    }

    @ViewBuilder
    private var previousSummaries: some View {
        if !history.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Previous summaries")
                    .font(Theme.Typography.title)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 12)

                ForEach(Array(history.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().padding(.leading, Theme.Spacing.md).overlay(Theme.Colors.hairline) }
                    ProgressHistoryRow(item: item)
                }
            }
            .tile(padding: 0)
        }
    }
}

private struct SummaryTimelineGraphic: View {
    let period: ProgressSummaryPeriod
    let summaries: [DailySummary]
    let proteinGoal: Double?

    private var metrics: ProgressMetrics { .init(summaries: summaries, proteinGoal: proteinGoal) }
    private var weeks: [ProgressWeekInterval] {
        ProgressTimelineBuilder.thirteenWeeks(summaries: summaries, proteinGoal: proteinGoal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TileEyebrow(period == .quarter ? "13 weekly intervals" : "Daily intervals")

            if period == .quarter {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(weeks) { week in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(week.hasEnoughData ? color(for: week.fraction) : .clear)
                            .overlay {
                                if !week.hasEnoughData {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(Theme.Colors.primary.opacity(0.32), lineWidth: 1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 10 + 24 * week.fraction)
                    }
                }
                .frame(height: 34, alignment: .bottom)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(weeks.map(\.accessibilityText).joined(separator: ". "))
            } else {
                HStack(spacing: 3) {
                    ForEach(Array(summaries.enumerated()), id: \.offset) { _, summary in
                        let state = metrics.state(for: summary)
                        Capsule()
                            .fill(state.color)
                            .overlay {
                                if state == .unknown {
                                    Capsule().stroke(Theme.Colors.primary.opacity(0.32), lineWidth: 1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 14)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
            }

            HStack(spacing: 14) {
                ProgressLegend(color: Theme.Colors.primary, title: metrics.hasGoal ? "Met" : "Logged")
                if metrics.hasGoal { ProgressLegend(color: Theme.NutrientColor.calories, title: "Below") }
                ProgressLegend(color: .clear, title: "Unknown", outlined: true)
            }
        }
    }

    private func color(for fraction: Double) -> Color {
        guard metrics.hasGoal else { return Theme.Colors.primary.opacity(0.35 + 0.65 * fraction) }
        return fraction >= 0.5 ? Theme.Colors.primary.opacity(0.35 + 0.65 * fraction) : Theme.NutrientColor.calories
    }

    private var accessibilitySummary: String {
        if metrics.hasGoal {
            let below = metrics.logged.count - metrics.metCount
            return "\(metrics.metCount) days met the protein floor, \(below) \(below == 1 ? "day was" : "days were") below, and \(metrics.missingCount) \(metrics.missingCount == 1 ? "day was" : "days were") not measured."
        }
        return "Nutrition was logged on \(metrics.logged.count) days and missing on \(metrics.missingCount) days."
    }
}

private struct ProgressLegend: View {
    let color: Color
    let title: String
    var outlined = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .overlay { if outlined { Circle().stroke(Theme.Colors.primary.opacity(0.4)) } }
                .frame(width: 8, height: 8)
            Text(title)
                .font(Theme.Fonts.body(11))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

private struct SummaryReviewCard: View {
    let title: String
    let summaries: [DailySummary]
    let proteinGoal: Double?

    private var metrics: ProgressMetrics { .init(summaries: summaries, proteinGoal: proteinGoal) }
    private var weakest: DailySummary? { metrics.logged.min { $0.proteinG < $1.proteinG } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("\(title), from Pulse", systemImage: "sparkles")
                .font(Theme.Fonts.body(17, .bold, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.primary)
            row("What went well", wentWell, "checkmark.circle.fill", .green)
            row("Where it got difficult", gotDifficult, "arrow.down.right.circle.fill", .orange)
            row("Pattern noticed", pattern, "point.3.connected.trianglepath.dotted", Theme.Colors.primary)

            VStack(alignment: .leading, spacing: 3) {
                TileEyebrow("One thing to try")
                Text(experiment)
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.primary.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .tile()
    }

    private var wentWell: String {
        if metrics.hasGoal {
            return "You protected your protein floor on \(metrics.metCount) of \(metrics.logged.count) measured days."
        }
        return "You logged enough nutrition to build a summary from \(metrics.logged.count) measured days."
    }

    private var gotDifficult: String {
        guard let weakest else { return "There isn’t enough measured data to identify a difficult day yet." }
        return "Protein was lowest on \(weakest.date.formatted(.dateTime.weekday(.wide))) at \(Int(weakest.proteinG.rounded()))g."
    }

    private var pattern: String {
        "Average protein was \(Int(metrics.averageProtein.rounded()))g across measured days in this period."
    }

    private var experiment: String {
        if let proteinGoal, proteinGoal > 0, metrics.averageProtein < proteinGoal {
            return "Add one protein-dense option to the first meal you log and watch the next comparable period."
        }
        return "Repeat the meal that made your strongest protein day easy."
    }

    private func row(_ title: String, _ detail: String, _ icon: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 18).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Fonts.body(12, .semibold)).foregroundStyle(Theme.Colors.textSecondary)
                Text(detail).font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textPrimary)
            }
        }
    }
}

private struct ProgressHistoryRow: View {
    let item: ProgressHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(Theme.Typography.headline)
                Text(item.dateRange).font(Theme.Typography.caption).foregroundStyle(Theme.Colors.textSecondary)
                Text("\(item.measuredDays) of \(item.expectedDays) measured days · \(item.averageProtein)g average protein")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
