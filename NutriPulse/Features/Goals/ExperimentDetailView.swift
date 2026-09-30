import SwiftUI

// The full arc for one personal experiment (docs/daylight-redesign.md): Setup (what's changing,
// what's measured, for how long), Running (day X of Y, today's check-in, a small tally), and
// Result (once it's finished, an honest comparison of the outcome on intervention vs
// non-intervention days). Reached from ExperimentsView's list.
struct ExperimentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let experiment: PersonalExperiment
    let onUpdated: () async -> Void

    @State private var goalBundle: PersonalGoalBundle?
    @State private var comparisonDays: [ExperimentDayObservation] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let goalRepository = PersonalGoalRepository()
    private let experimentRepository = ExperimentRepository()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                SheetHeader(title: "Experiment", onClose: { dismiss() })

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    setupCard
                    if !isFinished {
                        runningCard
                    }
                    resultCard
                    Text("Experiment results use descriptive associations only. They do not establish causation or provide medical advice.")
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.page)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .task { await load() }
        .alert("Couldn’t save your check-in", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    // MARK: - Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TileEyebrow("Setup")
            Text(experiment.question)
                .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                .foregroundStyle(Theme.Colors.textPrimary)
            // Rows only for what's known: "Unavailable" read like an error, not a missing detail.
            if let changing = goalBundle?.version.title {
                Divider().overlay(Theme.Colors.hairline)
                detailRow("Changing", value: changing)
            }
            if let measuring = outcomeMetric?.name {
                Divider().overlay(Theme.Colors.hairline)
                detailRow("Measuring", value: measuring)
            }
            Divider().overlay(Theme.Colors.hairline)
            detailRow("Window", value: ExperimentDateRange.label(start: experiment.interventionStart, end: experiment.endDate))
        }
        .tile()
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Running

    private var runningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow(dayLabel, color: Theme.Colors.violetLabel)

            if let timeline, timeline.totalDays != nil {
                MeterBar(progress: timeline.progress, color: Theme.Colors.violetLabel, track: Theme.Colors.violet.opacity(0.5), height: 8)
            }

            if let measurement = goalBundle?.primaryMeasurement, measurement.sourceType == .manualBoolean {
                Text("Did you complete this today?")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.violetInk)
                HStack(spacing: 8) {
                    Button("Yes") { checkIn(true) }
                        .buttonStyle(DetailCheckInButtonStyle(fill: Theme.Colors.violetLabel, foreground: .white))
                    Button("Not today") { checkIn(false) }
                        .buttonStyle(DetailCheckInButtonStyle(fill: .white, foreground: Theme.Colors.violetInk))
                }
                .disabled(isSaving)
            }

            if let tally = interventionTally {
                Text("Done on \(tally.done) of \(tally.total) days you've checked in so far.")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.violetLabel)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.violet, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
    }

    private var dayLabel: String {
        guard let timeline else { return "Running" }
        return timeline.totalDays.map { "Day \(timeline.dayIndex) of \($0)" } ?? "Day \(timeline.dayIndex)"
    }

    private var interventionTally: (done: Int, total: Int)? {
        guard let bundle = goalBundle, let measurementId = bundle.primaryMeasurement?.id else { return nil }
        let byDate = ExperimentInterventionDays.build(
            checkins: bundle.checkins, observations: bundle.observations, measurementId: measurementId
        )
        let inWindow = byDate.filter { date, _ in
            date >= experiment.interventionStart && (experiment.endDate.map { date <= $0 } ?? true)
        }
        guard !inWindow.isEmpty else { return nil }
        return (inWindow.values.filter { $0 }.count, inWindow.count)
    }

    // MARK: - Result

    @ViewBuilder
    private var resultCard: some View {
        if isFinished {
            VStack(alignment: .leading, spacing: 10) {
                TileEyebrow("Result", color: Theme.Colors.violetLabel)
                if let comparison, comparison.isReadable {
                    Text(resultSentence(comparison))
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("This shows an association on the days you logged, not a cause.")
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    Text(ExperimentComparisonResult.notEnoughDataMessage)
                        .font(Theme.Fonts.body(15, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if let comparison {
                        Text("\(comparison.interventionCount) measured day\(comparison.interventionCount == 1 ? "" : "s") with it, \(comparison.nonInterventionCount) without.")
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    } else {
                        Text("Check in on days you do this and days you don't — the comparison needs both.")
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .tile()
        }
    }

    private var outcomeMetric: ExperimentMetricSummary? { experiment.primaryOutcomeMeasurement?.metric }

    private var timeline: ExperimentTimeline? {
        ExperimentTimelineCalculator.timeline(interventionStart: experiment.interventionStart, endDate: experiment.endDate)
    }

    private var isFinished: Bool {
        experiment.status == .completed || experiment.status == .archived || (timeline?.hasElapsed ?? false)
    }

    private var comparison: ExperimentComparisonResult? {
        ExperimentComparisonEngine.compare(comparisonDays)
    }

    private func resultSentence(_ comparison: ExperimentComparisonResult) -> String {
        let unit = outcomeMetric?.unit.map { " \($0)" } ?? ""
        let name = (outcomeMetric?.name ?? "your outcome").lowercased()
        let with = String(format: "%.1f", comparison.interventionMean)
        let without = String(format: "%.1f", comparison.nonInterventionMean)
        return "On days you did this, your \(name) averaged \(with)\(unit) across \(comparison.interventionCount) days, vs \(without)\(unit) across \(comparison.nonInterventionCount) days you didn't."
    }

    // MARK: - Data

    private func load() async {
        #if DEBUG
        if DebugLaunch.has("--goals-preview") || DebugLaunch.has("--progress-preview") {
            comparisonDays = Self.previewDays(for: experiment)
            isLoading = false
            return
        }
        #endif
        isLoading = true
        defer { isLoading = false }

        let bundle = await loadGoalBundle()
        goalBundle = bundle

        guard let outcome = experiment.primaryOutcomeMeasurement,
              let observations = try? await experimentRepository.fetchOutcomeObservations(measurementId: outcome.measurementId)
        else {
            comparisonDays = []
            return
        }

        let outcomeByDate = Dictionary(
            observations.compactMap { observation -> (String, Double)? in
                guard let number = observation.number else { return nil }
                return (observation.localDate, number)
            },
            uniquingKeysWith: { first, _ in first }
        )

        let interventionByDate: [String: Bool]
        if let bundle, let measurementId = bundle.primaryMeasurement?.id {
            interventionByDate = ExperimentInterventionDays.build(
                checkins: bundle.checkins, observations: bundle.observations, measurementId: measurementId
            )
        } else {
            interventionByDate = [:]
        }

        comparisonDays = ExperimentComparisonEngine.days(
            outcomeByDate: outcomeByDate, interventionByDate: interventionByDate
        )
    }

    private func loadGoalBundle() async -> PersonalGoalBundle? {
        if let active = try? await goalRepository.fetchActiveGoals(),
           let match = active.first(where: { $0.id == experiment.interventionGoalId }) {
            return match
        }
        guard let completed = try? await goalRepository.fetchCompletedGoals() else { return nil }
        return completed.first(where: { $0.id == experiment.interventionGoalId })
    }

    private func checkIn(_ value: Bool) {
        guard let bundle = goalBundle, !isSaving else { return }
        isSaving = true
        Task {
            do {
                try await goalRepository.recordBoolean(value, for: bundle)
                await load()
                await onUpdated()
            } catch {
                errorMessage = "Your check-in couldn’t be saved yet."
            }
            isSaving = false
        }
    }
}

private struct DetailCheckInButtonStyle: ButtonStyle {
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

#if DEBUG
extension ExperimentDetailView {

    /// Sample days for the preview: alternating intervention days, the outcome a little higher
    /// on them for the finished experiment (a readable result) and flat for the running one.
    fileprivate static func previewDays(for experiment: PersonalExperiment) -> [ExperimentDayObservation] {
        let calendar = Calendar.current
        let finished = experiment.status == .completed
        let count = finished ? 21 : 6
        let end = finished ? (calendar.date(byAdding: .day, value: -14, to: .now) ?? .now) : .now
        return (0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: end) ?? end
            let didIntervene = offset % 3 != 0
            let base = finished ? 3.0 : 7.1
            let lift = finished && didIntervene ? 0.9 : 0
            let wobble = Double((offset * 7) % 5) * 0.1 - 0.2
            return ExperimentDayObservation(localDate: date.isoDateString, didIntervene: didIntervene,
                                            outcomeValue: base + lift + wobble)
        }
    }
}
#endif
