import SwiftUI

struct DateNavigatorView: View {
    let date: Date
    let isToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(isToday ? "Today" : date.displayDateString)
                    .font(.headline)
                if !isToday {
                    Button("Back to Today", action: onToday)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.primary)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isToday)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(isToday)
            .opacity(isToday ? 0.3 : 1)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, Theme.Spacing.xs)
    }
}
