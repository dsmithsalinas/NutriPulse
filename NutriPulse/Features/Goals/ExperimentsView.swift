import SwiftUI

struct ExperimentsView: View {
    @Environment(\.dismiss) private var dismiss
    let activeGoals: [GoalCardState]
    @State private var experiments: [PersonalExperiment] = []
    @State private var showCreate = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.Colors.primary)
                    Text("Test a question, not a diagnosis")
                        .font(Theme.Typography.title)
                    Text("An experiment connects one intervention goal to outcomes such as sleep duration or morning energy. Pulse can compare what happened while keeping missing data and possible confounders visible.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                    } else if experiments.isEmpty {
                        experimentPrimer
                    } else {
                        ForEach(experiments) { experiment in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(experiment.question)
                                        .font(Theme.Typography.headline)
                                    Spacer()
                                    Text(experiment.status.rawValue.capitalized)
                                        .font(Theme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(Theme.Colors.primary)
                                }
                                Text("\(experiment.interventionStart) through \(experiment.endDate ?? "ongoing")")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .padding(16)
                            .card()
                        }
                    }

                    Text("Experiment setup and conclusions use descriptive associations only. They do not establish causation or provide medical advice.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(20)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .navigationTitle("Personal Experiments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreate = true } label: { Image(systemName: "plus") }
                        .disabled(activeGoals.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showCreate) {
                CreateExperimentView(activeGoals: activeGoals) {
                    await load()
                }
            }
            .alert("Couldn’t update experiments", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Try Again") { Task { await load() } }
                Button("Not Now", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private var experimentPrimer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Intervention", systemImage: "target")
                .font(Theme.Typography.headline)
            Text(activeGoals.first?.bundle.version.title ?? "Create an active goal first")
                .font(Theme.Typography.body)
            Divider()
            Label("Possible outcomes", systemImage: "chart.xyaxis.line")
                .font(Theme.Typography.headline)
            Text("Sleep duration · morning energy · daily steps")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            Divider()
            Label("Confounders", systemImage: "exclamationmark.triangle")
                .font(Theme.Typography.headline)
            Text("Stress, illness, travel, alcohol, medication changes, and missing wearable data")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            Button("Create an experiment") { showCreate = true }
                .buttonStyle(.brandPrimary)
                .disabled(activeGoals.isEmpty)
        }
        .padding(16)
        .card()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            experiments = try await ExperimentRepository().fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = "Your experiments couldn’t be refreshed. Nothing was changed."
        }
    }
}

private struct CreateExperimentView: View {
    @Environment(\.dismiss) private var dismiss
    let activeGoals: [GoalCardState]
    let onCreated: () async -> Void
    @State private var selectedGoalId: UUID?
    @State private var selectedOutcomeId = ExperimentOutcomeTemplate.sleep.id
    @State private var question = ""
    @State private var duration = 21
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("Does this behavior affect my outcome?", text: $question, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Intervention goal") {
                    Picker("Goal", selection: $selectedGoalId) {
                        Text("Choose a goal").tag(Optional<UUID>.none)
                        ForEach(activeGoals) { state in
                            Text(state.bundle.version.title).tag(Optional(state.id))
                        }
                    }
                }
                Section("Primary outcome") {
                    Picker("Outcome", selection: $selectedOutcomeId) {
                        ForEach(ExperimentOutcomeTemplate.all) { outcome in
                            Text(outcome.name).tag(outcome.id)
                        }
                    }
                }
                Section("Duration") {
                    Picker("Days", selection: $duration) {
                        Text("14 days").tag(14)
                        Text("21 days").tag(21)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                }
                Section {
                    Text("Footing will report associations and possible confounders. It will not claim the intervention caused an outcome.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New experiment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Creating…" : "Create") { create() }
                        .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || selectedGoalId == nil || isSaving)
                }
            }
            .onAppear { selectedGoalId = selectedGoalId ?? activeGoals.first?.id }
            .alert("Couldn’t create experiment", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func create() {
        guard let selectedGoalId,
              let outcome = ExperimentOutcomeTemplate.all.first(where: { $0.id == selectedOutcomeId })
        else { return }
        isSaving = true
        Task {
            do {
                try await ExperimentRepository().create(
                    question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                    interventionGoalId: selectedGoalId,
                    outcome: outcome,
                    durationDays: duration
                )
                await onCreated()
                dismiss()
            } catch {
                isSaving = false
                errorMessage = "The experiment wasn’t saved. Check your connection and try again."
            }
        }
    }
}
