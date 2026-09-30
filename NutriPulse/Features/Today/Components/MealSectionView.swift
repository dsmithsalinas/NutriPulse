import SwiftUI

struct MealSectionView: View {
    let meal: Meal
    let logs: [FoodLog]
    var onEdit: (FoodLog) -> Void = { _ in }
    var onDelete: (FoodLog) -> Void = { _ in }

    private var mealCalories: Double { logs.reduce(0) { $0 + $1.totalCalories } }
    private var mealProtein: Double { logs.reduce(0) { $0 + $1.totalProteinG } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header: the meal as a tile label, its protein first (the number that
            // matters here), calories after.
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                TileEyebrow(meal.displayName)
                Spacer()
                // .rounded() everywhere. Int(Double) truncates toward zero, and the header
                // truncated the SUM while rows truncated each item: two 99.6 kcal rows showed
                // "99" and "99" under a header reading "199". Quantity steps by 0.25, so
                // fractional totals are routine — and the rings, which already used .rounded(),
                // then disagreed with both.
                Text("\(Int(mealProtein.rounded()))g")
                    .font(Theme.Fonts.body(14, .bold))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .monospacedDigit()
                Text("\(Int(mealCalories.rounded())) kcal")
                    .font(Theme.Fonts.body(13, .medium))
                    .foregroundStyle(Theme.Colors.textFaint)
                    .monospacedDigit()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, 14)
            .padding(.bottom, Theme.Spacing.xs)

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
        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.tileSmall, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tileSmall, style: .continuous))
        .shadow(color: Color(hex: 0x0F172A, opacity: 0.06), radius: 1, y: 1)
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
                            .font(Theme.Fonts.body(15, .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Text("\(servingText) · \(Int(log.totalCalories.rounded())) cal")
                            .font(Theme.Fonts.body(12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    // Protein is the number that matters for this app's user — surface it as a
                    // prominent pill instead of burying it in a macro subtitle.
                    Text("\(Int(log.totalProteinG.rounded()))g")
                        .font(Theme.Fonts.body(14, .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Colors.primaryText)
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
                    Text("Delete").font(Theme.Fonts.body(11, .semibold))
                }
                .foregroundStyle(.white)
                .frame(width: buttonWidth)
                .frame(maxHeight: .infinity)
            }
            .background(Theme.Colors.swipeDelete)

            content()
                .background(Theme.Colors.surfaceCard)
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

// Theme has no destructive-red token of its own (see ProfileView's private `danger`, which
// isn't visible outside that file) — the swipe-to-delete affordance needs one too.
private extension Theme.Colors {
    static let swipeDelete = Color(light: 0xB91C1C, dark: 0xF87171)
}
