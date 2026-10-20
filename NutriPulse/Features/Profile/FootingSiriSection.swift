import AppIntents
import SwiftUI

struct FootingSiriSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow("Siri and shortcuts")
            Text("Save water or a day note without opening Footing. Siri asks you to confirm before saving and may ask you to unlock your phone.")
                .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
            Text("Try “Record water in Footing,” “Save a note in Footing,” or “Today went sideways in Footing.”")
                .font(Theme.Fonts.body(15))
            ShortcutsLink()
            Text("Choose milliliters or US fluid ounces for water. Notes stay qualitative and don’t become lasting Pulse memories. Dose shortcuts open the app for review.")
                .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
        }.tile()
    }
}
