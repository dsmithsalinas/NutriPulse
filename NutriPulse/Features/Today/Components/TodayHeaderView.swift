import SwiftUI

// Day-aware header for Today. On the current day it leads with a time-of-day greeting; on a
// past day it steps aside for the date and a way back. The date pill (‹ label ›) is the day
// navigator — arrows step one day, tapping the label opens a picker to jump anywhere. The
// forward arrow is disabled on today, since there's no logging into the future.
struct TodayHeaderView: View {
    let firstName: String
    let date: Date
    let isToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    let onPickDate: () -> Void

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12:  return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default:      return "Hi"
        }
    }

    private var pillLabel: String {
        if isToday { return "Today" }
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d"
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                arrow("chevron.left", action: onPrevious, disabled: false)

                Button(action: onPickDate) {
                    HStack(spacing: 5) {
                        Text(pillLabel)
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.surfaceCard)
                    .clipShape(Capsule())
                    .overlay { Capsule().strokeBorder(Theme.Colors.hairline, lineWidth: 1) }
                }
                .buttonStyle(.plain)

                arrow("chevron.right", action: onNext, disabled: isToday)

                Spacer(minLength: 8)
            }

            if isToday {
                Text("\(greeting), \(firstName)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
            } else {
                Button(action: onToday) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Back to today")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.18), value: isToday)
    }

    private func arrow(_ system: String, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 30, height: 30)
                .background(Theme.Colors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
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
