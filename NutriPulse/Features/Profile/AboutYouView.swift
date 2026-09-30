import SwiftUI

// "What Pulse knows about you" (docs/daylight-redesign.md, step 8): allergies, how you eat,
// foods you love and avoid, and your kitchen situation, all in one place. Reachable from
// Profile (pushed) and from Pulse's start screen (a sheet) — kept working both ways by never
// wrapping its own NavigationStack; `SheetHeader`'s close action pops or dismisses either way.

// MARK: - View model

@Observable
@MainActor
final class AboutYouViewModel {
    var draft = PulsePreferences()
    var newAllergyText = ""
    var newLoveText = ""
    var newAvoidText = ""

    var isSaving = false
    var saveError: String? = nil

    private var original = PulsePreferences()
    private let store: PulseProfileStore

    init(store: PulseProfileStore = .shared) {
        self.store = store
    }

    var isLoading: Bool { !store.isLoaded }
    // The store keeps its last-good preferences even when a later reload fails, so only show
    // the full error state when there's truly nothing to edit yet — a stale-but-present draft
    // beats blocking the screen on a transient retry.
    var showLoadError: Bool { store.loadFailed && original.isEmpty && draft.isEmpty }

    var hasChanges: Bool { draft.normalized != original.normalized }

    func load() async {
        if !store.isLoaded {
            await store.load()
        }
        applyStoreState()
    }

    func retry() async {
        await store.load()
        applyStoreState()
    }

    private func applyStoreState() {
        guard !store.loadFailed || !store.preferences.isEmpty else { return }
        original = store.preferences
        draft = store.preferences
    }

    @discardableResult
    func save() async -> Bool {
        guard hasChanges, !isSaving else { return false }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            try await store.savePreferences(draft)
            original = store.preferences
            draft = original
            return true
        } catch {
            saveError = "Couldn't save. Your changes are still here — try again."
            return false
        }
    }

    // MARK: Allergies

    func isCommonAllergenSelected(_ name: String) -> Bool {
        draft.allergies.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    func toggleCommonAllergen(_ name: String) {
        if isCommonAllergenSelected(name) {
            draft.allergies.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        } else {
            draft.allergies.append(name)
        }
    }

    func addAllergy() {
        let trimmed = newAllergyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !draft.allergies.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            draft.allergies.append(trimmed)
        }
        newAllergyText = ""
    }

    func removeAllergy(_ item: String) {
        draft.allergies.removeAll { $0 == item }
    }

    // MARK: Eating patterns

    func togglePattern(_ pattern: EatingPattern) {
        if draft.eatingPatterns.contains(pattern) {
            draft.eatingPatterns.remove(pattern)
        } else {
            draft.eatingPatterns.insert(pattern)
        }
    }

    // MARK: Loves / avoids

    func addLove() {
        let trimmed = newLoveText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !draft.loves.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            draft.loves.append(trimmed)
        }
        newLoveText = ""
    }

    func removeLove(_ item: String) {
        draft.loves.removeAll { $0 == item }
    }

    func addAvoid() {
        let trimmed = newAvoidText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !draft.avoids.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            draft.avoids.append(trimmed)
        }
        newAvoidText = ""
    }

    func removeAvoid(_ item: String) {
        draft.avoids.removeAll { $0 == item }
    }
}

// MARK: - View

struct AboutYouView: View {
    @State private var vm = AboutYouViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showKitchenSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                SheetHeader(title: "What Pulse knows", onClose: { dismiss() })

                Text("Pulse steers suggestions away from what you can't or won't eat, and toward what works for you.")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.textSecondary)

                if vm.isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if vm.showLoadError {
                    loadFailedTile
                } else {
                    allergySection
                    eatingPatternSection
                    lovesSection
                    avoidsSection
                    kitchenSection

                    if let error = vm.saveError {
                        Text(error)
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(.red)
                    }

                    saveButton
                }
            }
            .padding(Theme.Spacing.page)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load() }
        .sheet(isPresented: $showKitchenSheet) {
            FoodAccessPreferencesView()
        }
    }

    // MARK: - Load failure

    private var loadFailedTile: some View {
        VStack(spacing: 12) {
            Text("Couldn't load what Pulse knows about you.")
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await vm.retry() } }
                .buttonStyle(.brandPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Allergies

    private var allergySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow("Allergies & intolerances")

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(CommonAllergen.all, id: \.self) { name in
                    ToggleChip(title: name, isSelected: vm.isCommonAllergenSelected(name)) {
                        vm.toggleCommonAllergen(name)
                    }
                }
            }

            AddChipField(placeholder: "Add another", text: $vm.newAllergyText, onAdd: vm.addAllergy)
                .accessibilityLabel("Add another allergy or intolerance")

            if !vm.draft.allergies.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(vm.draft.allergies, id: \.self) { item in
                        RemovableChip(title: item) { vm.removeAllergy(item) }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("Optional note — how serious, what happens", text: $vm.draft.allergyNote, axis: .vertical)
                    .font(Theme.Fonts.body(14))
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onChange(of: vm.draft.allergyNote) { _, value in
                        vm.draft.allergyNote = String(value.prefix(300))
                    }
                    .accessibilityLabel("Allergy note, optional")
                Text("\(vm.draft.allergyNote.count)/300")
                    .font(Theme.Fonts.body(11))
                    .foregroundStyle(Theme.Colors.textFaint)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        }
        .tile()
    }

    // MARK: - Eating patterns

    private var eatingPatternSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow("How you eat")
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(EatingPattern.allCases) { pattern in
                    ToggleChip(title: pattern.label, isSelected: vm.draft.eatingPatterns.contains(pattern)) {
                        vm.togglePattern(pattern)
                    }
                }
            }
        }
        .tile()
    }

    // MARK: - Loves / avoids

    private var lovesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow("Foods you love")
            AddChipField(placeholder: "Add a food you love", text: $vm.newLoveText, onAdd: vm.addLove)
                .accessibilityLabel("Add a food you love")
            if !vm.draft.loves.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(vm.draft.loves, id: \.self) { item in
                        RemovableChip(title: item) { vm.removeLove(item) }
                    }
                }
            }
        }
        .tile()
    }

    private var avoidsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow("Foods you'd rather skip")
            AddChipField(placeholder: "Add a food to avoid", text: $vm.newAvoidText, onAdd: vm.addAvoid)
                .accessibilityLabel("Add a food to avoid")
            if !vm.draft.avoids.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(vm.draft.avoids, id: \.self) { item in
                        RemovableChip(title: item) { vm.removeAvoid(item) }
                    }
                }
            }
        }
        .tile()
    }

    // MARK: - Kitchen

    // Reuses FoodAccessPreferencesView as-is — its own load/save/error handling — rather than
    // duplicating FoodAccessViewModel's data logic here.
    private var kitchenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TileEyebrow("Your kitchen")
            Text("Budget, cooking, and how much time you have for meals.")
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.textSecondary)
            Button("Edit kitchen preferences") { showKitchenSheet = true }
                .font(Theme.Fonts.body(14, .bold))
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(minHeight: 44, alignment: .leading)
        }
        .tile()
    }

    // MARK: - Save

    private var saveButton: some View {
        Button(vm.isSaving ? "Saving…" : "Save") {
            Task { await vm.save() }
        }
        .buttonStyle(.brandPrimary)
        .disabled(!vm.hasChanges || vm.isSaving)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Chips

/// A tappable chip for a fixed option (common allergens, eating patterns) — selected state is a
/// filled/tinted look plus the VoiceOver `.isSelected` trait, not just a visual change.
private struct ToggleChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(isSelected ? Theme.Colors.primaryText : Theme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(isSelected ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.surfaceInset,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Theme.Colors.primary.opacity(0.55) : .clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel(title)
    }
}

/// A chip for something the user typed in — shows what's chosen and lets them remove it.
private struct RemovableChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Colors.textFaint)
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Remove \(title)")
        }
        .padding(.leading, 12)
        .frame(minHeight: 44)
        .background(Theme.Colors.surfaceInset, in: Capsule())
    }
}

/// A free-text "add" row — a text field plus a circular plus button, shared by every add-your-own
/// section (allergies, loves, avoids).
private struct AddChipField: View {
    let placeholder: String
    @Binding var text: String
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .font(Theme.Fonts.body(14))
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onSubmit(onAdd)
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Theme.Colors.textFaint : Theme.Colors.primary,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .buttonStyle(.pressable)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Add")
        }
    }
}
