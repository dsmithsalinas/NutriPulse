import SwiftUI

// "Personal experiments" (docs/daylight-redesign.md): a sheet off Goals that connects one
// intervention goal to an outcome and tracks it over a fixed window. Daylight sheet chrome
// (SheetHeader, ground background) plus a Daylight settings-style Form for the create flow.
struct ExperimentsView: View {
    @Environment(\.dismiss) private var dismiss
    let activeGoals: [GoalCardState]
    @State private var experiments: [PersonalExperiment] = []
    @State private var showCreate = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                header

                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                        .frame(width: 52, height: 52)
                        .background(Theme.Colors.surfaceInset, in: Circle())
                    Text("Test a question, not a diagnosis")
                        .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("An experiment connects one intervention goal to outcomes such as sleep duration or morning energy. Pulse can compare what happened while keeping missing data and possible confounders visible.")
                        .font(Theme.Fonts.body(14))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .tile()

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                } else if experiments.isEmpty {
                    experimentPrimer
                } else {
                    VStack(spacing: Theme.Spacing.tileGap) {
                        ForEach(experiments) { experiment in
                            experimentRow(experiment)
                        }
                    }
                }

                Text("Experiment setup and conclusions use descriptive associations only. They do not establish causation or provide medical advice.")
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.page)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .presentationDragIndicator(.visible)
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

    private var header: some View {
        HStack {
            Text("Personal experiments")
                .font(Theme.Fonts.display(28, .extraBold, relativeTo: .title))
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { showCreate = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(activeGoals.isEmpty ? Theme.Colors.textFaint : Theme.Colors.primary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceCard, in: Circle())
            }
            .buttonStyle(.pressable)
            .disabled(activeGoals.isEmpty)
            .accessibilityLabel("Create an experiment")

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceCard, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Close")
        }
    }

    private func experimentRow(_ experiment: PersonalExperiment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(experiment.question)
                    .font(Theme.Fonts.body(15, .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer(minLength: 8)
                Text(experiment.status.rawValue.capitalized)
                    .font(Theme.Fonts.body(12, .bold))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Theme.Colors.primarySoft, in: Capsule())
            }
            Text("\(experiment.interventionStart) through \(experiment.endDate ?? "ongoing")")
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .tile()
    }

    private var experimentPrimer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Intervention", systemImage: "target")
                .font(Theme.Fonts.body(15, .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(activeGoals.first?.bundle.version.title ?? "Create an active goal first")
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.textPrimary)
            Divider().overlay(Theme.Colors.hairline)
            Label("Possible outcomes", systemImage: "chart.xyaxis.line")
                .font(Theme.Fonts.body(15, .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Sleep duration · morning energy · daily steps")
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.textSecondary)
            Divider().overlay(Theme.Colors.hairline)
            Label("Confounders", systemImage: "exclamationmark.triangle")
                .font(Theme.Fonts.body(15, .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Stress, illness, travel, alcohol, medication changes, and missing wearable data")
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.textSecondary)
            Button("Create an experiment") { showCreate = true }
                .buttonStyle(.brandPrimary)
                .disabled(activeGoals.isEmpty)
        }
        .tile()
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
                Section {
                    TextField("Does this behavior affect my outcome?", text: $question, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    DaylightSectionHeader("Question")
                }
                .daylightSection()

                Section {
                    Picker("Goal", selection: $selectedGoalId) {
                        Text("Choose a goal").tag(Optional<UUID>.none)
                        ForEach(activeGoals) { state in
                            Text(state.bundle.version.title).tag(Optional(state.id))
                        }
                    }
                } header: {
                    DaylightSectionHeader("Intervention goal")
                }
                .daylightSection()

                Section {
                    Picker("Outcome", selection: $selectedOutcomeId) {
                        ForEach(ExperimentOutcomeTemplate.all) { outcome in
                            Text(outcome.name).tag(outcome.id)
                        }
                    }
                } header: {
                    DaylightSectionHeader("Primary outcome")
                }
                .daylightSection()

                Section {
                    Picker("Days", selection: $duration) {
                        Text("14 days").tag(14)
                        Text("21 days").tag(21)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                } header: {
                    DaylightSectionHeader("Duration")
                } footer: {
                    DaylightSectionFooter("Footing will report associations and possible confounders. It will not claim the intervention caused an outcome.")
                }
                .daylightSection()
            }
            .daylightForm()
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
