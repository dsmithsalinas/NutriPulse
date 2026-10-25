import SwiftUI
import Supabase

struct EverydayToolsView: View {
    let userId: UUID
    let onAskPulse: (String) -> Void
    var startWithExperiments = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var tab: Tool?
    @State private var showExperiments = false
    @State private var showLeftovers = false
    @State private var showMemories = false
    @State private var showDataInfo = false
    @State private var linkingExperiment: TinyExperiment?
    @State private var reflectingExperiment: TinyExperiment?
    @State private var token: UUID?
    @State private var error: String?
    @State private var action = ""
    @State private var outcome = ""
    @State private var tried = true
    @State private var rating = 3
    @State private var useHealth = false
    @State private var healthMetric = ExperimentHealthLink.Metric.walking
    @State private var walkStart = 12
    @State private var walkEnd = 16
    @State private var leftoverName = ""
    @State private var meal = Meal.lunch
    @State private var pendingLeftover = SavedLeftover(name: "", savedOn: Date.now.isoDateString, meal: .lunch)
    @State private var when = ""
    @State private var helped = ""
    @State private var proposedMemory: String?
    @State private var decision = OneDecision.food
    @State private var constraints = ""
    @State private var busy = false
    @State private var message: String?
    private var store: EverydayToolsStore { .shared }
    private var ownsScreen: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--everyday-tools-preview") || ProcessInfo.processInfo.arguments.contains("--pulse-health-preview") { return true }
        #endif
        return store.accountId == userId && store.generation == token && supabase.auth.currentSession?.user.id == userId
    }
    enum Tool: String, CaseIterable, Identifiable {
        case experiments, library, leftovers, decision
        var id: String { rawValue }
        var title: String {
            switch self {
            case .experiments: "Try a small change"
            case .library: "Remember what helps"
            case .leftovers: "Save leftovers"
            case .decision: "Get one idea"
            }
        }
        var detail: String {
            switch self {
            case .experiments: "See how one change feels"
            case .library: "Keep something useful for Pulse"
            case .leftovers: "Note food to come back to"
            case .decision: "Ask Pulse for a manageable option"
            }
        }
        var symbol: String {
            switch self {
            case .experiments: "figure.walk"
            case .library: "doc.text"
            case .leftovers: "fork.knife"
            case .decision: "lightbulb"
            }
        }
        var eyebrow: String {
            switch self {
            case .experiments: "Small experiment"
            case .library: "Pulse memory"
            case .leftovers: "Leftovers"
            case .decision: "Ask Pulse"
            }
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if tab != nil {
                    Button { tab = nil } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                            .background(Theme.Colors.surfaceCard, in: Circle())
                    }.accessibilityLabel("Back to tools").disabled(busy)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                        .background(Theme.Colors.surfaceCard, in: Circle())
                }.accessibilityLabel("Close").disabled(busy)
            }
            .font(.system(size: 18, weight: .semibold)).buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.page).padding(.top, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if ownsScreen {
                        switch tab {
                        case nil: chooser
                        case .experiments: experiments
                        case .library: library
                        case .leftovers: leftovers
                        case .decision: decisions
                        }
                        if let text = error ?? store.error {
                            Text(text).foregroundStyle(Theme.Colors.danger).accessibilityAddTraits(.updatesFrequently)
                        }
                        if store.error != nil {
                            Button("Retry opening saved tools") {
                                guard supabase.auth.currentSession?.user.id == userId else { return }
                                store.setAccount(nil); store.setAccount(userId); token = store.generation
                            }.frame(minHeight: 44)
                        }
                        if let message { note(message) }
                        if tab != nil { Divider() }
                        Button { showDataInfo = true } label: {
                            Label("About saved data", systemImage: "info.circle")
                                .font(Theme.Fonts.body(13)).frame(minHeight: 44)
                        }.frame(maxWidth: .infinity)
                    } else {
                        Text("Your account changed. Close this screen and reopen it to continue.")
                    }
                }.font(Theme.Fonts.body(16)).padding(Theme.Spacing.page)
            }.scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.Colors.ground).foregroundStyle(Theme.Colors.textPrimary).tint(Theme.Colors.primary)
        .interactiveDismissDisabled(busy)
            .onAppear {
                if startWithExperiments { tab = .experiments }
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--everyday-tools-preview") {
                    store.preview(empty: !ProcessInfo.processInfo.arguments.contains("--tools-saved"))
                    PulseMemoryStore.shared.preview()
                    PulseProfileStore.shared.setForPreview(preferences: .init(), enabled: true)
                    let args = ProcessInfo.processInfo.arguments
                    if args.contains("--tools-experiment") { tab = .experiments }
                    if args.contains("--tools-library") { tab = .library; when = "Travel mornings"; helped = "A familiar cold breakfast made eating easier" }
                    if args.contains("--tools-leftovers") { tab = .leftovers }
                    if args.contains("--tools-decision") { tab = .decision }
                }
                #endif
                token = store.generation; constraints = store.data.constraints[decision.rawValue] ?? ""
                if let today = store.data.experiments.first?.observations.first(where: { $0.day == Date.now.isoDateString }) {
                    tried = today.tried; rating = today.rating ?? 3
                }
            }
            .onChange(of: walkStart) { _, start in walkEnd = max(walkEnd, start + 1) }
            .onChange(of: tab) { _, _ in error = nil; message = nil }
            .onChange(of: store.accountId) { _, _ in
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--everyday-tools-preview") { return }
                #endif
                useHealth = false; healthMetric = .walking; walkStart = 12; walkEnd = 16
                action = ""; outcome = ""; when = ""; helped = ""; leftoverName = ""; constraints = ""
                tab = nil; proposedMemory = nil; linkingExperiment = nil; reflectingExperiment = nil; showMemories = false; showDataInfo = false
            }
            .sheet(item: $reflectingExperiment) { experiment in
                ExperimentWrapUpView(experiment: experiment, owner: userId,
                    preview: ProcessInfo.processInfo.arguments.contains("--everyday-tools-preview") || ProcessInfo.processInfo.arguments.contains("--pulse-health-preview"))
            }
            .sheet(item: $linkingExperiment) { experiment in
                ExperimentHealthLinkEditor(sleepOutcome: experiment.healthOutcome == true) { link in
                    if mutate({ data in
                        guard let index = data.experiments.firstIndex(where: { $0.id == experiment.id }) else { return }
                        data.experiments[index].healthLink = link
                    }) { linkingExperiment = nil }
                }
            }
            .sheet(isPresented: $showMemories) {
                ScrollView {
                    VStack(spacing: 20) {
                        SheetHeader(title: "Saved memories", onClose: { showMemories = false })
                        PulseMemoriesSection()
                    }.padding(Theme.Spacing.page)
                }.background(Theme.Colors.ground)
            }
            .sheet(isPresented: $showDataInfo) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SheetHeader(title: "About saved data", onClose: { showDataInfo = false })
                        Text("Experiments, leftovers reminders and decision drafts stay on this phone. Notes and approved memories sync with your account.")
                        Text("Examples only fill an editable draft. They don’t start an experiment, save a memory or send anything to Pulse.")
                        Text("Leftovers add a meal note and a reminder in this app. They don’t schedule a notification or estimate nutrition. Removing a reminder leaves the day notes intact; edit or delete those on Today.")
                        Text("You review and approve memories separately. You can edit or forget them later. Forgetting a memory doesn’t erase past conversations.")
                    }.font(Theme.Fonts.body(16)).padding(Theme.Spacing.page)
                }.background(Theme.Colors.ground)
            }
            .sheet(isPresented: Binding(get: { proposedMemory != nil }, set: { if !$0 { proposedMemory = nil } })) {
                if let proposedMemory { PulseMemoryEditor(proposed: proposedMemory, expectedOwner: userId) }
            }
    }

    private var experiments: some View {
        VStack(alignment: .leading, spacing: 14) {
            TileEyebrow("Small experiment")
            title(hasActiveExperiment ? "Your small experiment." : "Start with a small idea.",
                  hasActiveExperiment ? "Notice how it feels. You can skip any day." : "Pick an example or write your own.")
            if !hasActiveExperiment && store.data.experiments.count < 20 {
                Text("Examples to adapt").font(Theme.Fonts.body(14, .semibold))
                exampleChoices(["After-lunch walk", "Familiar breakfast", "Wind-down"], selected: experimentExample) { selected in
                    switch selected {
                    case "After-lunch walk": action = "A short walk after lunch"; outcome = "Afternoon energy"
                    case "Familiar breakfast": action = "A familiar breakfast"; outcome = "How manageable my morning feels"
                    default: action = "A screen-free wind-down"; outcome = "How rested I feel"; healthMetric = .sleep
                    }
                }
                VStack(alignment: .leading, spacing: 18) {
                    entry("Try", placeholder: "e.g. A short walk after lunch", text: $action, limit: 150)
                    if useHealth && healthMetric == .sleep {
                        Text("Notice: Following-night sleep (hours)").font(Theme.Fonts.body(14, .semibold))
                    } else {
                        entry("Notice", placeholder: "e.g. Afternoon energy", text: $outcome, limit: 80)
                    }
                    if experimentExample != nil { note("Example selected. Edit either field before starting.") }
                    else { note("Choose one small change and one thing to notice.") }
                    Toggle("Use Apple Health observations", isOn: $useHealth)
                    if useHealth {
                        Picker("Observe", selection: $healthMetric) {
                            Text("Walking in a time window").tag(ExperimentHealthLink.Metric.walking)
                            Text("Sleep after each day").tag(ExperimentHealthLink.Metric.sleep)
                        }
                        if healthMetric == .walking {
                            Stepper("From \(walkStart):00", value: $walkStart, in: 0...23)
                            Stepper("Until \(walkEnd):00", value: $walkEnd, in: (walkStart + 1)...24)
                        }
                        note("Uses available Health data on this phone. Walking is a recorded workout, not proof you tried your experiment. Sleep belongs to the following night. You can unlink this later.")
                    }
                    primary("Start experiment", disabled: !valid(action, limit: 150) || (!(useHealth && healthMetric == .sleep) && !valid(outcome, limit: 80)) || store.error != nil) {
                        if mutate({ $0.experiments.append(TinyExperiment(action: action.trimmingCharacters(in: .whitespacesAndNewlines), outcome: useHealth && healthMetric == .sleep ? "Following-night sleep" : outcome.trimmingCharacters(in: .whitespacesAndNewlines), startedOn: Date.now.isoDateString, healthOutcome: useHealth && healthMetric == .sleep, healthLink: useHealth ? ExperimentHealthLink(metric: healthMetric, startHour: walkStart, endHour: max(walkEnd, walkStart + 1)) : nil)) }) {
                            showExperiments = true
                        }
                    }
                    note("You can skip any day.")
                }.padding(16).background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 22))
                Button("Write my own") { action = ""; outcome = "" }.frame(minHeight: 44)
            } else if !hasActiveExperiment {
                note("You have 20 saved experiments. Remove one below to make room for another.")
            }
            Button(showExperiments ? "Hide experiments" : "View experiments") { showExperiments.toggle() }
                .font(Theme.Fonts.body(14, .semibold)).frame(minHeight: 44)
            if showExperiments || hasActiveExperiment {
            if store.data.experiments.isEmpty { note("Your experiments will appear here after you start one.") }
            ForEach(store.data.experiments) { experiment in
                VStack(alignment: .leading, spacing: 12) {
                    Text(experiment.action).font(Theme.Fonts.body(18, .semibold))
                    Text("Noticing: \(experiment.outcome) · Started \(experiment.startedOn)")
                    if experiment.healthLink == nil { Text(experiment.summary).foregroundStyle(Theme.Colors.textSecondary) }
                    if let completedOn = experiment.completedOn {
                        Text("Finished \(completedOn)").foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if experiment.readyToReflect {
                        Button("Reflect on this experiment") { reflectingExperiment = experiment }.frame(minHeight: 44)
                    }
                    if experiment.healthLink == nil && experiment.completedOn == nil {
                        Button("Add Apple Health observations") { linkingExperiment = experiment }.frame(minHeight: 44)
                    }
                    if experiment.healthLink != nil {
                        ExperimentHealthCard(experiment: experiment, owner: userId)
                        Button("Unlink Apple Health") {
                            mutate { data in
                                guard let index = data.experiments.firstIndex(where: { $0.id == experiment.id }) else { return }
                                data.experiments[index].healthLink = nil
                            }
                        }.frame(minHeight: 44)
                    }
                    if !experiment.paused && experiment.completedOn == nil {
                        ExperimentObservationEditor(experiment: experiment) { observation in
                            mutate { data in
                                guard let index = data.experiments.firstIndex(where: { $0.id == experiment.id }) else { return }
                                data.experiments[index].observations.removeAll { $0.day == observation.day }
                                data.experiments[index].observations.append(observation)
                            }
                        }
                    }
                    ForEach(experiment.observations.sorted { $0.day > $1.day }, id: \.day) { observation in
                        HStack {
                            Text("\(observation.day) · \(observation.tried ? "Tried" : "Not tried")" + (observation.rating.map { " · \($0)/5" } ?? ""))
                            Spacer()
                            Button("Remove", role: .destructive) {
                                mutate { data in
                                    guard let index = data.experiments.firstIndex(where: { $0.id == experiment.id }) else { return }
                                    data.experiments[index].observations.removeAll { $0.day == observation.day }
                                }
                            }.frame(minHeight: 44)
                        }.font(Theme.Fonts.body(13))
                    }
                    Button("Reflect with Pulse") {
                        guard ownsScreen, PulseProfileStore.shared.pulseEnabled else { return }
                        onAskPulse("Reflect briefly on my small experiment. I tried: \(experiment.action). I noticed: \(experiment.outcome). Here is the descriptive comparison: \(experiment.summary). Missing days are unknown. Do not claim causation, recommend medication changes, or save a lasting memory. Respect clinical boundaries. Give one useful reflection without asking me to catch up.")
                        dismiss()
                    }.frame(minHeight: 44).disabled(!PulseProfileStore.shared.pulseEnabled)
                    if experiment.completedOn == nil {
                    Button(experiment.paused ? "Resume" : "Pause") {
                        mutate { data in
                            guard let index = data.experiments.firstIndex(where: { $0.id == experiment.id }) else { return }
                            data.experiments[index].paused.toggle()
                        }
                    }.frame(minHeight: 44)
                    Button("Finish experiment") {
                        mutate { data in
                            guard let index = data.experiments.firstIndex(where: { $0.id == experiment.id }) else { return }
                            data.experiments[index].completedOn = Date.now.isoDateString
                        }
                    }.frame(minHeight: 44)
                    }
                    Button("Delete experiment", role: .destructive) { mutate { $0.experiments.removeAll { $0.id == experiment.id } } }.frame(minHeight: 44)
                }.tile()
            }
            }
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 16) {
            TileEyebrow("Pulse memory")
            title("What works for you?", "Keep something useful for Pulse to remember.")
            Text("Examples of situations").font(Theme.Fonts.body(14, .semibold))
            exampleChoices(["Busy mornings", "Travel days", "Low-energy days"], selected: when) { when = $0 }
            VStack(alignment: .leading, spacing: 18) {
                entry("When", placeholder: "e.g. Busy mornings", text: $when, limit: 80)
                entry("What helped?", placeholder: "e.g. A ready-to-eat breakfast", text: $helped, limit: 180)
                if !valid(when, limit: 80) || !valid(helped, limit: 180) { note("Add when this helps and what helped to continue.") }
                primary("Review memory", disabled: !valid(when, limit: 80) || !valid(helped, limit: 180)) {
                    proposedMemory = "When \(when.trimmingCharacters(in: .whitespacesAndNewlines)), what helped me was: \(helped.trimmingCharacters(in: .whitespacesAndNewlines))."
                }
                note("Review and approve the exact wording next.")
            }.padding(16).background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 22))
            Button("View saved memories") { showMemories = true }
                .font(Theme.Fonts.body(14, .semibold)).frame(minHeight: 44)
        }
    }

    private var leftovers: some View {
        VStack(alignment: .leading, spacing: 14) {
            TileEyebrow("Leftovers")
            title("Save a little for later.", "A note is enough. No portions to calculate.")
            Text("Examples").font(Theme.Fonts.body(14, .semibold))
            exampleChoices(["Half a wrap", "Soup", "Write my own"], selected: leftoverExample) { choice in
                leftoverName = choice == "Half a wrap" ? "Half a chicken wrap" : choice == "Soup" ? "Soup" : ""
            }
            VStack(alignment: .leading, spacing: 18) {
                entry("Food saved", placeholder: "e.g. Half a chicken wrap", text: $leftoverName, limit: 120)
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meal").font(Theme.Fonts.body(14, .semibold))
                        mealPicker.fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    HStack {
                        Text("Meal").font(Theme.Fonts.body(14, .semibold))
                        Spacer()
                        mealPicker
                    }
                }
                if !valid(leftoverName, limit: 120) { note("Name the food to save it.") }
                if store.data.leftovers.count >= 30 { note("You have 30 saved leftovers. Remove a reminder below to make room.") }
                primary(busy ? "Saving…" : "Save leftovers", disabled: !valid(leftoverName, limit: 120) || busy || store.data.leftovers.count >= 30 || store.error != nil) { saveLeftover() }
                note("Adds a meal note and a reminder here. No calories or macros.")
                note("Reminder on this phone · Meal note syncs")
            }.padding(16).background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 22))
            Button(showLeftovers ? "Hide saved leftovers" : "View saved leftovers") { showLeftovers.toggle() }
                .font(Theme.Fonts.body(14, .semibold)).frame(minHeight: 44)
            if showLeftovers {
            if store.data.leftovers.isEmpty { note("Food you save for later will appear here.") }
            ForEach(store.data.leftovers.sorted { $0.savedOn > $1.savedOn }) { item in
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.name).font(Theme.Fonts.body(18, .semibold))
                    Text(item.finishedOn.map { "Finished \($0) · Portions unknown" } ?? "Saved \(item.savedOn) · Portions unknown")
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if item.initialNoteSaved != true {
                        Text("Reminder saved · Meal note needs saving").font(Theme.Fonts.body(13))
                        Button("Retry saving meal note") { queueInitialNote(item) }.frame(minHeight: 44).disabled(busy)
                    } else if item.finishedOn == nil {
                        Button(item.finishRequestedOn == nil ? "Finished the rest" : "Retry saving finished") { finish(item) }.frame(minHeight: 44).disabled(busy)
                    } else {
                        Button("Undo finished") { undoFinish(item) }.frame(minHeight: 44).disabled(busy)
                    }
                    Button("Remove reminder", role: .destructive) { mutate { $0.leftovers.removeAll { $0.id == item.id } } }.frame(minHeight: 44).disabled(busy)
                }.tile()
            }
            Text("Removing a reminder leaves its day notes intact. You can edit or delete those on Today.").font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var decisions: some View {
        VStack(alignment: .leading, spacing: 16) {
            TileEyebrow("Ask Pulse")
            title("Let Pulse narrow it down.", "Choose an example, then add your details.")
            Text("Help with").font(Theme.Fonts.body(14, .semibold))
            exampleChoices(["Food", "Movement", "Groceries"], selected: decisionLabel) { choice in
                decision = choice == "Food" ? .food : choice == "Movement" ? .movement : .groceries
                constraints = store.data.constraints[decision.rawValue] ?? ""
            }
            Text("Example situations").font(Theme.Fonts.body(14, .semibold))
            exampleChoices(["Short on time", "Nothing sounds good", "Low energy"], selected: selectedSituation) { choice in
                switch choice {
                case "Short on time": constraints = "I have ten minutes. Help me choose something manageable with the time I have."
                case "Nothing sounds good": constraints = "Nothing sounds good right now. Help me find one manageable option."
                default: constraints = "My energy is low today. Help me find one easy option."
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                entry("Your situation", placeholder: "e.g. I have ten minutes and a grocery store nearby.", text: $constraints, limit: 1000, lines: 3...7)
                if !valid(constraints, limit: 1000) { note("Add a few details to continue.") }
                if !PulseProfileStore.shared.pulseEnabled { note("Turn on Pulse in Profile to ask for an idea.") }
                primary("Ask Pulse for one idea", disabled: !valid(constraints, limit: 1000) || !PulseProfileStore.shared.pulseEnabled || store.error != nil) { ask(alternative: false) }
                note("Sent to Pulse when you ask. No memory or diary entry is created.")
            }.padding(16).background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 22))
            if store.data.constraints[decision.rawValue] != nil {
                Button("Clear saved draft") {
                    if mutate({ $0.constraints.removeValue(forKey: decision.rawValue) }) {
                        constraints = ""; message = "Draft cleared. Your food and activity logs are unchanged."
                    }
                }.frame(minHeight: 44)
            }
        }
    }

    private var mealPicker: some View {
        Picker("Meal", selection: $meal) {
            ForEach(Meal.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }.labelsHidden().accessibilityLabel("Meal")
    }
    private var chooser: some View {
        VStack(alignment: .leading, spacing: 18) {
            TileEyebrow("Make today easier")
            title("What would help right now?", "Choose one and take a small step.")
            ForEach(Tool.allCases) { tool in
                Button { tab = tool } label: {
                    HStack(spacing: 14) {
                        Image(systemName: tool.symbol).font(.system(size: 24))
                            .foregroundStyle(Theme.Colors.primary).frame(width: 52, height: 52)
                            .background(Theme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(tool.title).font(Theme.Fonts.body(17, .bold))
                            Text(tool.detail).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 22))
                }.buttonStyle(.plain)
            }
        }
    }
    private var hasActiveExperiment: Bool { store.data.experiments.contains { $0.completedOn == nil } }
    private var experimentExample: String? {
        if action == "A short walk after lunch" && outcome == "Afternoon energy" { return "After-lunch walk" }
        if action == "A familiar breakfast" && outcome == "How manageable my morning feels" { return "Familiar breakfast" }
        if action == "A screen-free wind-down" && outcome == "How rested I feel" { return "Wind-down" }
        return nil
    }
    private var leftoverExample: String? {
        leftoverName == "Half a chicken wrap" ? "Half a wrap" : leftoverName == "Soup" ? "Soup" : nil
    }
    private var decisionLabel: String { decision == .food ? "Food" : decision == .movement ? "Movement" : "Groceries" }
    private var selectedSituation: String? {
        if constraints == "I have ten minutes. Help me choose something manageable with the time I have." { return "Short on time" }
        if constraints == "Nothing sounds good right now. Help me find one manageable option." { return "Nothing sounds good" }
        if constraints == "My energy is low today. Help me find one easy option." { return "Low energy" }
        return nil
    }
    private func note(_ text: String) -> some View {
        Text(text).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func entry(_ label: String, placeholder: String, text: Binding<String>, limit: Int, lines: ClosedRange<Int> = 1...4) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(Theme.Fonts.body(14, .semibold))
            TextField(placeholder, text: text, axis: .vertical).lineLimit(lines)
                .font(Theme.Fonts.body(16)).padding(12)
                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(label)
            if text.wrappedValue.unicodeScalars.count > limit {
                Text("Keep this to \(limit) characters or fewer.").font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.danger)
            }
        }
    }
    private func primary(_ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center).padding(.vertical, 8)
        }.buttonStyle(.brandPrimary).disabled(disabled)
    }
    private func exampleChoices(_ labels: [String], selected: String?, action: @escaping (String) -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { ForEach(labels, id: \.self) { exampleChip($0, selected: selected == $0, action: action) } }
            VStack(spacing: 8) { ForEach(labels, id: \.self) { exampleChip($0, selected: selected == $0, action: action) } }
        }
    }
    private func exampleChip(_ label: String, selected: Bool, action: @escaping (String) -> Void) -> some View {
        Button { action(label) } label: {
            Text(label).font(Theme.Fonts.body(14, .semibold))
                .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
                .padding(.horizontal, 10).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? Theme.Colors.limeInk : Theme.Colors.textPrimary)
                .background(selected ? Theme.Colors.lime : Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
    private func title(_ heading: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading).font(Theme.Fonts.display(29, .extraBold, relativeTo: .title)).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(detail).foregroundStyle(Theme.Colors.textSecondary)
        }
    }
    private func valid(_ value: String, limit: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.unicodeScalars.count <= limit
    }
    @discardableResult private func mutate(_ change: (inout EverydayToolData) -> Void) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--everyday-tools-preview") || ProcessInfo.processInfo.arguments.contains("--pulse-health-preview") { return false }
        #endif
        guard ownsScreen, let token else { error = "Your account changed. Close this screen and try again."; return false }
        do { try store.update(owner: userId, generation: token, change); error = nil; return true }
        catch { self.error = "Couldn’t save on this phone. Please try again."; return false }
    }
    private func saveLeftover() {
        guard ownsScreen else { return }
        pendingLeftover.name = leftoverName.trimmingCharacters(in: .whitespacesAndNewlines); pendingLeftover.meal = meal
        let item = pendingLeftover
        guard mutate({ data in data.leftovers.removeAll { $0.id == item.id }; data.leftovers.append(item) }) else { return }
        showLeftovers = true
        leftoverName = ""; pendingLeftover = SavedLeftover(name: "", savedOn: Date.now.isoDateString, meal: meal)
        queueInitialNote(item)
    }
    private func queueInitialNote(_ item: SavedLeftover) {
        guard ownsScreen, let token else { return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                try await store.saveInitialLeftoverNote(id: item.id, owner: userId, generation: token) {
                    try await MealNoteRepository().save($0)
                }
                message = "Saved with a qualitative meal note. No nutrients were estimated."
            } catch { self.error = "Reminder saved. The meal note couldn’t be saved yet; use Retry saving meal note." }
        }
    }
    private func finish(_ item: SavedLeftover) {
        guard ownsScreen, let token else { return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                try await store.finishLeftover(id: item.id, owner: userId, generation: token, on: Date.now.isoDateString) {
                    try await MealNoteRepository().save($0)
                }
            } catch { self.error = "Couldn’t save finished. Try again; it won’t create a duplicate note." }
        }
    }
    private func undoFinish(_ item: SavedLeftover) {
        guard ownsScreen, let day = item.finishedOn else { return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                try await MealNoteRepository().delete(MealNote(id: item.finishNoteId, userId: userId, logDate: day, meal: item.meal, body: item.finishBody))
                mutate { data in
                    guard let index = data.leftovers.firstIndex(where: { $0.id == item.id }) else { return }
                    data.leftovers[index].finishedOn = nil
                    data.leftovers[index].finishRequestedOn = nil
                }
            } catch { self.error = "Couldn’t undo finished. Please try again." }
        }
    }
    private func ask(alternative: Bool) {
        guard ownsScreen, PulseProfileStore.shared.pulseEnabled, let prompt = decision.prompt(constraints: constraints, alternative: alternative),
              mutate({ $0.constraints[decision.rawValue] = constraints }) else { return }
        onAskPulse(prompt); dismiss()
    }
}
