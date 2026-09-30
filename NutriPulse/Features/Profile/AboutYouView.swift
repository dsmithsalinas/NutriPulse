import SwiftUI

// "What Pulse knows about you" (docs/daylight-redesign.md, step 8): allergies, how you eat,
// foods you love and avoid, and your kitchen situation, all in one place.
// Placeholder so Profile can link here; the full screen replaces this.
struct AboutYouView: View {
    var body: some View {
        Text("What Pulse knows")
            .font(Theme.Typography.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.ground.ignoresSafeArea())
    }
}
