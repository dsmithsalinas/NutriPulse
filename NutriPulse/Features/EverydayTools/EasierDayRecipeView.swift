import SwiftUI

struct EasierDayRecipeView: View {
    let owner: UUID
    var preview = false
    @Environment(\.dismiss) private var dismiss
    @State private var draft = EasierDayRecipeDraft()
    @State private var proposed: String?
    @State private var approvedMemory: String?
    init(owner: UUID, preview: Bool = false, support: String = "") {
        self.owner = owner; self.preview = preview
        _draft = State(initialValue: EasierDayRecipeDraft(support: support))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: "Your easier-day recipe", onClose: { dismiss() })
                VStack(alignment: .leading, spacing: 10) {
                    TileEyebrow("Keep what helps", color: Theme.Colors.violetLabel)
                    Text("A little less to figure out next time.").font(Theme.Fonts.display(27, .bold, relativeTo: .title))
                    Text("Choose practical things that help you. Review the exact wording before Pulse remembers it.").font(Theme.Fonts.body(15))
                }.padding(20).background(Theme.Colors.violet, in: RoundedRectangle(cornerRadius: Theme.Radius.tile))
                if let approvedMemory {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Approved for Pulse", systemImage: "checkmark.circle.fill").font(Theme.Fonts.body(18, .bold))
                        Text(approvedMemory).font(Theme.Fonts.body(16))
                        Text("You can edit or forget this in What Pulse knows.").font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                    }.tile()
                    Button("Done") { dismiss() }.buttonStyle(.brandPrimary)
                } else {
                VStack(alignment: .leading, spacing: 16) {
                    field("When this helps", placeholder: "e.g. Low-energy afternoons", text: $draft.situation)
                    field("Something to eat", placeholder: "e.g. My usual yogurt and fruit", text: $draft.food)
                    field("A water shortcut", placeholder: "e.g. Keep my small bottle nearby", text: $draft.water)
                    field("Support that helps", placeholder: "e.g. One manageable option at a time", text: $draft.support)
                    Text("Add whichever parts help. Keep the whole recipe brief enough for a 300-character memory.")
                        .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                }.tile()
                Text("\(draft.draftText?.unicodeScalars.count ?? 0)/300 characters").font(Theme.Fonts.body(13))
                    .foregroundStyle((draft.draftText?.unicodeScalars.count ?? 0) > 300 ? Theme.Colors.danger : Theme.Colors.textSecondary)
                Button("Review recipe") { proposed = draft.memory }.buttonStyle(.brandPrimary).disabled(draft.memory == nil)
                Text("This saves a preference only after approval. Goals and reminder settings stay as you set them.")
                    .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                }
            }.padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground).tint(Theme.Colors.primary).scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: Binding(get: { proposed != nil }, set: { if !$0 { proposed = nil } })) {
            if let proposed { PulseMemoryEditor(proposed: proposed, expectedOwner: owner, readOnlyPreview: preview, onApproved: { approvedMemory = $0 }) }
        }
        .onChange(of: EverydayToolsStore.shared.accountId) { _, account in if !preview && account != owner { proposed = nil; dismiss() } }
    }
    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.Fonts.body(14, .semibold))
            TextField(placeholder, text: text, axis: .vertical).font(Theme.Fonts.body(16)).lineLimit(1...4)
                .padding(12).background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel(title)
        }
    }
}
