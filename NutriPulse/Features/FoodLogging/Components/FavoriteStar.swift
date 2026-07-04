import SwiftUI

struct FavoriteStar: View {
    let foodItemId: UUID
    @State private var isToggling = false

    var body: some View {
        Button {
            guard !isToggling else { return }
            Task {
                isToggling = true
                await FavoritesStore.shared.toggle(foodItemId: foodItemId)
                isToggling = false
            }
        } label: {
            Image(systemName: FavoritesStore.shared.isFavorited(foodItemId) ? "star.fill" : "star")
                .foregroundStyle(FavoritesStore.shared.isFavorited(foodItemId) ? Color.yellow : Color.secondary)
                .imageScale(.small)
        }
        .buttonStyle(.plain)
        .opacity(isToggling ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isToggling)
    }
}
