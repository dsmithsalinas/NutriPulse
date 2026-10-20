import SwiftUI
import Supabase

struct OffScriptSheet: View {
    let userId: UUID
    let date: Date
    let onAskPulse: (String) -> Void
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: OffScriptAction?
    @State private var context = ""
    @State private var saving = false
    @State private var error: String?
    @State private var pending: MealNote?
    @State private var savedNote: MealNote?
    @State private var undo = FoodSaveUndo()
    private var pulseEnabled: Bool { PulseProfileStore.shared.pulseEnabled }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SheetHeader(title: "Today went sideways", onClose: { dismiss() })
                if let note = savedNote {
                    savedContent(note)
                } else {
                    Text("A sentence is enough.").font(Theme.Fonts.display(25, .bold, relativeTo: .title2))
                    Text("Get help with right now, or just leave a note. There’s no diary to finish first.")
                        .font(Theme.Fonts.body(16)).foregroundStyle(Theme.Colors.textSecondary)
                    choices
                    if let selected {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(selected.contextLabel).font(Theme.Fonts.body(16, .semibold))
                            TextField(selected == .remember ? "What happened today…" : "I’m at an airport, nothing sounds appealing, and I have ten minutes…", text: $context, axis: .vertical)
                                .lineLimit(3...7).font(Theme.Fonts.body(17)).padding(14)
                                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14))
                                .accessibilityLabel(selected.contextLabel)
                            Text("\(context.unicodeScalars.count)/1,000 characters")
                                .font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
                            if selected == .remember {
                                Text("Saved as a day note, with no calories or macros. Lasting Pulse memory still needs your separate approval.")
                                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                            } else if !pulseEnabled {
                                Text("Pulse is turned off. Turn it on in Profile for help, or choose the note option here.")
                                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                            }
                            Button(saving ? "Saving…" : selected == .remember ? "Save just this note" : "Ask Pulse") {
                                submit(selected)
                            }.buttonStyle(.brandPrimary)
                                .disabled(saving || MealNote.validBody(context) == nil || (selected != .remember && !pulseEnabled))
                        }
                    }
                }
                if let error = error ?? undo.error {
                    Text(error).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.danger)
                }
            }.padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground).tint(Theme.Colors.primary)
            .scrollDismissesKeyboard(.interactively).interactiveDismissDisabled(saving || undo.isUndoing)
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--off-script-note-preview") {
                    selected = .remember; context = "Travel took longer than expected. Kept things simple today."
                }
                #endif
            }
    }

    private var choices: some View {
        VStack(spacing: 8) {
            ForEach(OffScriptAction.allCases) { action in
                Button { selected = action; error = nil } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: action.symbol).frame(width: 23).foregroundStyle(Theme.Colors.primaryText)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(action.title).font(Theme.Fonts.body(16, .semibold))
                            Text(action.detail).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        if selected == action { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Colors.primaryText) }
                    }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding(12)
                        .background(selected == action ? Theme.Colors.primary.opacity(0.10) : Theme.Colors.surfaceInset,
                                    in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).disabled(saving)
                    .accessibilityAddTraits(selected == action ? .isSelected : [])
            }
        }
    }

    private func savedContent(_ note: MealNote) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Saved for today", systemImage: "checkmark.circle")
                .font(Theme.Fonts.display(24, .bold, relativeTo: .title2))
            Text(note.body).font(Theme.Fonts.body(17))
            Text(MealNoteStore.shared.isPending(note.id) ? "Saved on this phone · Waiting to sync" : "Day note saved")
                .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            Text("You can leave it here. Nothing to fill in later.")
                .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
            Button(undo.isUndoing ? "Undoing…" : "Undo") {
                Task {
                    if await undo.undo() { savedNote = nil; pending = nil; onSaved() }
                }
            }.font(Theme.Fonts.body(15, .semibold)).frame(minHeight: 44).disabled(undo.isUndoing)
            Button("Done") { dismiss() }.buttonStyle(.brandPrimary).disabled(undo.isUndoing)
        }
    }

    private func submit(_ action: OffScriptAction) {
        guard !saving, supabase.auth.currentSession?.user.id == userId else {
            error = "Your account changed. Close this sheet and try again."; return
        }
        if action != .remember {
            guard pulseEnabled, let prompt = action.prompt(context: context) else { return }
            onAskPulse(prompt)
            dismiss() // Today sends only after the sheet closes, so consent can present safely.
            return
        }
        guard let body = MealNote.validBody(context) else { return }
        saving = true; error = nil
        if pending == nil {
            // The legacy meal column stays populated for older clients; kind controls meaning.
            pending = MealNote(userId: userId, logDate: date.isoDateString, meal: .snack, body: body, kind: .dayContext)
        }
        pending?.body = body
        Task {
            defer { saving = false }
            do {
                guard let note = pending, supabase.auth.currentSession?.user.id == userId else { throw URLError(.userAuthenticationRequired) }
                try await MealNoteRepository().save(note)
                guard supabase.auth.currentSession?.user.id == userId else { throw URLError(.userAuthenticationRequired) }
                undo.record(note: note); savedNote = note; onSaved()
            } catch { self.error = "Couldn’t save your note on this phone. Your text is still here; please try again." }
        }
    }
}
