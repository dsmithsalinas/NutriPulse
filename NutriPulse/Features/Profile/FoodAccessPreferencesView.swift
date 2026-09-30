import SwiftUI
import Supabase

@Observable @MainActor
final class FoodAccessViewModel {
    var draft = FoodAccessDraft()
    var isLoading = true
    var isSaving = false
    var loadFailed = false
    var error: String?
    private var userId: UUID?
    private let repo = FoodAccessRepository()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let id = try await supabase.auth.session.user.id
            let saved = try await repo.fetch()
            guard try await supabase.auth.session.user.id == id else { throw URLError(.userAuthenticationRequired) }
            userId = id
            draft = saved?.draft ?? .init()
            loadFailed = false; error = nil
        } catch {
            userId = nil; loadFailed = true
            self.error = "Couldn't load your food preferences. Try again when you're connected."
        }
    }
    func save() async -> Bool {
        guard let userId, !isLoading, !loadFailed, !isSaving else { return false }
        isSaving = true; error = nil
        defer { isSaving = false }
        do {
            _ = try await repo.save(draft, userId: userId)
            guard try await supabase.auth.session.user.id == userId else { throw URLError(.userAuthenticationRequired) }
            NotificationCenter.default.post(name: .foodAccessChanged, object: nil)
            return true
        } catch {
            self.error = "Couldn't save your preferences. Your choices are still here; try again."
            return false
        }
    }
}

struct FoodAccessPreferencesView: View {
    @State private var vm = FoodAccessViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Help Pulse suggest food that fits your everyday life. Choose any that apply.")
                        .font(Theme.Fonts.body(14))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if vm.isLoading {
                        ProgressView("Loading preferences…")
                    } else if vm.loadFailed {
                        Button("Try again") { Task { await vm.load() } }
                            .font(Theme.Fonts.body(15, .semibold))
                            .foregroundStyle(Theme.Colors.primary)
                    } else {
                        ForEach(FoodAccessChoice.allCases) { choice in
                            Toggle(choice.title, isOn: Binding(
                                get: { vm.draft.choices.contains(choice) },
                                set: { selected in
                                    if selected { vm.draft.choices.insert(choice) }
                                    else { vm.draft.choices.remove(choice) }
                                }))
                        }
                    }
                }
                .daylightSection()

                if !vm.isLoading && !vm.loadFailed {
                    Section {
                        TextField("Optional—food access, equipment, or prep time", text: $vm.draft.note, axis: .vertical)
                            .lineLimit(3...6)
                            .onChange(of: vm.draft.note) { _, value in vm.draft.note = String(value.prefix(500)) }
                    } header: {
                        DaylightSectionHeader("Anything else about getting meals ready?")
                    }
                    .daylightSection()

                    Section {
                        Button("Clear my preferences", role: .destructive) { vm.draft = .init() }
                    } footer: {
                        DaylightSectionFooter("Saved preferences apply to future Pulse chats and outlooks until you change them. Refresh an existing outlook to use them. For changes just this week, use Update my week.")
                    }
                    .daylightSection()
                }
                if let error = vm.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(Theme.Fonts.body(12))
                }
            }
            .disabled(vm.isSaving)
            .daylightForm()
            .navigationTitle("Food preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(vm.isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(vm.isSaving ? "Saving…" : "Save") {
                        Task { if await vm.save() { dismiss() } }
                    }.disabled(vm.isLoading || vm.loadFailed || vm.isSaving)
                }
            }
            .task { await vm.load() }
        }
        .tint(Theme.Colors.primary)
        .interactiveDismissDisabled(vm.isSaving)
    }
}
