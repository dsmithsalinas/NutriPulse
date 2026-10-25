import SwiftUI
import Supabase

struct ExperimentWrapUpView: View {
    let experiment: TinyExperiment
    let owner: UUID
    var preview = false
    @Environment(\.dismiss) private var dismiss
    @State private var choice = ExperimentNextStep.keepTrying
    @State private var note = ""
    @State private var revisedAction = ""
    @State private var error: String?
    @State private var saved = false
    @State private var showRecipe = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: "A moment to reflect", onClose: { dismiss() })
                VStack(alignment: .leading, spacing: 12) {
                    TileEyebrow("Your small experiment", color: Theme.Colors.violetLabel)
                    Text(saved ? "Room for what comes next." : "What would you like to do next?").font(Theme.Fonts.display(27, .bold, relativeTo: .title))
                    Text(experiment.action).font(Theme.Fonts.body(16, .semibold))
                    Text("You recorded \(Set(experiment.observations.map(\.day)).count) days. What you noticed matters more than a verdict.")
                        .font(Theme.Fonts.body(14))
                }.padding(20).background(Theme.Colors.violet, in: RoundedRectangle(cornerRadius: Theme.Radius.tile))
                if saved {
                    Text(choice == .makeEasier ? "Your original experiment and observations are kept. The easier version starts fresh, with blank days unknown." : choice == .finish ? "Your observations and reflection are kept. You can leave this experiment here." : "Keep going at your own pace. We’ll leave this question until you’ve recorded six more days.")
                        .font(Theme.Fonts.body(16)).tile()
                    Button("Keep what helped for another day") { showRecipe = true }.buttonStyle(.brandPrimary)
                    Button("Done") { dismiss() }.frame(minHeight: 44)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(ExperimentNextStep.allCases) { value in
                            Button { choice = value } label: {
                                HStack { Text(value.title); Spacer(); Image(systemName: choice == value ? "checkmark.circle.fill" : "circle") }
                                    .font(Theme.Fonts.body(16, .semibold)).padding(12).frame(minHeight: 44)
                                    .background(choice == value ? Theme.Colors.lime : Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).accessibilityAddTraits(choice == value ? [.isSelected] : [])
                        }
                        Text("What did you notice? (Optional)").font(Theme.Fonts.body(14, .semibold))
                        TextField("e.g. Shorter walks felt more manageable", text: $note, axis: .vertical).lineLimit(2...5)
                            .padding(12).background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Experiment reflection")
                        if choice == .makeEasier {
                            TextField("A smaller change to try", text: $revisedAction, axis: .vertical).lineLimit(1...4)
                                .padding(12).background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Easier experiment")
                            Text("The easier version starts fresh. Your original observations stay with the original change. Health observation settings carry over; you can review or unlink them in Experiments.").font(Theme.Fonts.body(13))
                        }
                    }.tile()
                    if let error { Text(error).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.danger) }
                    Button("Save my next step", action: save).buttonStyle(.brandPrimary)
                        .disabled(note.unicodeScalars.count > 240 || (choice == .makeEasier && (revisedAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || revisedAction == experiment.action || revisedAction.unicodeScalars.count > 150)))
                    Text("No success or failure label. Your reflection stays on this phone unless you choose to approve a memory.")
                        .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                }
            }.padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground).tint(Theme.Colors.primary).scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showRecipe) { EasierDayRecipeView(owner: owner, preview: preview, support: note) }
        .onChange(of: EverydayToolsStore.shared.accountId) { _, account in if !preview && account != owner { dismiss() } }
    }
    private func save() {
        if preview { error = "Preview only — no experiment changed."; return }
        let store = EverydayToolsStore.shared
        guard store.accountId == owner, supabase.auth.currentSession?.user.id == owner else { return }
        do {
            let next = try ExperimentWrapUp.applying(id: experiment.id, choice: choice, note: note, revisedAction: revisedAction, day: Date.now.isoDateString, to: store.data)
            try store.update(owner: owner, generation: store.generation) { $0 = next }
            error = nil; saved = true
        } catch ExperimentWrapUp.Failure.capacity { error = "You have 20 saved experiments. Remove one in Experiments before starting an easier version. Your original is unchanged." }
        catch ExperimentWrapUp.Failure.invalid { error = "Keep your reflection under 240 characters and choose a different, smaller change of up to 150 characters." }
        catch { self.error = "Couldn’t save your next step. Please try again." }
    }
}
