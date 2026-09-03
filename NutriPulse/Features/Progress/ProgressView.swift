import SwiftUI

struct ProgressDashboardView: View {
    @State private var analytics = AnalyticsViewModel()
    @State private var goals = GoalsViewModel()
    @State private var selectedRange: ProgressRange = .month
    @State private var experimentCount = 0
    @State private var showExperiments = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    rangePicker
                    dateRange

                    if analytics.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 320)
                            .accessibilityLabel("Loading progress")
                    } else if analytics.errorMessage != nil {
                        progressErrorState
                    } else {
                        ProgressHeroCard(
                            range: selectedRange,
                            summaries: analytics.summaries,
                            proteinGoal: analytics.goalProteinG
                        )

                        ProgressNoticeCard(text: noticeText)

                        destinationList
                    }

                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, 4)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                async let analyticsLoad: Void = loadAnalytics()
                async let supportingLoad: Void = loadSupportingData()
                _ = await (analyticsLoad, supportingLoad)
            }
            .task(id: selectedRange) { await loadAnalytics() }
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

    private var header: some View {
        Text("Progress")
            .font(Theme.Typography.display)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rangePicker: some View {
        Picker("Progress range", selection: $selectedRange) {
            ForEach(ProgressRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var dateRange: some View {
        Text(selectedRange.dateRangeText())
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var destinationList: some View {
        VStack(spacing: 0) {
            NavigationLink {
                GoalsView(embeddedInNavigation: true)
            } label: {
                ProgressDestinationRow(
                    icon: "target",
                    title: "Goals",
                    subtitle: "\(goals.active.count) active · Create or manage goals"
                )
            }

            Divider().padding(.leading, 70)

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

            Divider().padding(.leading, 70)

            NavigationLink {
                ProgressSummariesView(initialPeriod: selectedRange.summaryPeriod)
            } label: {
                ProgressDestinationRow(
                    icon: "doc.text",
                    title: "Progress summaries",
                    subtitle: analytics.loggedDays.count >= 3 ? "Latest summary ready" : "Builds after 3 measured days"
                )
            }

            Divider().padding(.leading, 70)

            Button { showExperiments = true } label: {
                ProgressDestinationRow(
                    icon: "flask.fill",
                    title: "Personal experiments",
                    subtitle: experimentCount == 1 ? "1 active" : "\(experimentCount) active"
                )
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private var noticeText: String {
        ProgressNoticeBuilder.text(insights: analytics.cycleInsights)
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

    private func loadAnalytics() async {
        analytics.selectedRange = selectedRange.analyticsRange
        await analytics.loadData()
    }

    private func loadSupportingData() async {
        await goals.load()
        await loadExperimentCount()
    }

    private func loadExperimentCount() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--progress-preview") {
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

private struct ProgressHeroCard: View {
    let range: ProgressRange
    let summaries: [DailySummary]
    let proteinGoal: Double?

    private var metrics: ProgressMetrics { .init(summaries: summaries, proteinGoal: proteinGoal) }
    private var headline: String {
        guard !metrics.logged.isEmpty else { return "Your protein picture starts here." }
        if metrics.hasGoal { return "Here’s your protein-floor picture." }
        return "Your logging pattern is taking shape."
    }
    private var detail: AttributedString {
        var text: AttributedString
        if metrics.hasGoal {
            text = AttributedString("You reached your floor on \(metrics.metCount) of \(metrics.logged.count) measured days.")
        } else {
            text = AttributedString("You logged nutrition on \(metrics.logged.count) of \(summaries.count) days. Create a protein goal to track floor attainment.")
        }
        if let range = text.range(of: metrics.hasGoal ? "\(metrics.metCount) of \(metrics.logged.count)" : "\(metrics.logged.count) of \(summaries.count)") {
            text[range].foregroundColor = Theme.Colors.primary
            text[range].font = .system(size: 17, weight: .semibold)
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR LAST \(range.rawValue) DAYS")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Theme.Colors.textFaint)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(headline)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(detail)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 4)
                ProgressCompletionRing(
                    completion: metrics.completion,
                    caption: metrics.hasGoal ? "days met" : "days logged"
                )
            }

            ProgressTimelineGraphic(
                range: range,
                summaries: summaries,
                proteinGoal: proteinGoal
            )

            HStack(spacing: 16) {
                ProgressLegend(color: Theme.Colors.primary, title: metrics.hasGoal ? "Met" : "Logged")
                if metrics.hasGoal {
                    ProgressLegend(color: Theme.NutrientColor.calories, title: "Below")
                }
                ProgressLegend(color: .clear, title: "Unknown", outlined: true)
                Spacer()
                Text("\(metrics.missingCount) \(metrics.missingCount == 1 ? "day" : "days") not measured")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(14)
        .card()
    }
}

private struct ProgressCompletionRing: View {
    let completion: Double
    let caption: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.ringTrack, lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(completion, 0), 1))
                .stroke(Theme.Colors.primaryGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((completion * 100).rounded()))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.primary)
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(width: 76, height: 76)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((completion * 100).rounded())) percent, \(caption)")
    }
}

private struct ProgressTimelineGraphic: View {
    let range: ProgressRange
    let summaries: [DailySummary]
    let proteinGoal: Double?

    private var metrics: ProgressMetrics { .init(summaries: summaries, proteinGoal: proteinGoal) }
    private var weeks: [ProgressWeekInterval] {
        ProgressTimelineBuilder.thirteenWeeks(summaries: summaries, proteinGoal: proteinGoal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if range == .quarter {
                Text("LAST 13 WEEKS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.Colors.textFaint)
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(weeks) { week in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(week.hasEnoughData ? weekColor(week.fraction) : .clear)
                            .overlay {
                                if !week.hasEnoughData {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(Theme.Colors.primary.opacity(0.32), lineWidth: 1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 8 + 20 * week.fraction)
                    }
                }
                .frame(height: 28, alignment: .bottom)
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
                .accessibilityLabel(dayAccessibilitySummary)
            }
        }
    }

    private func weekColor(_ fraction: Double) -> Color {
        guard metrics.hasGoal else { return Theme.Colors.primary.opacity(0.35 + 0.65 * fraction) }
        return fraction >= 0.5 ? Theme.Colors.primary.opacity(0.35 + 0.65 * fraction) : Theme.NutrientColor.calories
    }

    private var dayAccessibilitySummary: String {
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
                .font(.system(size: 11))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

private struct ProgressNoticeCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "drop")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("WORTH NOTICING")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.Colors.textFaint)
                Text(text)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .card()
    }
}

private struct ProgressDestinationRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

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
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
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
            .padding(Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .navigationTitle("Progress summaries")
        .navigationBarTitleDisplayMode(.inline)
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
            Text(selectedPeriod.fullLabel.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(Theme.Colors.textFaint)

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
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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
        .card()
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
        .card()
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
                    if index > 0 { Divider().padding(.leading, Theme.Spacing.md) }
                    ProgressHistoryRow(item: item)
                }
            }
            .card()
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
            Text(period == .quarter ? "13 WEEKLY INTERVALS" : "DAILY INTERVALS")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.Colors.textFaint)

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

private struct SummaryReviewCard: View {
    let title: String
    let summaries: [DailySummary]
    let proteinGoal: Double?

    private var metrics: ProgressMetrics { .init(summaries: summaries, proteinGoal: proteinGoal) }
    private var weakest: DailySummary? { metrics.logged.min { $0.proteinG < $1.proteinG } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("\(title), from Pulse", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(Theme.Colors.primary)
            row("What went well", wentWell, "checkmark.circle.fill", .green)
            row("Where it got difficult", gotDifficult, "arrow.down.right.circle.fill", .orange)
            row("Pattern noticed", pattern, "waveform.path.ecg", Theme.Colors.primary)

            VStack(alignment: .leading, spacing: 3) {
                Text("ONE THING TO TRY")
                    .font(.system(size: 10, weight: .bold)).tracking(0.7)
                    .foregroundStyle(Theme.Colors.textFaint)
                Text(experiment)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.primary.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(Theme.Spacing.md)
        .card()
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
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(detail).font(.subheadline)
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
