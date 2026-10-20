import SwiftUI
import Supabase

struct EverydayToolsView: View {
    let userId: UUID
    let onAskPulse: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tab = Tool.experiments
    @State private var token: UUID?
    @State private var error: String?
    @State private var action = "A short walk after lunch"
    @State private var outcome = "Afternoon energy"
    @State private var tried = true
    @State private var rating = 3
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
        if ProcessInfo.processInfo.arguments.contains("--everyday-tools-preview") { return true }
        #endif
        return store.accountId == userId && store.generation == token && supabase.auth.currentSession?.user.id == userId
    }
    enum Tool: String, CaseIterable, Identifiable {
        case experiments = "Try", library = "Keep", leftovers = "Save", decision = "Decide"
        var id: String { rawValue }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SheetHeader(title: "Make today easier", onClose: { dismiss() })
                Picker("Tools", selection: $tab) {
                    ForEach(Tool.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                if ownsScreen {
                    switch tab {
                    case .experiments: experiments
                    case .library: library
                    case .leftovers: leftovers
                    case .decision: decisions
                    }
                    if let text = error ?? store.error { Text(text).foregroundStyle(Theme.Colors.danger) }
                    if store.error != nil {
                        Button("Retry opening saved tools") {
                            guard supabase.auth.currentSession?.user.id == userId else { return }
                            store.setAccount(nil); store.setAccount(userId); token = store.generation
                        }.frame(minHeight: 44)
                    }
                    if let message { Text(message).foregroundStyle(Theme.Colors.textSecondary) }
                } else {
                    Text("Your account changed. Close this screen and reopen it to continue.")
                }
            }.font(Theme.Fonts.body(16)).padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground).tint(Theme.Colors.primary)
            .scrollDismissesKeyboard(.interactively).interactiveDismissDisabled(busy)
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--everyday-tools-preview") {
                    store.preview()
                    PulseMemoryStore.shared.preview()
                    PulseProfileStore.shared.setForPreview(preferences: .init(), enabled: true)
                    let args = ProcessInfo.processInfo.arguments
                    if args.contains("--tools-library") { tab = .library; when = "Travel mornings"; helped = "A familiar cold breakfast made eating easier" }
                    if args.contains("--tools-leftovers") { tab = .leftovers }
                    if args.contains("--tools-decision") { tab = .decision }
                }
                #endif
                token = store.generation; constraints = store.data.constraints[decision.rawValue] ?? ""
                if let today = store.data.experiments.first?.observations.first(where: { $0.day == Date.now.isoDateString }) {
                    tried = today.tried; rating = today.rating
                }
            }
            .onChange(of: tab) { _, _ in error = nil; message = nil }
            .sheet(isPresented: Binding(get: { proposedMemory != nil }, set: { if !$0 { proposedMemory = nil } })) {
                if let proposedMemory { PulseMemoryEditor(proposed: proposedMemory, expectedOwner: userId) }
            }
    }

    private var experiments: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("What actually helps me?", "Try one small change and notice how you feel. No goal or daily streak required.")
            if !store.data.experiments.contains(where: { $0.completedOn == nil }) && store.data.experiments.count < 20 {
                TextField("Something to try", text: $action, axis: .vertical).textFieldStyle(.roundedBorder)
                TextField("What to notice", text: $outcome).textFieldStyle(.roundedBorder)
                Text("Try one small change at a time, such as a familiar breakfast or screen-free wind-down. Leave days blank whenever you need to.")
                    .foregroundStyle(Theme.Colors.textSecondary)
                Button("Start a small experiment") {
                    mutate { $0.experiments.append(TinyExperiment(action: action.trimmingCharacters(in: .whitespacesAndNewlines), outcome: outcome.trimmingCharacters(in: .whitespacesAndNewlines), startedOn: Date.now.isoDateString)) }
                }.buttonStyle(.brandPrimary).disabled(!valid(action, limit: 150) || !valid(outcome, limit: 80))
            }
            ForEach(store.data.experiments) { experiment in
                VStack(alignment: .leading, spacing: 12) {
                    Text(experiment.action).font(Theme.Fonts.body(18, .semibold))
                    Text("Noticing: \(experiment.outcome) · Started \(experiment.startedOn)")
                    Text(experiment.summary).foregroundStyle(Theme.Colors.textSecondary)
                    if let completedOn = experiment.completedOn {
                        Text("Finished \(completedOn)").foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if !experiment.paused && experiment.completedOn == nil {
                        Picker("Today", selection: $tried) {
                            Text("Tried it").tag(true); Text("Didn’t try it").tag(false)
                        }.pickerStyle(.segmented)
                        Stepper("\(experiment.outcome): \(rating)/5", value: $rating, in: 1...5)
                        Text("1 = very low · 5 = very high. Only record what you remember. Skipping leaves today unknown.")
                            .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                        Button(experiment.observations.contains { $0.day == Date.now.isoDateString } ? "Update today’s observation" : "Save today’s observation") {
                            mutate { data in
                                guard let index = data.experiments.firstIndex(where: { $0.id == experiment.id }) else { return }
                                data.experiments[index].observations.removeAll { $0.day == Date.now.isoDateString }
                                data.experiments[index].observations.append(.init(day: Date.now.isoDateString, tried: tried, rating: rating))
                            }
                        }.buttonStyle(.brandPrimary)
                    }
                    ForEach(experiment.observations.sorted { $0.day > $1.day }, id: \.day) { observation in
                        HStack {
                            Text("\(observation.day) · \(observation.tried ? "Tried" : "Not tried") · \(observation.rating)/5")
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
            deviceOnly
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("My works-for-me library", "Keep the situation and what helped together. Pulse can use approved entries when they’re relevant.")
            Text("When").font(Theme.Fonts.body(14, .semibold))
            TextField("Travel mornings, busy afternoons…", text: $when, axis: .vertical).textFieldStyle(.roundedBorder).accessibilityLabel("When this helped")
            Text("What helped").font(Theme.Fonts.body(14, .semibold))
            TextField("What helped me…", text: $helped, axis: .vertical).textFieldStyle(.roundedBorder).accessibilityLabel("What helped me")
            Button("Review before remembering") { proposedMemory = "When \(when.trimmingCharacters(in: .whitespacesAndNewlines)), what helped me was: \(helped.trimmingCharacters(in: .whitespacesAndNewlines))." }
                .buttonStyle(.brandPrimary)
                .disabled(!valid(when, limit: 80) || !valid(helped, limit: 180))
            Text("Keep what helped in that situation. You can change or forget it later.")
                .foregroundStyle(Theme.Colors.textSecondary)
            PulseMemoriesSection()
        }
    }

    private var leftovers: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("Save the rest", "Had some and saved the rest? Keep a simple reminder without guessing fractions or macros.")
            TextField("What did you save?", text: $leftoverName).textFieldStyle(.roundedBorder)
            Picker("Meal", selection: $meal) { ForEach(Meal.allCases, id: \.self) { Text($0.displayName).tag($0) } }
            Button("Had some · Saved the rest") { saveLeftover() }
                .buttonStyle(.brandPrimary).disabled(!valid(leftoverName, limit: 120) || busy || store.data.leftovers.count >= 30)
            Text("No portion estimates are added. If you already logged the full meal, you can edit that entry on Today.")
                .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
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
            deviceOnly
        }
    }

    private var decisions: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("One less decision", "Choose what to hand off. Pulse will offer one manageable option using your constraints.")
            Picker("Decision", selection: $decision) {
                ForEach(OneDecision.allCases) { Text($0.rawValue).tag($0) }
            }.onChange(of: decision) { _, value in constraints = store.data.constraints[value.rawValue] ?? "" }
            TextField("Time, budget, what’s available, and any limits…", text: $constraints, axis: .vertical)
                .lineLimit(3...7).textFieldStyle(.roundedBorder)
            Text("Your constraints are sent when you ask Pulse. Lasting memory still needs separate approval.")
                .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
            Button("Give me one option") { ask(alternative: false) }.buttonStyle(.brandPrimary)
                .disabled(!valid(constraints, limit: 1000) || !PulseProfileStore.shared.pulseEnabled)
            Button("Ask for a different option") { ask(alternative: true) }.frame(minHeight: 44)
                .disabled(!valid(constraints, limit: 1000) || !PulseProfileStore.shared.pulseEnabled)
            if !PulseProfileStore.shared.pulseEnabled { Text("Turn on Pulse in Profile to ask for an option.") }
            Button("Done with this decision") {
                mutate { $0.constraints.removeValue(forKey: decision.rawValue) }; constraints = ""
                message = "Cleared. Nothing was added to your food or activity logs."
            }.frame(minHeight: 44)
            deviceOnly
        }
    }

    private var deviceOnly: some View {
        Text("Experiments, leftovers reminders and decision drafts stay on this phone. Notes and approved memories sync with your account.")
            .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
    }
    private func title(_ heading: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading).font(Theme.Fonts.display(25, .bold, relativeTo: .title2))
            Text(detail).foregroundStyle(Theme.Colors.textSecondary)
        }
    }
    private func valid(_ value: String, limit: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.unicodeScalars.count <= limit
    }
    @discardableResult private func mutate(_ change: (inout EverydayToolData) -> Void) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--everyday-tools-preview") { return false }
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
