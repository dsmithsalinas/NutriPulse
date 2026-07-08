import SwiftUI

struct MealSectionView: View {
    let meal: Meal
    let logs: [FoodLog]
    var onEdit: (FoodLog) -> Void = { _ in }
    var onDelete: (FoodLog) -> Void = { _ in }

    private var mealCalories: Double { logs.reduce(0) { $0 + $1.totalCalories } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Label(meal.displayName, systemImage: meal.icon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                // .rounded() everywhere. Int(Double) truncates toward zero, and the header
                // truncated the SUM while rows truncated each item: two 99.6 kcal rows showed
                // "99" and "99" under a header reading "199". Quantity steps by 0.25, so
                // fractional totals are routine — and the rings, which already used .rounded(),
                // then disagreed with both.
                Text("\(Int(mealCalories.rounded())) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Color(.tertiarySystemBackground))

            // Food log rows
            // SWIFT CONCEPT — ForEach over an Identifiable collection. SwiftUI uses the `id`
            // property to efficiently diff and animate list changes, the same role `key` plays in React.
            ForEach(logs) { log in
                SwipeToDeleteRow(onDelete: { onDelete(log) }) {
                    FoodLogRowView(log: log, onEdit: onEdit)
                        .padding(.horizontal, Theme.Spacing.md)
                }
                if log != logs.last {
                    Divider().padding(.leading, Theme.Spacing.md)
                }
            }
        }
        .card()
    }
}

private struct FoodLogRowView: View {
    let log: FoodLog
    let onEdit: (FoodLog) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            // Tap to edit — a sibling of FavoriteStar's own button, not nested
            // inside it, so both stay independently tappable.
            Button {
                onEdit(log)
            } label: {
                HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.displayName)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(servingText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(log.totalCalories.rounded())) kcal")
                            .font(.subheadline.weight(.medium))
                        Text("P \(Int(log.totalProteinG.rounded()))g · C \(Int(log.totalCarbsG.rounded()))g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            FavoriteStar(foodItemId: log.foodItemId)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var servingText: String {
        let qty = log.quantity == log.quantity.rounded() ? "\(Int(log.quantity))" : String(format: "%.1f", log.quantity)
        let desc = log.foodItems?.servingDesc ?? "serving"
        return "\(qty) × \(desc)"
    }
}

// A minimal, hand-rolled swipe-to-delete. List's native .swipeActions needs a
// real List, which fought this screen's card layout (guessed-at row heights,
// clipped corners where the header meets the rows). This tracks a horizontal
// drag directly on plain content instead, so rows keep sizing themselves
// exactly like every other view here — no height to guess.
private struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offsetX: CGFloat = 0
    private let buttonWidth: CGFloat = 74
    private var isOpen: Bool { offsetX != 0 }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: onDelete) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Delete").font(.caption2)
                }
                .foregroundStyle(.white)
                .frame(width: buttonWidth)
                .frame(maxHeight: .infinity)
            }
            .background(Color.red)

            content()
                .background(Theme.Colors.surface)
                // Swiped open, a tap just closes it instead of triggering the
                // row's own action (matches Mail/Reminders) — .disabled()
                // only mutes the inner Button, the tap-to-close below still runs.
                .disabled(isOpen)
                .offset(x: offsetX)
                .onTapGesture { if isOpen { close() } }
                // .simultaneousGesture, not .gesture — the row sits inside
                // TodayView's ScrollView, and an exclusive gesture makes
                // SwiftUI wait to see which one "wins" before either responds,
                // which is exactly the lag. Simultaneous means no arbitration
                // delay; the horizontal-dominant guard below keeps a vertical
                // scroll from being hijacked into a horizontal swipe.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            offsetX = max(-buttonWidth, min(0, value.translation.width))
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let shouldOpen = value.translation.width < -buttonWidth / 2
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offsetX = shouldOpen ? -buttonWidth : 0
                            }
                        }
                )
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offsetX = 0
        }
    }
}
