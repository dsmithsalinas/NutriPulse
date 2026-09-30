import SwiftUI

// Daylight Goals (docs/daylight-redesign.md): a custom header (back-to-Progress + New goal),
// a full-detail hero card for the primary active goal, a live experiment tile framed around
// its intervention goal's own check-in, compact rows for any other active goals, and a
// "N finished goals" row that opens the completed list. Reached by pushing from Progress
// (`embeddedInNavigation`) or standalone via `--goals-preview`.

/// Local to Goals: a plain success/attention triad the shared palette doesn't carry (it only
/// has "wins" lime and "water" sky), plus the "Try this"-style amber used for a warning pill.
private extension Theme.Colors {
    static let goalMet    = Color(hex: 0x22A447)
    static let goalMissed = Color(hex: 0xD94B57)
    static let amberTile  = Color(hex: 0xFFEDD5)
    static let amberLabel = Color(hex: 0x9A3412)
}

struct GoalsView: View {
    var embeddedInNavigation = false
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var vm = GoalsViewModel()
    @State private var experiments: [PersonalExperiment] = []
    @State private var showCreate = false
    @State private var showExperiments = false
    @State private var showCompleted = false
    @State private var selectedGoal: GoalSelection?

    @ViewBuilder
    var body: some View {
        if embeddedInNavigation {
            screenContent
        } else {
            NavigationStack { screenContent }
        }
    }

    private var screenContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                header
                    .popIn(order: 0)

                if vm.isLoading && vm.active.isEmpty {
                    ProgressView("Loading goals…")
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else if vm.active.isEmpty {
                    goalsEmptyState
                        .popIn(order: 1)
                } else {
                    content
                }
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        // Always hidden: the custom header above supplies its own back button when pushed.
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            async let goalsLoad: Void = vm.load()
            async let experimentsLoad: Void = loadExperiments()
            _ = await (goalsLoad, experimentsLoad)
        }
        .task { await vm.load() }
        .task { await loadExperiments() }
        .sheet(isPresented: $showCreate) {
            CreateGoalView(vm: vm)
        }
        .onChange(of: showCreate) { _, isPresented in
            if !isPresented { Task { await loadExperiments() } }
        }
        .sheet(isPresented: $showExperiments) {
            ExperimentsView(activeGoals: vm.active)
        }
        .onChange(of: showExperiments) { _, isPresented in
            if !isPresented { Task { await loadExperiments() } }
        }
        .sheet(item: $selectedGoal) { selection in
            GoalDetailContainer(goalID: selection.id, vm: vm) { title in
                appState.pendingCoachPrompt = "How am I doing on my goal: \(title)?"
            }
        }
        .navigationDestination(isPresented: $showCompleted) {
            CompletedGoalsView(
                goals: vm.completed,
                isLoading: vm.isLoading,
                onSelect: { selectedGoal = GoalSelection(id: $0) }
            )
        }
        .alert("Couldn’t update goals", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "Please try again.")
        }
    }

    // MARK: - Header

    // Pushed from Progress: a back button row with New goal, then the title. On its own: the
    // title and New goal share one row, like the other Daylight screens.
    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if embeddedInNavigation {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.Colors.surfaceCard, in: Circle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Back to Progress")
                    Spacer()
                    newGoalButton
                }
                title
            } else {
                HStack(alignment: .center) {
                    title
                    Spacer(minLength: 8)
                    newGoalButton
                }
            }
        }
    }

    private var title: some View {
        Text("Goals")
            .font(Theme.Fonts.display(36, .extraBold, relativeTo: .largeTitle))
            .foregroundStyle(Theme.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var newGoalButton: some View {
        Button { showCreate = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("New goal")
                    .font(Theme.Fonts.body(14, .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Theme.Colors.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Create a goal")
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: Theme.Spacing.tileGap) {
            if let primary = heroState {
                GoalHeroCard(
                    state: primary,
                    onBooleanCheckin: { value in Task { await vm.record(value, for: primary) } },
                    onRatingCheckin: { value in Task { await vm.record(value, for: primary) } },
                    onAskPulse: {
                        appState.pendingCoachPrompt = "How am I doing on my goal: \(primary.bundle.version.title)?"
                    }
                )
                .popIn(order: 1)
            }

            if let data = experimentCardData {
                ExperimentTile(
                    data: data,
                    onYes: { Task { await vm.record(true, for: data.goalState) } },
                    onNotToday: { Task { await vm.record(false, for: data.goalState) } }
                )
                .popIn(order: 2)
            }

            ForEach(Array(secondaryGoals.enumerated()), id: \.element.id) { index, state in
                GoalCompactRow(state: state) { selectedGoal = GoalSelection(id: state.id) }
                    .popIn(order: 3 + index)
            }

            experimentsRow
                .popIn(order: 3 + secondaryGoals.count)

            if !vm.completed.isEmpty {
                completedRow
                    .popIn(order: 4 + secondaryGoals.count)
            }
        }
    }

    private var heroState: GoalCardState? {
        vm.active.first(where: { $0.measurement?.sourceType == .manualBoolean }) ?? vm.active.first
    }

    private var secondaryGoals: [GoalCardState] {
        vm.active.filter { $0.id != heroState?.id }
    }

    // Frames the intervention goal's own daily check-in as "the experiment" — an experiment
    // is just that goal on a timer, so its Yes/Not-today buttons are the goal's real check-in.
    private var experimentCardData: ExperimentCardData? {
        guard let running = experiments.first(where: { $0.status == .running }),
              let goalState = vm.active.first(where: { $0.id == running.interventionGoalId }),
              let start = Self.parseISODate(running.interventionStart)
        else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dayIndex = max((calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1, 1)
        let end = running.endDate.flatMap(Self.parseISODate)
        let totalDays = end.map { (calendar.dateComponents([.day], from: start, to: $0).day ?? 0) + 1 }
        let progress = totalDays.map { min(Double(dayIndex) / Double(max($0, 1)), 1) } ?? 0
        return ExperimentCardData(
            experiment: running, goalState: goalState,
            dayIndex: dayIndex, totalDays: totalDays, progress: progress
        )
    }

    private static func parseISODate(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private var experimentsRow: some View {
        Button { showExperiments = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "flask.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceInset, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal experiments")
                        .font(Theme.Fonts.body(15, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(experimentsSubtitle)
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Colors.textFaint)
            }
            .padding(14)
            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.tileSmall, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Create or review personal experiments")
    }

    private var experimentsSubtitle: String {
        let running = experiments.filter { $0.status == .running || $0.status == .baseline }.count
        guard running > 0 else { return "Test a question, not a diagnosis" }
        return "\(running) \(running == 1 ? "experiment" : "experiments") in progress"
    }

    private var completedRow: some View {
        Button { showCompleted = true } label: {
            HStack {
                Text(vm.completed.count == 1 ? "1 finished goal" : "\(vm.completed.count) finished goals")
                    .font(Theme.Fonts.body(15, .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, 6)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows your completed goals")
    }

    private var goalsEmptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "target")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Colors.primary)
            Text("Start with one clear goal")
                .font(Theme.Fonts.display(22, .bold, relativeTo: .title2))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Footing can combine quick check-ins with health data you already track.")
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Create a goal") { showCreate = true }
                .buttonStyle(.brandPrimary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 330)
        .tile()
    }

    private func loadExperiments() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--goals-preview")
            || ProcessInfo.processInfo.arguments.contains("--progress-preview") {
            experiments = []
            return
        }
        #endif
        experiments = (try? await ExperimentRepository().fetchAll()) ?? []
    }
}

private struct GoalSelection: Identifiable {
    let id: UUID
}

private struct ExperimentCardData {
    let experiment: PersonalExperiment
    let goalState: GoalCardState
    let dayIndex: Int
    let totalDays: Int?
    let progress: Double
}

// MARK: - Experiment tile

private struct ExperimentTile: View {
    let data: ExperimentCardData
    let onYes: () -> Void
    let onNotToday: () -> Void

    private var measurement: GoalMeasurement? { data.goalState.measurement }
    private var readableYet: Bool { data.goalState.progress.measuredCount >= 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dayLabel)
                .font(Theme.Fonts.body(12, .bold))
                .tracking(Theme.Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.violetLabel)

            Text(data.experiment.question)
                .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                .foregroundStyle(Theme.Colors.violetInk)

            if data.totalDays != nil {
                MeterBar(progress: data.progress, color: Theme.Colors.violetLabel, track: Theme.Colors.violet.opacity(0.5), height: 8, delay: 0.4)
            }

            if measurement?.sourceType == .manualBoolean {
                Text(checkinQuestion)
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.violetInk)
                HStack(spacing: 8) {
                    Button("Yes", action: onYes)
                        .buttonStyle(ExperimentButtonStyle(fill: Theme.Colors.violetLabel, foreground: .white))
                    Button("Not today", action: onNotToday)
                        .buttonStyle(ExperimentButtonStyle(fill: .white, foreground: Theme.Colors.violetInk))
                }
            }

            Text(readableYet
                 ? "Enough days measured to start reading this experiment."
                 : "Too early to read — \(data.goalState.progress.measuredCount) \(data.goalState.progress.measuredCount == 1 ? "night" : "nights") measured so far.")
                .font(Theme.Fonts.body(13))
                .foregroundStyle(Theme.Colors.violetLabel)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.violet, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var dayLabel: String {
        data.totalDays.map { "Experiment · day \(data.dayIndex) of \($0)" } ?? "Experiment · day \(data.dayIndex)"
    }

    private var checkinQuestion: String {
        let title = data.goalState.bundle.version.title.lowercased()
        if title.contains("caffeine") && title.contains("noon") {
            return "Did you skip caffeine after noon today?"
        }
        return "Did you complete this today?"
    }
}

private struct ExperimentButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body(15, .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Compact goal row (secondary active goals, and the completed list)

private struct GoalCompactRow: View {
    let state: GoalCardState
    let onTap: () -> Void

    private var measurement: GoalMeasurement? { state.measurement }
    private var hasNumericProgress: Bool {
        measurement?.sourceType == .automatic && state.progress.value != nil && state.progress.target != nil
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                        .frame(width: 30, height: 30)
                        .background(Theme.Colors.surfaceInset, in: Circle())
                    Text(state.bundle.version.title)
                        .font(Theme.Fonts.body(15, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(valueLine)
                        .font(Theme.Fonts.body(13, .semibold).monospacedDigit())
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Colors.textFaint)
                }
                if hasNumericProgress, let value = state.progress.value, let target = state.progress.target, target > 0 {
                    MeterBar(progress: value / target, color: Theme.Colors.skyAction, track: Theme.Colors.surfaceInset, height: 8, delay: 0.4)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.tileSmall, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(state.bundle.version.title), \(valueLine)")
        .accessibilityHint("Shows progress, daily measurements, and goal setup")
    }

    private var valueLine: String {
        guard let value = state.progress.value else { return "Not enough data" }
        let formatted = value.formatted(.number.precision(.fractionLength(0...1)))
        if let target = state.progress.target {
            return "\(formatted) · floor \(target.formatted(.number.precision(.fractionLength(0...1)))) \(measurement?.unit ?? "")"
                .trimmingCharacters(in: .whitespaces)
        }
        return "\(formatted) \(measurement?.unit ?? "")".trimmingCharacters(in: .whitespaces)
    }

    private var symbol: String {
        switch measurement?.sourceMetric {
        case .steps: "shoeprints.fill"
        case .workouts, .workoutMinutes: "figure.run"
        case .sleepDuration: "bed.double.fill"
        case .protein: "fork.knife"
        case .weight: "scalemass.fill"
        case .water: "drop.fill"
        default: "target"
        }
    }
}

// MARK: - Completed goals

private struct CompletedGoalsView: View {
    let goals: [GoalCardState]
    let isLoading: Bool
    let onSelect: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.Colors.surfaceCard, in: Circle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Back to Goals")
                    Spacer()
                }
                Text("Completed")
                    .font(Theme.Fonts.display(30, .extraBold, relativeTo: .title))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if isLoading && goals.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if goals.isEmpty {
                    BrandedEmptyState(
                        icon: "checkmark.circle",
                        title: "No completed goals yet",
                        message: "Finished goals and their conclusions will stay here."
                    )
                    .frame(minHeight: 260)
                } else {
                    ForEach(goals) { state in
                        GoalCompactRow(state: state) { onSelect(state.id) }
                    }
                }
            }
            .padding(Theme.Spacing.page)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Hero card (primary active goal)

private struct GoalHeroCard: View {
    let state: GoalCardState
    let onBooleanCheckin: (Bool) -> Void
    let onRatingCheckin: (Double) -> Void
    let onAskPulse: () -> Void
    @State private var selectedDay: GoalDaySelection?

    private var measurement: GoalMeasurement? { state.measurement }
    private var timelineDays: [GoalTimelineDay] {
        if state.bundle.version.period == .weekly {
            return weeklyTimelineDays
        }
        // The mockup's goal card shows the last 14 days rather than 7, for a fuller read.
        return state.progress.days.suffix(14).map { GoalTimelineDay(date: $0.0, dayState: $0.1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(Theme.Fonts.body(12, .bold))
                        .tracking(Theme.Typography.eyebrowTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(state.bundle.version.title)
                        .font(Theme.Fonts.display(22, .bold, relativeTo: .title2))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(statusPill.label)
                    .font(Theme.Fonts.body(13, .bold))
                    .foregroundStyle(statusPill.text)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(statusPill.fill, in: Capsule())
            }

            if !timelineDays.isEmpty {
                dayGrid
            }

            HStack {
                if state.progress.currentStreak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color(hex: 0xFB923C))
                        Text("\(state.progress.currentStreak) \(state.progress.currentStreak == 1 ? "day" : "days") in a row")
                            .font(Theme.Fonts.body(15, .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }
                Spacer()
                Text("Dashed = not measured")
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Divider().overlay(Theme.Colors.hairline)

            if state.bundle.goal.status == .active {
                checkin
                Button("Ask Pulse about this goal", action: onAskPulse)
                    .font(Theme.Fonts.body(14, .semibold))
                    .foregroundStyle(Theme.Colors.primaryText)
            } else {
                completedSummary
            }
        }
        .padding(18)
        .tile()
        .sheet(item: $selectedDay) { selection in
            GoalDayDetailView(state: state, selection: selection, onAskPulse: onAskPulse)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var eyebrow: String {
        if let start = parse(state.bundle.version.startDate) {
            return "\(state.bundle.version.period.displayName) · from \(start.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return state.bundle.version.period.displayName
    }

    private var dayGrid: some View {
        HStack(spacing: 5) {
            ForEach(timelineDays) { item in
                Button {
                    guard let dayState = item.dayState else { return }
                    selectedDay = GoalDaySelection(date: item.date, dayState: dayState)
                } label: {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(cellFill(item.dayState))
                        .overlay {
                            if cellDashed(item.dayState) {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Theme.Colors.primary.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [3]))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 22)
                }
                .buttonStyle(.plain)
                .disabled(item.dayState == nil)
                .accessibilityLabel(dayAccessibility(item))
                .accessibilityHint(item.dayState == nil
                                   ? "This day is outside the goal schedule"
                                   : "Shows what Footing measured for this day")
            }
        }
    }

    private func cellFill(_ state: GoalDayState?) -> Color {
        switch state {
        case .met: Theme.Colors.primary
        case .notMet: Theme.Colors.surfaceInset
        case .missing, .pending, nil: .clear
        }
    }

    private func cellDashed(_ state: GoalDayState?) -> Bool {
        switch state {
        case .missing, .pending, nil: true
        default: false
        }
    }

    private var weeklyTimelineDays: [GoalTimelineDay] {
        let calendar = Calendar.current
        let referenceDate = state.bundle.goal.status == .active
            ? Date.now
            : GoalLifecycle.evaluationDate(for: state.bundle)
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return [] }
        let today = calendar.startOfDay(for: referenceDate)
        let startDate = parse(state.bundle.version.startDate)
        let endDate = state.bundle.version.endDate.flatMap(parse)

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            let day = calendar.startOfDay(for: date)
            let appleWeekday = calendar.component(.weekday, from: day)
            let isoWeekday = appleWeekday == 1 ? 7 : appleWeekday - 1
            let isScheduled = state.bundle.version.scheduledWeekdays.contains(isoWeekday)
                && startDate.map { day >= calendar.startOfDay(for: $0) } ?? true
                && endDate.map { day <= calendar.startOfDay(for: $0) } ?? true

            guard isScheduled else { return GoalTimelineDay(date: day, dayState: nil) }
            if let existing = state.progress.days.first(where: { calendar.isDate($0.0, inSameDayAs: day) }) {
                return GoalTimelineDay(date: day, dayState: existing.1)
            }
            return GoalTimelineDay(date: day, dayState: day > today ? .pending : .missing)
        }
    }

    @ViewBuilder
    private var checkin: some View {
        switch measurement?.sourceType {
        case .manualBoolean:
            VStack(alignment: .leading, spacing: 12) {
                Text(checkinQuestion)
                    .font(Theme.Fonts.body(16, .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                HStack(spacing: 10) {
                    checkinButton("Yes", color: Theme.Colors.goalMet) { onBooleanCheckin(true) }
                    checkinButton("Not today", color: Theme.Colors.goalMissed) { onBooleanCheckin(false) }
                }
            }
        case .manualRating:
            VStack(alignment: .leading, spacing: 10) {
                Text("How would you rate today?")
                    .font(Theme.Fonts.body(16, .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                HStack {
                    ForEach(1...5, id: \.self) { value in
                        Button("\(value)") { onRatingCheckin(Double(value)) }
                            .font(Theme.Fonts.body(16, .semibold))
                            .foregroundStyle(Theme.Colors.primary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Theme.Colors.surfaceInset, in: Circle())
                    }
                }
            }
        default:
            GoalAutomaticProgress(state: state)
        }
    }

    private var completedSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Final result")
                .font(Theme.Fonts.body(12, .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
            if state.progress.measuredCount == 0 {
                Text("No usable measurements were available for this goal period.")
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.textPrimary)
            } else {
                Text("\(state.progress.metCount) of \(state.progress.measuredCount) measured days met the goal.")
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func checkinButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(Theme.Fonts.body(15, .bold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var checkinQuestion: String {
        let title = state.bundle.version.title.lowercased()
        if title.contains("caffeine") && title.contains("noon") {
            return "Did you avoid caffeine after noon today?"
        }
        return "Did you complete this today?"
    }

    private var statusPill: (fill: Color, text: Color, label: String) {
        switch state.progress.status {
        case .met: (Theme.Colors.lime, Theme.Colors.limeInk, "Completed")
        case .onTrack: (Theme.Colors.lime, Theme.Colors.limeInk, "On track")
        case .offTrack: (Theme.Colors.amberTile, Theme.Colors.amberLabel, "Needs attention")
        case .notMet: (Theme.Colors.amberTile, Theme.Colors.amberLabel, "Ended")
        case .missing, .insufficientData: (Theme.Colors.surfaceInset, Theme.Colors.textSecondary, "Gathering data")
        case .pending: (Theme.Colors.surfaceInset, Theme.Colors.textSecondary, "Pending")
        }
    }

    private func dayAccessibility(_ item: GoalTimelineDay) -> String {
        let state: String
        switch item.dayState {
        case .met: state = "met"
        case .notMet: state = "not met"
        case .missing: state = "no data"
        case .pending: state = "pending"
        case nil: state = "not scheduled"
        }
        let today = Calendar.current.isDateInToday(item.date) ? ", today" : ""
        return "\(item.date.formatted(date: .abbreviated, time: .omitted))\(today), \(state)"
    }

    private func parse(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: .init(year: parts[0], month: parts[1], day: parts[2]))
    }
}

private struct GoalTimelineDay: Identifiable {
    let date: Date
    let dayState: GoalDayState?

    var id: Date { date }
}

private struct GoalDaySelection: Identifiable {
    let date: Date
    let dayState: GoalDayState

    var id: Date { date }
}

private struct GoalDayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let state: GoalCardState
    let selection: GoalDaySelection
    let onAskPulse: () -> Void

    private var measurement: GoalMeasurement? { state.measurement }
    private var value: GoalDailyValue? {
        state.values.last { Calendar.current.isDate($0.date, inSameDayAs: selection.date) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: statusSymbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(statusColor)
                        .frame(width: 48, height: 48)
                        .background(statusColor.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusTitle)
                            .font(Theme.Fonts.display(22, .bold, relativeTo: .title2))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(selection.date.formatted(date: .complete, time: .omitted))
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(
                        measurement?.sourceDisplayName ?? "Goal check-in",
                        systemImage: measurement?.sourceSymbol ?? "target"
                    )
                    .font(Theme.Fonts.body(16, .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    Text(valueSummary)
                        .font(Theme.Fonts.display(22, .bold, relativeTo: .title2))
                        .foregroundStyle(Theme.Colors.primary)
                    Text(explanation)
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tile()

                if selection.dayState == .missing {
                    Label("No data is not counted as a failure.", systemImage: "minus.circle")
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Button("Ask Pulse about this day") {
                    dismiss()
                    onAskPulse()
                }
                .buttonStyle(.brandPrimary)
            }
            .padding(20)
            .background(Theme.Colors.ground.ignoresSafeArea())
            .navigationTitle("Daily detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var statusTitle: String {
        switch selection.dayState {
        case .met: "Goal met"
        case .notMet: "Target not reached"
        case .missing: "No data"
        case .pending: "Not measured yet"
        }
    }

    private var statusSymbol: String {
        switch selection.dayState {
        case .met: "checkmark"
        case .notMet: "xmark"
        case .missing: "minus"
        case .pending: "clock"
        }
    }

    private var statusColor: Color {
        switch selection.dayState {
        case .met: Theme.Colors.goalMet
        case .notMet: Theme.Colors.goalMissed
        case .missing, .pending: Theme.Colors.textFaint
        }
    }

    private var valueSummary: String {
        guard let value else { return "Nothing recorded" }
        if let actual = value.displayValue, let target = value.displayTarget {
            return "\(format(actual)) g of \(format(target)) g"
        }
        if let number = value.number {
            return "\(format(number)) \(measurement?.unit ?? "")"
        }
        if let boolean = value.boolean {
            return boolean ? "Recorded as completed" : "Recorded as not completed"
        }
        return "Nothing recorded"
    }

    private var explanation: String {
        switch selection.dayState {
        case .met:
            return "Footing found measured data from \(measurement?.sourceDisplayName ?? "the selected source") and it met this goal’s definition for the day."
        case .notMet:
            if measurement?.sourceMetric == .protein {
                return "Your food log contained enough information to measure the day, but the logged protein total was below your nutrition target. Missing meals can affect this result."
            }
            return "Footing found measured data from \(measurement?.sourceDisplayName ?? "the selected source"), but it did not meet this goal’s configured target for the day."
        case .missing:
            return "Footing could not find enough usable data from \(measurement?.sourceDisplayName ?? "the selected source") for this day. It remains unknown instead of being marked as missed."
        case .pending:
            return "This day is still in progress and has not been evaluated yet."
        }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct GoalAutomaticProgress: View {
    let state: GoalCardState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(valueLabel)
                    .font(Theme.Fonts.display(22, .bold, relativeTo: .title2))
                    .foregroundStyle(Theme.Colors.primary)
                Label(
                    state.measurement?.sourceDisplayName ?? "Connected data",
                    systemImage: state.measurement?.sourceSymbol ?? "link"
                )
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text("\(Int((state.progress.coverage * 100).rounded()))% measured")
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var valueLabel: String {
        guard let value = state.progress.value else { return "No data yet" }
        let unit = state.measurement?.unit.map { " \($0)" } ?? ""
        return "\(value.formatted(.number.precision(.fractionLength(0))))\(unit)"
    }
}

// MARK: - Goal detail (pushed from a compact row)

private struct GoalDetailContainer: View {
    let goalID: UUID
    let vm: GoalsViewModel
    let onAskPulse: (String) -> Void

    var body: some View {
        if let state = vm.state(for: goalID) {
            GoalDetailView(
                state: state,
                onBooleanCheckin: { value in
                    Task { await vm.record(value, for: state) }
                },
                onRatingCheckin: { value in
                    Task { await vm.record(value, for: state) }
                },
                onAskPulse: { onAskPulse(state.bundle.version.title) }
            )
        } else {
            ContentUnavailableView(
                "Goal unavailable",
                systemImage: "target",
                description: Text("This goal could not be refreshed.")
            )
        }
    }
}

private struct GoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let state: GoalCardState
    let onBooleanCheckin: (Bool) -> Void
    let onRatingCheckin: (Double) -> Void
    let onAskPulse: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GoalHeroCard(
                        state: state,
                        onBooleanCheckin: onBooleanCheckin,
                        onRatingCheckin: onRatingCheckin,
                        onAskPulse: onAskPulse
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Goal setup")
                            .font(Theme.Fonts.body(16, .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        detailRow("Target", value: targetDescription)
                        Divider().overlay(Theme.Colors.hairline)
                        detailRow("Measured with", value: state.measurement?.sourceDisplayName ?? "Connected data")
                        if let quality = state.quality {
                            Divider().overlay(Theme.Colors.hairline)
                            detailRow("Data quality", value: qualityDescription(quality))
                        }
                        Divider().overlay(Theme.Colors.hairline)
                        detailRow("Timeframe", value: timeframeDescription)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tile()
                }
                .padding(16)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .navigationTitle("Goal details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(Theme.Fonts.body(13))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.Fonts.body(15, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func qualityDescription(_ quality: MetricQualityAssessment) -> String {
        switch quality.status {
        case .usable:
            return "Usable · \(Int((quality.coverage * 100).rounded()))% coverage"
        case .usableWithCaution:
            return "Usable with limits · \(Int((quality.coverage * 100).rounded()))% coverage"
        case .insufficientData:
            return "Not enough usable data yet"
        case .conflictingSources:
            return "Connected sources disagree"
        case .implausible:
            return "Questionable readings excluded"
        }
    }

    private var targetDescription: String {
        guard let measurement = state.measurement,
              let target = measurement.targetValue else { return "Track progress" }
        let formatted = target.formatted(.number.precision(.fractionLength(0...1)))
        switch measurement.kind {
        case .frequency:
            return "\(formatted) \(measurement.unit ?? "times") per \(periodNoun)"
        case .habit where measurement.aggregation == .rate:
            return "\((target * 100).formatted(.number.precision(.fractionLength(0))))% of measured days"
        default:
            return "\(formatted) \(measurement.unit ?? "")".trimmingCharacters(in: .whitespaces)
        }
    }

    private var periodNoun: String {
        switch state.bundle.version.period {
        case .daily: "day"
        case .weekly: "week"
        case .monthly: "month"
        case .annual: "year"
        case .custom: "goal period"
        case .ongoing: "ongoing period"
        }
    }

    private var timeframeDescription: String {
        if let endDate = state.bundle.version.endDate {
            return "\(state.bundle.version.startDate) – \(endDate)"
        }
        return state.bundle.version.period == .ongoing
            ? "Ongoing"
            : state.bundle.version.period.displayName
    }
}
