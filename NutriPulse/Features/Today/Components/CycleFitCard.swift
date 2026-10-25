import SwiftUI
import Supabase

struct CycleFitCard: View {
    let owner: UUID
    let cycleDay: Int
    var preview = false
    let onRecipe: () -> Void
    let onTellPulse: (CycleFitChoice) -> Void
    @State private var previewChoice: CycleFitChoice?
    @State private var error: String?
    private var choice: CycleFitChoice? {
        preview ? previewChoice : EverydayToolsStore.shared.data.cycleFit(on: Date.now.isoDateString, cycleDay: cycleDay)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow("Your experience today")
            Text("Does this fit today?").font(Theme.Fonts.display(22, .bold, relativeTo: .headline))
            if let choice {
                Label(choice.title, systemImage: "checkmark.circle.fill").font(Theme.Fonts.body(16, .semibold)).foregroundStyle(Theme.Colors.primary)
                Text(choice == .different ? "Today comes first. Earlier observations are only background." : choice == .notUseful ? "This card will stay out of your way for today." : "Thanks for checking. Your experience today still leads.")
                    .font(Theme.Fonts.body(14))
                if choice == .familiar { Button("Keep what helps on days like this", action: onRecipe).frame(minHeight: 44) }
                if choice != .notUseful { Button("Tell Pulse about today") { onTellPulse(choice) }.frame(minHeight: 44) }
                Button("Change my answer") { set(nil) }.font(Theme.Fonts.body(14)).frame(minHeight: 44)
            } else {
                ForEach(CycleFitChoice.allCases) { value in
                    Button { set(value) } label: {
                        HStack { Text(value.title); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)) }
                            .font(Theme.Fonts.body(15, .semibold)).padding(12).frame(minHeight: 44)
                            .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
            }
            if let error { Text(error).foregroundStyle(Theme.Colors.danger) }
            Text("For today, on this phone. Only sent to Pulse if you tap Tell Pulse about today. This doesn’t change your check-in.")
                .font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading).tile()
    }
    private func set(_ value: CycleFitChoice?) {
        if preview { previewChoice = value; return }
        let store = EverydayToolsStore.shared
        guard store.accountId == owner, supabase.auth.currentSession?.user.id == owner else { return }
        do { try store.update(owner: owner, generation: store.generation) { $0.setCycleFit(value, day: Date.now.isoDateString, cycleDay: cycleDay) }; error = nil }
        catch { self.error = "Couldn’t save your choice on this phone. Please try again." }
    }
}
