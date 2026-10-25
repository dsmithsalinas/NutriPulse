import SwiftUI

struct GentlerDayCard: View {
    let onFamiliar: () -> Void
    let onLighter: () -> Void
    let onDismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow("A gentler start")
            Text("Your recorded sleep was shorter than your recent usual.").font(Theme.Fonts.body(17, .bold))
            Text("How you feel matters most. Want one less decision today?").font(Theme.Fonts.body(14))
            Button("Find something familiar", action: onFamiliar).frame(minHeight: 44).foregroundStyle(Theme.Colors.primary)
            Button("Take it easier", action: onLighter).frame(minHeight: 44).foregroundStyle(Theme.Colors.primary)
            Button("I’m okay today", action: onDismiss).frame(minHeight: 44).foregroundStyle(Theme.Colors.primary)
        }.foregroundStyle(Theme.Colors.textPrimary).tint(Theme.Colors.primary).tile()
    }
}
