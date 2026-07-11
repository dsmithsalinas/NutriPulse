import SwiftUI

/// Required attribution for the FatSecret Platform API. Per the platform licensing agreement,
/// this must appear on every screen that displays FatSecret nutrition data (food search results
/// and the food-detail sheet, which also backs barcode scans). Tapping opens the platform site.
///
/// The official brand badge is bundled locally (FatSecretAttribution.imageset) rather than
/// hot-linked from platform.fatsecret.com, so it renders offline and needs no runtime fetch.
struct FatSecretAttribution: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(URL(string: "https://platform.fatsecret.com")!)
        } label: {
            Image("FatSecretAttribution")
                .resizable()
                .scaledToFit()
                .frame(height: 26)
                .accessibilityLabel("Nutrition information provided by FatSecret Platform API")
        }
        .buttonStyle(.plain)
    }
}
