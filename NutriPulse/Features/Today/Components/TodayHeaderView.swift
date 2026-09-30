import SwiftUI

// Today's Daylight header: the date over a big weekday, a calendar button that opens the day
// picker, and a way back when viewing a past day. Days also change by swiping the page (see
// TodayView), and VoiceOver users swipe up/down on this header to step a day.
struct TodayHeaderView: View {
    let date: Date
    let isToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    let onPickDate: () -> Void

    private var dateLine: String {
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        if isToday { return day }
        if Calendar.current.isDateInYesterday(date) { return "\(day) · Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(dateLine)
                    .font(Theme.Fonts.body(14, .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(Theme.Fonts.display(36, .extraBold, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Swipe up or down to change the day")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onNext()
                case .decrement: onPrevious()
                @unknown default: break
                }
            }

            Spacer(minLength: 8)

            if !isToday {
                Button(action: onToday) {
                    Label("Today", systemImage: "arrow.uturn.left")
                        .font(Theme.Fonts.body(14, .bold))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Theme.Colors.surfaceCard, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Back to today")
                .transition(.scale.combined(with: .opacity))
            }

            Button(action: onPickDate) {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceCard, in: Circle())
                    .shadow(color: Color(hex: 0x0F172A, opacity: 0.08), radius: 1, y: 1)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Pick a day")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isToday)
    }
}

// Graphical picker to jump to any past day (never the future).
struct DatePickerSheet: View {
    let selected: Date
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(selected: Date, onPick: @escaping (Date) -> Void) {
        self.selected = selected
        self.onPick = onPick
        _date = State(initialValue: selected)
    }

    var body: some View {
        NavigationStack {
            DatePicker("Jump to day", selection: $date, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.Colors.primary)
                .padding()
                .frame(maxHeight: .infinity, alignment: .top)
                .navigationTitle("Jump to day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onPick(date); dismiss() }
                    }
                }
        }
    }
}
