import SwiftUI

struct GoalsView: View {
    var embeddedInNavigation = false
    @Environment(AppState.self) private var appState
    @State private var vm = GoalsViewModel()
    @State private var selection: GoalListSelection = .active
    @State private var showCreate = false
    @State private var showExperiments = false
    @State private var selectedGoal: GoalSelection?

    private enum GoalListSelection: String, CaseIterable, Identifiable {
        case active = "Active"
        case completed = "Completed"
        var id: String { rawValue }
    }

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
                VStack(spacing: 16) {
                    header
                    segment
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .toolbar(embeddedInNavigation ? .visible : .hidden, for: .navigationBar)
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .sheet(isPresented: $showCreate) {
                CreateGoalView(vm: vm)
            }
            .sheet(isPresented: $showExperiments) {
                ExperimentsView(activeGoals: vm.active)
            }
            .sheet(item: $selectedGoal) { selection in
                GoalDetailContainer(goalID: selection.id, vm: vm) { title in
                    appState.pendingCoachPrompt = "How am I doing on my goal: \(title)?"
                }
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Goals")
                    .font(Theme.Typography.display)
                Text("Today · \(Date.now.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Button { showCreate = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 48, height: 48)
                    .background(Theme.Colors.surfaceCard)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.Colors.hairline))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Create a goal")
        }
    }

    private var segment: some View {
        Picker("Goal status", selection: $selection) {
            ForEach(GoalListSelection.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var content: some View {
        if selection == .completed {
            if vm.isLoading && vm.completed.isEmpty {
                ProgressView("Loading completed goals…")
                    .frame(maxWidth: .infinity, minHeight: 280)
            } else if vm.completed.isEmpty {
                completedEmptyState
            } else {
                completedGoals
            }
        } else if vm.isLoading && vm.active.isEmpty {
            ProgressView("Loading goals…")
                .frame(maxWidth: .infinity, minHeight: 280)
        } else if vm.active.isEmpty {
            goalsEmptyState
        } else {
            activeGoals
        }
    }

    private var activeGoals: some View {
        VStack(spacing: 16) {
            if let primary = heroState {
                GoalHeroCard(
                    state: primary,
                    allowsCheckin: true,
                    onBooleanCheckin: { value in Task { await vm.record(value, for: primary) } },
                    onRatingCheckin: { value in Task { await vm.record(value, for: primary) } },
                    onAskPulse: {
                        appState.pendingCoachPrompt = "How am I doing on my goal: \(primary.bundle.version.title)?"
                    }
                )
            }

            ForEach(vm.active.filter { $0.id != heroState?.id }) { state in
                GoalSummaryRow(state: state) {
                    selectedGoal = GoalSelection(id: state.id)
                }
            }

            Button { showExperiments = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.surfaceInset)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Personal Experiments")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Advanced comparisons across habits and outcomes")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.Colors.textFaint)
                }
                .padding(14)
                .card()
            }
            .buttonStyle(.plain)
        }
    }

    private var heroState: GoalCardState? {
        vm.active.first(where: { $0.measurement?.sourceType == .manualBoolean }) ?? vm.active.first
    }

    private var completedGoals: some View {
        VStack(spacing: 12) {
            ForEach(vm.completed) { state in
                GoalSummaryRow(state: state) {
                    selectedGoal = GoalSelection(id: state.id)
                }
            }
        }
    }

    private var goalsEmptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "target")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Colors.primary)
            Text("Start with one clear goal")
                .font(Theme.Typography.title)
            Text("Footing can combine quick check-ins with health data you already track.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Create a goal") { showCreate = true }
                .buttonStyle(.brandPrimary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 330)
        .card()
    }

    private var completedEmptyState: some View {
        BrandedEmptyState(
            icon: "checkmark.circle",
            title: "No completed goals yet",
            message: "Finished goals and their conclusions will stay here."
        )
        .frame(minHeight: 300)
    }
}

private struct GoalSelection: Identifiable {
    let id: UUID
}

private struct GoalHeroCard: View {
    let state: GoalCardState
    let allowsCheckin: Bool
    let onBooleanCheckin: (Bool) -> Void
    let onRatingCheckin: (Double) -> Void
    let onAskPulse: () -> Void
    @State private var selectedDay: GoalDaySelection?

    private var measurement: GoalMeasurement? { state.measurement }
    private var timelineDays: [GoalTimelineDay] {
        if state.bundle.version.period == .weekly {
            return weeklyTimelineDays
        }
        return state.progress.days.suffix(7).map {
            GoalTimelineDay(date: $0.0, dayState: $0.1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceInset)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.bundle.version.title)
                        .font(Theme.Typography.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(periodLabel)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Text(statusLabel)
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            if !timelineDays.isEmpty {
                weekStrip
            }

            Divider().overlay(Theme.Colors.hairline)

            if allowsCheckin {
                checkin
            } else {
                completedSummary
            }

            Divider().overlay(Theme.Colors.hairline)

            HStack(alignment: .top, spacing: 10) {
                Image("PulseMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Pulse")
                        .font(Theme.Typography.headline)
                    Text(pulseSummary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Button("Ask Pulse about this goal", action: onAskPulse)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.primary)
                        .padding(.top, 3)
                }
            }
        }
        .padding(16)
        .card()
        .sheet(item: $selectedDay) { selection in
            GoalDayDetailView(state: state, selection: selection, onAskPulse: onAskPulse)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.bundle.version.period == .weekly
                 ? (allowsCheckin ? "This week" : "Goal week")
                 : "Recent days")
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)

            HStack(spacing: 4) {
                ForEach(timelineDays) { item in
                    Button {
                        guard let dayState = item.dayState else { return }
                        selectedDay = GoalDaySelection(date: item.date, dayState: dayState)
                    } label: {
                        VStack(spacing: 7) {
                            Text(item.date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption2.weight(isCurrentDay(item.date) ? .bold : .regular))
                                .foregroundStyle(isCurrentDay(item.date)
                                                 ? Theme.Colors.primary
                                                 : Theme.Colors.textSecondary)
                            Image(systemName: daySymbol(item.dayState))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(dayColor(item.dayState))
                                .frame(width: 30, height: 30)
                                .background(dayColor(item.dayState).opacity(item.dayState == .missing ? 0.08 : 0.12))
                                .clipShape(Circle())
                        }
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isCurrentDay(item.date) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.Colors.primary.opacity(0.07))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(item.dayState == nil)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(dayAccessibility(item))
                    .accessibilityHint(item.dayState == nil
                                       ? "This day is outside the goal schedule"
                                       : "Shows what Footing measured for this day")
                }
            }
        }
    }

    private var weeklyTimelineDays: [GoalTimelineDay] {
        let calendar = Calendar.current
        let referenceDate = allowsCheckin
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

    private func isCurrentDay(_ date: Date) -> Bool {
        allowsCheckin && Calendar.current.isDateInToday(date)
    }

    @ViewBuilder
    private var checkin: some View {
        switch measurement?.sourceType {
        case .manualBoolean:
            VStack(alignment: .leading, spacing: 12) {
                Text(checkinQuestion)
                    .font(Theme.Typography.headline)
                HStack(spacing: 10) {
                    checkinButton("Yes", color: Color(hex: 0x22A447)) { onBooleanCheckin(true) }
                    checkinButton("Not today", color: Color(hex: 0xD94B57)) { onBooleanCheckin(false) }
                }
                Button("No data / Skip") { }
                    .font(Theme.Typography.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.Colors.primary.opacity(0.55), lineWidth: 1)
                    }
                    .accessibilityHint("Leaves today unmeasured. It will not count as a failure.")
            }
        case .manualRating:
            VStack(alignment: .leading, spacing: 10) {
                Text("How would you rate today?")
                    .font(Theme.Typography.headline)
                HStack {
                    ForEach(1...5, id: \.self) { value in
                        Button("\(value)") { onRatingCheckin(Double(value)) }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.Colors.primary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Theme.Colors.surfaceInset)
                            .clipShape(Circle())
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
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
            if state.progress.measuredCount == 0 {
                Text("No usable measurements were available for this goal period.")
                    .font(Theme.Typography.body)
            } else {
                Text("\(state.progress.metCount) of \(state.progress.measuredCount) measured days met the goal.")
                    .font(Theme.Typography.body.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func checkinButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(Theme.Typography.body.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var symbol: String {
        switch measurement?.sourceMetric {
        case .steps: "shoeprints.fill"
        case .workouts, .workoutMinutes: "figure.run"
        case .sleepDuration: "bed.double.fill"
        case .protein: "fork.knife"
        case .weight: "scalemass.fill"
        case .water: "drop.fill"
        default: measurement?.sourceType == .manualRating ? "sun.max.fill" : "cup.and.saucer.fill"
        }
    }

    private var checkinQuestion: String {
        let title = state.bundle.version.title.lowercased()
        if title.contains("caffeine") && title.contains("noon") {
            return "Did you avoid caffeine after noon today?"
        }
        return "Did you complete this today?"
    }

    private var periodLabel: String {
        if let end = state.bundle.version.endDate,
           let startDate = parse(state.bundle.version.startDate),
           let endDate = parse(end) {
            let elapsed = max(Calendar.current.dateComponents([.day], from: startDate, to: .now).day ?? 0, 0) + 1
            let total = max(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0, 0) + 1
            return "Day \(min(elapsed, total)) of \(total)"
        }
        return state.bundle.version.period.displayName
    }

    private var statusLabel: String {
        switch state.progress.status {
        case .met: "Completed"
        case .onTrack: "On track"
        case .offTrack: "Needs attention"
        case .notMet: "Ended"
        case .missing, .insufficientData: "Gathering data"
        case .pending: "Pending"
        }
    }

    private var statusColor: Color {
        switch state.progress.status {
        case .met, .onTrack: Color(hex: 0x22A447)
        case .offTrack, .notMet: Color(hex: 0xD97706)
        default: Theme.Colors.primary
        }
    }

    private var pulseSummary: String {
        guard state.progress.measuredCount > 0 else {
            return "There isn’t enough measured data yet. A skipped day will stay unknown, not count against you."
        }
        let noun = state.progress.measuredCount == 1 ? "day" : "days"
        return "You met this goal on \(state.progress.metCount) of \(state.progress.measuredCount) measured \(noun). \(missingSummary)"
    }

    private var missingSummary: String {
        let missing = max(state.progress.expectedCount - state.progress.measuredCount, 0)
        if missing == 0 { return "Your measured history is up to date." }
        return "\(missing) unmeasured \(missing == 1 ? "day is" : "days are") kept separate."
    }

    private func daySymbol(_ state: GoalDayState?) -> String {
        switch state {
        case .met: "checkmark"
        case .notMet: "xmark"
        case .missing: "minus"
        case .pending: "circle"
        case nil: "minus"
        }
    }

    private func dayColor(_ state: GoalDayState?) -> Color {
        switch state {
        case .met: Color(hex: 0x22A447)
        case .notMet: Color(hex: 0xD94B57)
        case .missing, .pending: Theme.Colors.textFaint
        case nil: Theme.Colors.textFaint.opacity(0.45)
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
                        .background(statusColor.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusTitle)
                            .font(Theme.Typography.title)
                        Text(selection.date.formatted(date: .complete, time: .omitted))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(
                        measurement?.sourceDisplayName ?? "Goal check-in",
                        systemImage: measurement?.sourceSymbol ?? "target"
                    )
                    .font(Theme.Typography.headline)
                    Text(valueSummary)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.primary)
                    Text(explanation)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                if selection.dayState == .missing {
                    Label("No data is not counted as a failure.", systemImage: "minus.circle")
                        .font(Theme.Typography.caption)
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
        case .met: Color(hex: 0x22A447)
        case .notMet: Color(hex: 0xD94B57)
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
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.primary)
                Label(
                    state.measurement?.sourceDisplayName ?? "Connected data",
                    systemImage: state.measurement?.sourceSymbol ?? "link"
                )
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text("\(Int((state.progress.coverage * 100).rounded()))% measured")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var valueLabel: String {
        guard let value = state.progress.value else { return "No data yet" }
        let unit = state.measurement?.unit.map { " \($0)" } ?? ""
        return "\(value.formatted(.number.precision(.fractionLength(0))))\(unit)"
    }
}

private struct GoalDetailContainer: View {
    let goalID: UUID
    let vm: GoalsViewModel
    let onAskPulse: (String) -> Void

    var body: some View {
        if let state = vm.state(for: goalID) {
            GoalDetailView(
                state: state,
                allowsCheckin: state.bundle.goal.status == .active,
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
    let allowsCheckin: Bool
    let onBooleanCheckin: (Bool) -> Void
    let onRatingCheckin: (Double) -> Void
    let onAskPulse: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GoalHeroCard(
                        state: state,
                        allowsCheckin: allowsCheckin,
                        onBooleanCheckin: onBooleanCheckin,
                        onRatingCheckin: onRatingCheckin,
                        onAskPulse: onAskPulse
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Goal setup")
                            .font(Theme.Typography.headline)
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
                    .card()
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
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.body.weight(.semibold))
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

private struct GoalSummaryRow: View {
    let state: GoalCardState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceInset)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.bundle.version.title)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if state.measurement?.sourceType == .automatic {
                        Text(state.measurement?.sourceDisplayName ?? "Connected data")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textFaint)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textFaint)
            }
            .padding(14)
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View details for \(state.bundle.version.title)")
        .accessibilityHint("Shows progress, daily measurements, and goal setup")
    }

    private var subtitle: String {
        guard let value = state.progress.value else { return "Not enough measured data" }
        let formatted = value.formatted(.number.precision(.fractionLength(0)))
        if let target = state.progress.target {
            return "\(formatted) of \(target.formatted(.number.precision(.fractionLength(0)))) \(state.measurement?.unit ?? "")"
        }
        return "\(formatted) \(state.measurement?.unit ?? "")"
    }

    private var symbol: String {
        switch state.measurement?.sourceMetric {
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
