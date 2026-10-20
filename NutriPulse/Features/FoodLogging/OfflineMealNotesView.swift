import SwiftUI

/// Available during an offline cold start without bypassing profile/onboarding checks.
struct OfflineMealNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var meal = Meal.current
    @State private var creating = false
    @State private var editing: MealNote?
    @State private var deleting: MealNote?
    @State private var undo = FoodSaveUndo()
    @State private var error: String?
    private var store: MealNoteStore { .shared }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SheetHeader(title: "Notes", onClose: { dismiss() })
                Text("You can save a note on this phone while you’re offline. It will sync when you’re connected and signed in.")
                    .font(Theme.Fonts.body(16)).foregroundStyle(Theme.Colors.textSecondary)
                DatePicker("Day", selection: $date, in: ...Date.now, displayedComponents: .date)
                Picker("Meal", selection: $meal) {
                    ForEach(Meal.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.pickerStyle(.menu)
                Button("Leave a meal note") { creating = true }.buttonStyle(.brandPrimary)
                if undo.canUndo {
                    Text("Saved on this phone").font(Theme.Fonts.body(15, .bold))
                    Button("Undo") { Task { _ = await undo.undo() } }.frame(minHeight: 44).disabled(undo.isUndoing)
                }
                if let error = undo.error ?? error { Text(error).foregroundStyle(Theme.Colors.danger) }
                ForEach(store.cached(for: date)) { note in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.displayTitle).font(Theme.Fonts.body(14, .bold))
                        Text(note.body).font(Theme.Fonts.body(16))
                        Text(store.isPending(note.id) ? "Waiting to sync · Nutrition unknown" : "Nutrition unknown")
                            .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                        HStack {
                            Button("Edit") { undo.reset(); editing = note }.frame(minHeight: 44)
                            Spacer()
                            Button("Delete", role: .destructive) { deleting = note }.frame(minHeight: 44)
                        }
                    }.tile(padding: Theme.Spacing.md)
                }
                if store.cached(for: date).isEmpty {
                    Text("No notes saved on this phone for this day.")
                        .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                }
            }.padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground)
            .sheet(isPresented: $creating) {
                MealNoteSheet(date: date, meal: meal) {}.environment(\.foodSaveUndo, undo)
            }
            .sheet(item: $editing) { note in MealNoteSheet(date: date, meal: note.meal, existing: note) {} }
            .confirmationDialog("Delete this note?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete note", role: .destructive) {
                    guard let note = deleting else { return }
                    Task { do { try await MealNoteRepository().delete(note) } catch { self.error = "Couldn’t delete your note. Please try again." } }
                }
            }
    }
}
