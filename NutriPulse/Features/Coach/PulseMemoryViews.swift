import SwiftUI

struct PulseAttentionSection: View {
    private var store: PulseAttentionStore { .shared }
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow("Pulse’s attention")
            Text("Choose how often Pulse reaches out. You can always start a conversation.")
                .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
            if store.loadFailed {
                Button("Couldn’t load your preference. Retry") { Task { await store.load() } }.frame(minHeight: 44)
            } else if !store.isLoaded {
                ProgressView("Loading your preference…")
            } else {
                ForEach(PulseAttentionLimit.allCases, id: \.self) { limit in
                    Button {
                        Task { do { try await store.setLimit(limit); error = nil } catch { self.error = "Couldn’t save your preference. Please try again." } }
                    } label: {
                        HStack {
                            Text(limit.label)
                            Spacer()
                            Image(systemName: store.limit == limit ? "checkmark.circle.fill" : "circle")
                        }.font(Theme.Fonts.body(15, .semibold)).frame(minHeight: 44)
                    }.buttonStyle(.plain).disabled(store.isSaving)
                        .accessibilityAddTraits(store.limit == limit ? .isSelected : [])
                }
            }
            Text("A limit, not a daily quota. Smart coaching and your Monday outlook share it. Shot reminders are separate.")
                .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
            if let error { Text(error).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.danger) }
        }.tile().tint(Theme.Colors.primary).task { await store.load() }
    }
}

struct PulseMemoriesSection: View {
    private var store: PulseMemoryStore { .shared }
    @State private var editing: PulseMemory?
    @State private var adding = false
    @State private var forgetting: PulseMemory?
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow("What helps you")
            Text("Practical things you’ve chosen to let Pulse remember. Nothing is saved here without your approval.")
                .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
            if store.loadFailed {
                Button("Couldn’t refresh memories. Retry") { Task { await store.load() } }.frame(minHeight: 44)
            } else if !store.isLoaded { ProgressView("Loading memories…") }
            ForEach(store.memories) { memory in
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.content).font(Theme.Fonts.body(16))
                    HStack(spacing: 22) {
                        Button("Edit") { editing = memory }
                        Button("Forget", role: .destructive) { forgetting = memory }
                    }.font(Theme.Fonts.body(14, .semibold)).frame(minHeight: 44).disabled(store.isSaving)
                }
            }
            Button("Remember something that helps") { adding = true }
                .font(Theme.Fonts.body(15, .semibold)).frame(minHeight: 44).disabled(store.isSaving)
            Text("Saved to your account across devices. Forgetting removes a saved memory; it doesn’t erase past conversations. You can clear those separately.")
                .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
            if let error { Text(error).foregroundStyle(Theme.Colors.danger) }
        }.tile().tint(Theme.Colors.primary).task { await store.load() }
            .sheet(isPresented: $adding) { PulseMemoryEditor() }
            .sheet(item: $editing) { PulseMemoryEditor(existing: $0) }
            .confirmationDialog("Forget this memory?", isPresented: Binding(get: { forgetting != nil }, set: { if !$0 { forgetting = nil } }), titleVisibility: .visible) {
                Button("Forget memory", role: .destructive) {
                    guard let memory = forgetting else { return }
                    Task { do { try await store.forget(memory); error = nil } catch { self.error = "Couldn’t forget this memory. Please try again." } }
                }
            }
    }
}

struct PulseMemoryEditor: View {
    var existing: PulseMemory? = nil
    var proposed: String = ""
    var expectedOwner: UUID? = nil
    var readOnlyPreview = false
    var onApproved: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var owner: UUID?
    @State private var saving = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SheetHeader(title: existing == nil ? "Review for Pulse" : "Edit memory", onClose: { dismiss() })
                VStack(alignment: .leading, spacing: 10) {
                    TileEyebrow("Keep what helps", color: Theme.Colors.violetLabel)
                    Text(existing == nil ? "A little context for next time." : "Make it sound like you.")
                        .font(Theme.Fonts.display(28, .bold, relativeTo: .title)).fixedSize(horizontal: false, vertical: true)
                    Text("Choose the words you want Pulse to remember.")
                        .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.violet, in: RoundedRectangle(cornerRadius: Theme.Radius.tile))
                VStack(alignment: .leading, spacing: 12) {
                    TileEyebrow("Exact wording")
                    TextField("For travel, a familiar breakfast makes mornings easier.", text: $content, axis: .vertical)
                        .font(Theme.Fonts.body(17)).lineLimit(3...7)
                        .padding(14).background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("Memory for Pulse").disabled(saving)
                    HStack {
                        Text("Edit anything before approving.")
                        Spacer(minLength: 8)
                        Text("\(content.unicodeScalars.count)/300").monospacedDigit()
                    }.font(Theme.Fonts.body(12)).foregroundStyle(content.unicodeScalars.count > 300 ? Theme.Colors.danger : Theme.Colors.textSecondary)
                }.tile()
                if let error { Text(error).foregroundStyle(Theme.Colors.danger) }
                if readOnlyPreview { Text("Preview only · approval is disabled here.").font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary) }
                Button(saving ? "Saving…" : "Approve and remember") {
                    guard !readOnlyPreview else { return }
                    let approvedText = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    saving = true
                    Task {
                        defer { saving = false }
                        do {
                            if var memory = existing {
                                memory.content = approvedText
                                try await PulseMemoryStore.shared.save(memory)
                            } else {
                                guard let owner else { throw URLError(.userAuthenticationRequired) }
                                try await PulseMemoryStore.shared.approve(approvedText, for: owner)
                            }
                            let savedText = PulseMemoryStore.shared.memories.first {
                                $0.userId == owner && $0.content.caseInsensitiveCompare(approvedText) == .orderedSame
                            }?.content ?? approvedText
                            onApproved?(savedText)
                            dismiss()
                        } catch PulseMemoryStore.SaveError.capacity {
                            self.error = "Pulse can keep 30 practical memories. Edit or forget one to make room."
                        } catch { self.error = "Couldn’t save this memory. Check your connection and try again." }
                    }
                }.buttonStyle(.brandPrimary).disabled(readOnlyPreview || saving || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || content.unicodeScalars.count > 300)
                Text("Only remembered after you approve. You can edit or forget it in What Pulse knows.")
                    .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
            }.padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground).tint(Theme.Colors.primary).interactiveDismissDisabled(saving).scrollDismissesKeyboard(.interactively)
            .onAppear { content = existing?.content ?? proposed; owner = expectedOwner ?? PulseMemoryStore.shared.accountId }
    }
}

#if DEBUG
/// Read-only fixtures using the production views; never reads a personal account.
struct PulseWeekPreview: View {
    @State private var ready = false
    var body: some View {
        ScrollView {
            if ready {
                VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                    Text("Your pace with Pulse").font(Theme.Fonts.display(30, .bold, relativeTo: .title))
                    if ProcessInfo.processInfo.arguments.contains("--breakfast-checkin-preview") {
                        BreakfastCheckinCard(date: .now, hasDetailedBreakfast: false, onLogDifferently: {})
                        Text("Logging and Pulse are here whenever you need them.")
                            .font(Theme.Fonts.body(16)).foregroundStyle(Theme.Colors.textSecondary)
                    } else {
                        PulseAttentionSection()
                        PulseMemoriesSection()
                        BreakfastCheckinSettings()
                    }
                }.padding(Theme.Spacing.page)
            }
        }.background(Theme.Colors.ground.ignoresSafeArea()).allowsHitTesting(false)
            .task {
                UsualMealStore.shared.preview()
                PulseAttentionStore.shared.preview()
                PulseMemoryStore.shared.preview()
                BreakfastCheckinStore.shared.preview()
                ready = true
            }
    }
}
#endif
