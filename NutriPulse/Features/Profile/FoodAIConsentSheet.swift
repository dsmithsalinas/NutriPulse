import SwiftUI

struct FoodAIConsentSheet: View {
    var onAllowed: (() async -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var store = FoodAIConsentStore.shared
    @State private var owner = FoodAIConsentStore.shared.accountId
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var permissionWasGranted = FoodAIConsentStore.shared.isAllowed

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SheetHeader(title: "AI food logging", onClose: { dismiss() })
                VStack(alignment: .leading, spacing: 12) {
                    Text("To turn a meal description into food entries, Footing sends the words you type or say to Anthropic, the company behind Claude.")
                    Text("Only the food description is sent for parsing—not your name, health history, shot details, Pulse memories, or audio. Food names are also looked up with FatSecret to find nutrition information.")
                }
                .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textPrimary).tile()
                Text("This permission is separate from Pulse. Search, barcode scanning, usual meals, and manual logging stay available without it. You can turn AI food logging off here in Profile at any time.")
                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                Link("Privacy Policy", destination: Config.privacyPolicyURL)
                    .font(Theme.Fonts.body(14, .semibold)).foregroundStyle(Theme.Colors.primary)
                if let errorMessage {
                    Text(errorMessage).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.danger)
                }
                if store.isAllowed || (store.loadFailed && permissionWasGranted) {
                    Button("Turn off AI food logging", role: .destructive) { save(false) }
                        .font(Theme.Fonts.body(16, .semibold))
                } else {
                    Button { save(true) } label: {
                        Text(isWorking ? "Saving…" : "Allow AI food logging")
                            .font(Theme.Fonts.body(16, .bold)).foregroundStyle(Theme.Colors.limeInk)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(Theme.Colors.lime, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                    }
                    Button("Not now") { dismiss() }.font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textSecondary).frame(maxWidth: .infinity)
                }
                if isWorking { ProgressView() }
            }
            .padding(Theme.Spacing.page)
            .disabled(isWorking)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .interactiveDismissDisabled(isWorking)
        .onChange(of: store.accountId) { _, _ in dismiss() }
    }

    private func save(_ agreed: Bool) {
        guard let owner else { dismiss(); return }
        isWorking = true; errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await store.record(agreed: agreed, for: owner)
                guard store.accountId == owner else { return }
                dismiss()
                if agreed { await onAllowed?() }
            } catch {
                errorMessage = "Couldn’t save your choice. Check your connection and try again."
            }
        }
    }
}
