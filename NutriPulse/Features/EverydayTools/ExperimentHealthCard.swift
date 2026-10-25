import SwiftUI
import Supabase

struct ExperimentHealthCard: View {
    let experiment: TinyExperiment
    let owner: UUID
    @State private var showDetail = false
    var body: some View {
        HealthSummaryCard(title: "Health observations", headline: "See what you’re noticing.",
            detail: experiment.healthLink?.metric == .sleep ? "Following-night sleep, alongside your experiment." : "Recorded walking, alongside your experiment.",
            symbol: experiment.healthLink?.metric == .sleep ? "moon" : "figure.walk", featured: true) { showDetail = true }
            .sheet(isPresented: $showDetail) { ExperimentHealthDetailView(experiment: experiment, owner: owner) }
    }
}

struct ExperimentHealthDetailView: View {
    let original: TinyExperiment
    let owner: UUID
    var onManage: (() -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var days: [ExperimentHealthDay] = []
    @State private var loading = false
    @State private var refresh = 0
    @State private var accessMessage: String?
    @State private var saveError: String?
    @State private var showWrapUp = false
    init(experiment: TinyExperiment, owner: UUID, onManage: (() -> Void)? = nil) {
        self.original = experiment; self.owner = owner; self.onManage = onManage
    }
    private var experiment: TinyExperiment {
        guard EverydayToolsStore.shared.accountId == owner else { return original }
        return EverydayToolsStore.shared.data.experiments.first { $0.id == original.id } ?? original
    }
    private var preview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--tools-health") || ProcessInfo.processInfo.arguments.contains("--pulse-health-preview")
        #else
        false
        #endif
    }
    private var ownsScreen: Bool { preview || (EverydayToolsStore.shared.accountId == owner && supabase.auth.currentSession?.user.id == owner) }
    private var isSleep: Bool { experiment.healthLink?.metric == .sleep }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: "Your small experiment", onClose: { dismiss() })
                if ownsScreen {
                    VStack(alignment: .leading, spacing: 12) {
                        TileEyebrow("One small change", color: Theme.Colors.violetLabel)
                        Text(experiment.action).font(Theme.Fonts.display(28, .extraBold, relativeTo: .title)).fixedSize(horizontal: false, vertical: true)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(String(days.count)).font(Theme.Fonts.number(52))
                            Text(isSleep ? "nights recorded" : "walking days recorded").font(Theme.Fonts.body(16, .semibold))
                        }
                        Text("Last 14 days · Blank days stay unknown").font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.violetLabel)
                    }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.violet, in: RoundedRectangle(cornerRadius: Theme.Radius.tile))
                    if loading { ProgressView("Reading available observations…").frame(maxWidth: .infinity) }
                    if !days.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            TileEyebrow(isSleep ? "Recorded sleep" : "Walking in your window")
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(Array(days.prefix(7).reversed())) { day in
                                    VStack(spacing: 7) {
                                        Text(day.value.formatted(.number.precision(.fractionLength(1)))).font(Theme.Fonts.number(12))
                                        RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.primary.opacity(0.8))
                                            .frame(height: max(4, 70 * day.value / max(days.map(\.value).max() ?? 1, 1)))
                                        Text(Date.fromISODateString(day.day)?.formatted(.dateTime.weekday(.narrow)) ?? "").font(Theme.Fonts.body(12))
                                    }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore)
                                        .accessibilityLabel("\(day.day): \(day.value.formatted()) \(isSleep ? "hours of following-night sleep" : "minutes walking")")
                                }
                            }
                            Text("\(isSleep ? "Hours of sleep after each experiment day" : "Minutes from recorded walking workouts") · Apple Health")
                                .font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
                        }.tile()
                    }
                    let metrics = ExperimentHealthEvidence.groupMetrics(experiment: experiment, days: days)
                    if !metrics.isEmpty {
                        TileEyebrow("What you’re noticing")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                            ForEach(metrics) { metric in HealthMetricTile(metric: metric, fill: metric.id == "tried" ? Theme.Colors.lime : Theme.Colors.surfaceCard) }
                        }
                        Text("An early snapshot of your recorded days.").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    } else if !loading {
                        Text(days.isEmpty ? "No matching observations yet. You can still share how it went; missing data stays unknown." : "Keep noticing at your own pace. A comparison needs three observed days in each confirmed group.")
                            .font(Theme.Fonts.body(15)).tile()
                    }
                    if experiment.readyToReflect {
                        VStack(alignment: .leading, spacing: 10) {
                            TileEyebrow("A quiet check-in")
                            Text("Keep trying, make it easier, or leave it here.").font(Theme.Fonts.display(21, .bold, relativeTo: .headline))
                            Button("Reflect on this experiment") { showWrapUp = true }.frame(minHeight: 44)
                        }.tile()
                    }
                    if let reflection = experiment.reflection {
                        VStack(alignment: .leading, spacing: 8) {
                            TileEyebrow("Your reflection")
                            Text(reflection.note.isEmpty ? "You chose: \(reflection.nextStep.title)." : reflection.note)
                            Text("Recorded \(reflection.reviewedOn)").font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
                        }.tile()
                    }
                    if !experiment.paused && experiment.completedOn == nil {
                        DisclosureGroup("Add how it went") {
                            ExperimentObservationEditor(experiment: experiment, save: save).padding(.top, 12)
                        }.padding(18).background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.tileSmall))
                    }
                    if let saveError { Text(saveError).foregroundStyle(Theme.Colors.danger) }
                    if let onManage { Button("Open Experiments", action: onManage).buttonStyle(.brandPrimary) }
                    DisclosureGroup("How Footing worked this out") {
                        VStack(alignment: .leading, spacing: 14) {
                            if let comparison = ExperimentHealthEvidence.comparison(experiment: experiment, days: days) { Text(comparison) }
                            Text("Only days you explicitly confirm as tried or not tried form the groups. Health observations never mark a day complete. Sleep follows the experiment day; walking uses your chosen window. These observations don’t establish cause. Source-conflicting or implausible sleep is excluded.")
                            Text("Computed on this phone. Health readings and comparisons aren’t sent to Pulse or saved as a memory.")
                            if let accessMessage { Text(accessMessage) }
                            Button("Refresh observations") { refresh += 1 }.frame(minHeight: 44)
                            Button("Choose Apple Health access") { Task { await chooseAccess() } }.frame(minHeight: 44)
                        }.font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary).padding(.top, 12)
                    }.padding(18).background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.tileSmall))
                }
            }.font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textPrimary).padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground).tint(Theme.Colors.primary)
        .task(id: refresh) {
            #if DEBUG
            if preview { days = HealthExperiencePreview.experimentDays(); return }
            #endif
            guard ownsScreen else { days = []; return }
            let generation = EverydayToolsStore.shared.generation
            loading = true
            let values = await HealthExperienceReader.experiment(experiment)
            guard !Task.isCancelled, ownsScreen, generation == EverydayToolsStore.shared.generation else { days = []; loading = false; return }
            days = values; loading = false
        }
        .sheet(isPresented: $showWrapUp) { ExperimentWrapUpView(experiment: experiment, owner: owner, preview: preview) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh += 1 } }
        .onChange(of: EverydayToolsStore.shared.accountId) { _, _ in if !preview { days = []; dismiss() } }
    }
    private func save(_ observation: TinyObservation) {
        guard ownsScreen, !preview else { return }
        do {
            try EverydayToolsStore.shared.update(owner: owner, generation: EverydayToolsStore.shared.generation) { data in
                guard let index = data.experiments.firstIndex(where: { $0.id == original.id }) else { return }
                data.experiments[index].observations.removeAll { $0.day == observation.day }
                data.experiments[index].observations.append(observation)
            }
            saveError = nil
        } catch { saveError = "Couldn’t save on this phone. Please try again." }
    }
    private func chooseAccess() async {
        guard ownsScreen, !preview else { return }
        do {
            let opened = try await HealthKitManager.shared.reconnect()
            guard ownsScreen else { return }
            accessMessage = opened ? "Your choices are saved in Apple Health." : "Manage Footing’s read choices in the Health app, then refresh here. Empty reads can mean missing data or unavailable access."
            refresh += 1
        } catch { if ownsScreen { accessMessage = "Couldn’t open Health access. Try again from Profile." } }
    }
}

struct ExperimentObservationEditor: View {
    let experiment: TinyExperiment
    let save: (TinyObservation) -> Void
    @State private var date = Date.now
    @State private var choice: Int = 0
    @State private var rating = 3
    private var range: ClosedRange<Date> {
        min(Date.now, Date.fromISODateString(experiment.startedOn) ?? Calendar.current.startOfDay(for: .now))...Date.now
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("Observation day", selection: $date, in: range, displayedComponents: .date)
            Picker("Did you try it?", selection: $choice) {
                Text("Unknown").tag(0); Text("Tried it").tag(1); Text("Didn’t try").tag(2)
            }.pickerStyle(.menu)
            if experiment.healthOutcome != true {
                Stepper("\(experiment.outcome): \(rating)/5", value: $rating, in: 1...5)
                Text("1 = very low · 5 = very high")
            } else {
                Text("Recorded sleep supplies the outcome while linked and available. Only confirm whether you tried the change that day.")
            }
            Button("Save observation") {
                save(.init(day: date.isoDateString, tried: choice == 1, rating: experiment.healthOutcome == true ? nil : rating))
            }.frame(minHeight: 44).disabled(choice == 0)
            Text("Skipping leaves this day unknown. You never need to catch up.")
                .font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
        }
        .task(id: date.isoDateString) {
            let existing = experiment.observations.first { $0.day == date.isoDateString }
            choice = existing.map { $0.tried ? 1 : 2 } ?? 0
            rating = existing?.rating ?? 3
        }
    }
}

struct ExperimentHealthLinkEditor: View {
    var sleepOutcome = false
    let save: (ExperimentHealthLink) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var metric = ExperimentHealthLink.Metric.walking
    @State private var start = 12
    @State private var end = 16
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: "Apple Health observations", onClose: { dismiss() })
                Text("Observe available data without marking any day complete. Your confirmed tried/not-tried days stay separate.")
                Picker("Observe", selection: $metric) {
                    if !sleepOutcome { Text("Walking in a time window").tag(ExperimentHealthLink.Metric.walking) }
                    Text("Sleep after each day").tag(ExperimentHealthLink.Metric.sleep)
                }
                if metric == .walking {
                    Stepper("From \(start):00", value: $start, in: 0...23)
                    Stepper("Until \(end):00", value: $end, in: (start + 1)...24)
                    Text("Only recorded walking workouts in this window are included. Steps alone don’t prove you took this walk.")
                } else {
                    Text("Sleep after an experiment day is paired with that day. Hours come from available Apple Health sleep data; you only confirm whether you tried the change.")
                }
                Text("Adding observations keeps your existing rating and entries. Sleep is an additional measure; it doesn’t replace the outcome you originally chose.")
                Text("Uses this phone’s Health data. Observations stay on-device and aren’t sent to Pulse. Unlink whenever you like; your own entries remain.")
                Button("Link these observations") { save(.init(metric: metric, startHour: start, endHour: max(end, start + 1))) }.buttonStyle(.brandPrimary)
            }.font(Theme.Fonts.body(15)).padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground)
        .onAppear { if sleepOutcome { metric = .sleep } }
        .onChange(of: start) { _, value in end = max(end, value + 1) }
    }
}
