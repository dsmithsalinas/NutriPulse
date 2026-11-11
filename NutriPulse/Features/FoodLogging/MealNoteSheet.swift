import Supabase
import SwiftUI

struct MealNoteSheet: View {
    let date: Date
    let meal: Meal
    var existing: MealNote? = nil
    let onSaved: () -> Void
    @Environment(\.foodSaveUndo) private var undo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var editing: Bool
    @State private var bodyText = ""
    @State private var saving = false
    @State private var error: String?
    @State private var pending: MealNote?
    private var dayNote: Bool { existing?.isDayContext == true }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: editing ? 8 : Theme.Spacing.md) {
                SheetHeader(title: dayNote ? "Day note" : "Meal note", onClose: { dismiss() })
                ScrollView {
                    let expanded = !editing && geometry.size.width >= 650 && typeSize < .xxxLarge
                    let layout =
                        expanded
                        ? AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.tileGap))
                        : AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                    layout {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text(
                                dayNote
                                    ? "Keep the context. Skip the numbers." : "Remember the meal. Skip the numbers."
                            )
                            .font(Theme.Fonts.display(24, .bold, relativeTo: .title2))
                            Text(
                                dayNote
                                    ? date.formatted(date: .abbreviated, time: .omitted)
                                    : "\(meal.displayName) · \(date.formatted(date: .abbreviated, time: .omitted))"
                            )
                            .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
                            Text(
                                dayNote
                                    ? "For example: Travel changed the day. I kept things simple."
                                    : "For example: Lunch out with friends. I don’t remember the details."
                            )
                            .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: editing ? 0 : nil).clipped().opacity(editing ? 0 : 1)
                        .accessibilityHidden(editing)
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            TextEditor(text: $bodyText).focused($editing).frame(
                                height: editing
                                    ? max(44, geometry.size.height - 44 - 16 - 24) : 140
                            )
                            .font(Theme.Fonts.body(17)).padding(editing ? 0 : 8).tile(padding: editing ? 0 : 16)
                            .accessibilityLabel(
                                dayNote
                                    ? "What would you like to remember about today?"
                                    : "What would you like to remember about this meal?")
                            if !editing {
                                Text("\(bodyText.unicodeScalars.count)/1,000 characters")
                                    .font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
                                Text(
                                    "No calories or macros are added. You can leave it as a note—there’s nothing to fill in later. Pulse can use it as context when you ask for support."
                                )
                                .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                                if let error { Text(error).foregroundStyle(Theme.Colors.danger) }
                            }
                        }.frame(maxWidth: .infinity)

                    }.padding(.vertical, 4)
                }.scrollDismissesKeyboard(.interactively)
                    .accessibilityIdentifier("mealNoteContent")
                if !editing {
                    Button(saving ? "Saving…" : dayNote ? "Save day note" : "Save meal note") {
                        #if DEBUG
                            if ProcessInfo.processInfo.arguments.contains("--notes-layout-preview") { return }
                        #endif
                        editing = false
                        saving = true
                        error = nil
                        Task {
                            defer { saving = false }
                            do {
                                guard let id = supabase.auth.currentSession?.user.id else {
                                    throw URLError(.userAuthenticationRequired)
                                }
                                guard let text = MealNote.validBody(bodyText) else { return }
                                if pending == nil {
                                    pending =
                                        existing
                                        ?? MealNote(userId: id, logDate: date.isoDateString, meal: meal, body: text)
                                }
                                pending?.body = text
                                try await MealNoteRepository().save(pending!)
                                if existing == nil, let note = pending { undo?.record(note: note) }
                                dismiss()
                                onSaved()
                            } catch {
                                self.error =
                                    "Couldn’t save your note on this phone. Your text is still here; please try again."
                            }
                        }
                    }.buttonStyle(.brandPrimary).disabled(saving || MealNote.validBody(bodyText) == nil)
                }
            }.padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, editing ? 8 : Theme.Spacing.page)
                .daylightReadableWidth(1100)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { editing = false }.accessibilityIdentifier("mealNoteKeyboardDone")
                    }
                }
        }
        .background(Theme.Colors.ground).interactiveDismissDisabled(saving)
        .onAppear { if bodyText.isEmpty { bodyText = existing?.body ?? "" } }
    }
}
