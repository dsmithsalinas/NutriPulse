import SwiftUI

struct LighterTrackingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var duration: LighterTrackingSetting.Duration?
    @State private var reason: LighterTrackingSetting.Reason?
    @State private var error: String?
    @State private var initialized = false
    private var store: TrackingPreferencesStore { .shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SheetHeader(title: "Take it easier", onClose: { dismiss() })
                Text("Less tracking pressure. Support when you need it.")
                    .font(Theme.Fonts.body(17)).foregroundStyle(Theme.Colors.textSecondary)
                VStack(alignment: .leading, spacing: 16) {
                    TileEyebrow("What changes")
                    Label("Goal reminders pause", systemImage: "bell.slash")
                    Divider()
                    Label("Logging and Pulse stay available", systemImage: "checkmark.circle")
                    Divider()
                    Label("Incomplete days stay unassessed", systemImage: "minus.circle")
                }
                .font(Theme.Fonts.body(16))
                .foregroundStyle(Theme.Colors.textPrimary)
                .tile(padding: Theme.Spacing.md)
                Text("Your goals and past entries stay saved. Medication reminders are managed separately.")
                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    TileEyebrow("For how long?")
                    if store.isActive && !store.needsResumeChoice {
                        choice(store.setting?.endsAt.map { "Keep current end: \($0.formatted(date: .abbreviated, time: .shortened))" }
                               ?? "Keep until I’m ready", selected: duration == nil) { duration = nil }
                    }
                    ForEach(LighterTrackingSetting.Duration.allCases) { option in
                        choice(option.title, selected: store.isActive ? duration == option : (duration ?? .untilReady) == option) { duration = option }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    TileEyebrow("Optional context")
                    Text("Anything you’d like us to know?")
                        .font(Theme.Fonts.body(16, .semibold))
                    choice("No context", selected: reason == nil) { reason = nil }
                    ForEach(LighterTrackingSetting.Reason.allCases) { option in
                        choice(option.title, selected: reason == option) { reason = option }
                    }
                    Text("This helps Pulse tailor support. Feeling unwell doesn’t change your targets or medication plan.")
                        .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                }
                if store.loadFailed {
                    Text("Couldn’t refresh this setting. You can retry or save your choice.")
                        .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    Button("Retry") { Task { await store.load() } }
                }
                if let error {
                    Text(error).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.danger)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                Button(store.isActive ? "Save lighter tracking" : "Start lighter tracking") {
                    Task { await save(resume: false) }
                }
                .buttonStyle(.brandPrimary)
                .disabled(store.isSaving)
                if store.isActive {
                    Button("Return to usual tracking") { Task { await save(resume: true) } }
                        .font(Theme.Fonts.body(16, .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(store.isSaving)
                }
                if store.isSaving { ProgressView("Saving…").frame(maxWidth: .infinity) }
            }
            .padding(Theme.Spacing.page)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .tint(Theme.Colors.primaryText)
        .interactiveDismissDisabled(store.isSaving)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await store.load()
            guard !initialized else { return }
            if store.needsResumeChoice { duration = .untilReady; reason = nil }
            else if store.isActive { reason = store.contextReason }
            initialized = true
        }
    }
    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(Theme.Fonts.body(16, .semibold))
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
            .foregroundStyle(selected ? Theme.Colors.primaryText : Theme.Colors.textPrimary)
            .padding(.horizontal, 14).frame(minHeight: 48)
            .background(selected ? Theme.Colors.primarySoft : Theme.Colors.surfaceCard,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.row))
        }
        .buttonStyle(.plain).disabled(store.isSaving)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func save(resume: Bool) async {
        error = nil
        do {
            if resume { try await store.resume() }
            else { try await store.update(reason: reason, duration: duration) }
            dismiss()
        } catch {
            self.error = "Couldn’t save your setting. Check your connection and try again."
        }
    }
}
