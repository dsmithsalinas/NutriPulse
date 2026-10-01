import SwiftUI

// The Log sheet's persistent chrome (docs/daylight-redesign.md): a header showing which meal
// everything on this sheet logs to, and the Talk/Search/Scan/Favorites tab strip beneath it.

/// "Adding to Dinner ▾" plus a close button. The meal here is the single source of truth for
/// every tab: a food's "+" logs straight to it, and the confirm step starts pre-filled from it.
struct LogSheetHeader: View {
    @Binding var meal: Meal
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Adding to")
                    .font(Theme.Fonts.body(14, .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Menu {
                    ForEach(Meal.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { option in
                        Button {
                            meal = option
                        } label: {
                            Label(option.displayName, systemImage: option.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(meal.displayName)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .font(Theme.Fonts.display(28, .extraBold, relativeTo: .title))
                    .foregroundStyle(Theme.Colors.textPrimary)
                }
                .accessibilityLabel("Meal: \(meal.displayName)")
                .accessibilityHint("Double tap to change which meal you're adding to")
            }
            Spacer(minLength: 12)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceCard, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Close")
        }
    }
}

/// The Talk / Search / Scan / Favorites segmented control — an inset track with the selected
/// tab drawn as an ink capsule, matching the mockups' tab strip.
struct LogTabBar: View {
    @Binding var selection: FoodLoggingViewModel.LogTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FoodLoggingViewModel.LogTab.allCases, id: \.self) { tab in
                let selected = selection == tab
                Button {
                    if reduceMotion {
                        selection = tab
                    } else {
                        withAnimation(Theme.Motion.tabSelect) { selection = tab }
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(Theme.Fonts.body(14, selected ? .bold : .semibold))
                        .foregroundStyle(selected ? Theme.Colors.selectionText : Theme.Colors.textSecondary)
                        // Slightly taller than the mockup's 40pt track for a ≥44pt tap target.
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.Colors.selectionFill)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Log method")
    }
}
