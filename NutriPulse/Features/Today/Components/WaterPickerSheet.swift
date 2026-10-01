import SwiftUI

// The water tile's size picker: three presets, a custom stepper, and Undo for the last add.
// Picking a preset also makes it the "usual" amount the tile's + adds in one tap.
struct WaterPickerSheet: View {
    let intakeMl: Double
    let goalMl: Double
    let unit: WaterUnit
    @Binding var usualMl: Double
    /// Logs water and returns the new entry's id (nil if it failed), so it can be undone.
    let onAdd: (Double) async -> UUID?
    let onUndo: (UUID, Double) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customAmount: Double = 0
    @State private var lastAdd: (id: UUID, ml: Double)?
    @State private var isWorking = false

    private var presets: [(label: String, name: String, ml: Double, symbol: String)] {
        let names = ["Glass", "Bottle", "Large bottle"]
        let symbols = ["drop", "waterbottle", "waterbottle.fill"]
        return unit.quickAdds.enumerated().map { index, add in
            (add.label, names[index], add.ml, symbols[index])
        }
    }

    /// One tap of the custom stepper: 50 ml, or 2 oz.
    private var step: Double { unit == .ml ? 50 : 2 * 29.5735 }

    private var remainingText: String {
        let left = goalMl - intakeMl
        return left > 0 ? "\(unit.displayAmount(left)) to go" : "goal reached"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: "Add water", onClose: { dismiss() })

            summary

            HStack(spacing: 10) {
                ForEach(presets, id: \.label) { preset in
                    presetButton(preset)
                }
            }

            customRow

            if let lastAdd {
                undoToast(lastAdd)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("Tip: tapping + on Today adds your usual \(unit.display(usualMl)) in one go.")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.page)
        .padding(.top, 20)
        .background(Theme.Colors.ground.ignoresSafeArea())
        .presentationDetents([.height(560), .large])
        .presentationDragIndicator(.visible)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: lastAdd?.id)
        .onAppear {
            if customAmount == 0 { customAmount = unit == .ml ? 300 : 10 * 29.5735 }
        }
    }

    private var summary: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: 0xF0F9FF))
                LiquidFill(level: goalMl > 0 ? min(intakeMl / goalMl, 1) : 0, color: Color(hex: 0x38BDF8))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.Colors.skyAction, lineWidth: 3)
            }
            .frame(width: 52, height: 84)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(unit.displayAmount(intakeMl))
                    .font(Theme.Fonts.number(40, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.Colors.skyText)
                    .contentTransition(.numericText(value: intakeMl))
                Text("of \(unit.displayAmount(goalMl)) today · \(remainingText)")
                    .font(Theme.Fonts.body(14, .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .tile(radius: 24, padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func presetButton(_ preset: (label: String, name: String, ml: Double, symbol: String)) -> some View {
        let isUsual = abs(preset.ml - usualMl) < 1
        return Button {
            usualMl = preset.ml
            add(preset.ml)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: preset.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.Colors.skyAction)
                // The usual size sits on the fixed light-sky fill; the others on an adaptive tile.
                Text(preset.label)
                    .font(Theme.Fonts.body(17, .bold))
                    .foregroundStyle(isUsual ? Theme.Colors.skyInk : Theme.Colors.skyText)
                    .monospacedDigit()
                Text(preset.name)
                    .font(Theme.Fonts.body(12, .semibold))
                    .foregroundStyle(isUsual ? Theme.Colors.skyLabel : Theme.Colors.skySubtext)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
            .background(isUsual ? Theme.Colors.sky : Theme.Colors.surfaceCard,
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                if isUsual {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.Colors.skyAction, lineWidth: 2)
                }
            }
            .overlay(alignment: .top) {
                if isUsual {
                    Text("Usual")
                        .font(Theme.Fonts.body(11, .bold, relativeTo: nil))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(height: 18)
                        .background(Theme.Colors.skyAction, in: Capsule())
                        .offset(y: -9)
                }
            }
        }
        .buttonStyle(PressableStyle(scale: 0.95))
        .disabled(isWorking)
        .accessibilityLabel("Add \(preset.label), \(preset.name)\(isUsual ? ", your usual" : "")")
    }

    // On a narrow phone at large text the single row ran out of room and broke words mid-way
    // ("Ad / d", "Custo / m"). ViewThatFits keeps the one-line row when it fits and otherwise
    // puts "Custom" on its own line above the controls; no label is ever allowed to wrap.
    private var customRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                customLabel
                Spacer(minLength: 4)
                customControls
            }
            VStack(alignment: .leading, spacing: 8) {
                customLabel
                customControls
            }
            .padding(.vertical, 10)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(minHeight: 56)
        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var customLabel: some View {
        Text("Custom")
            .font(Theme.Fonts.body(15, .bold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .lineLimit(1)
            .fixedSize()
    }

    private var customControls: some View {
        HStack(spacing: 8) {
            stepButton("minus", label: "Less") { customAmount = max(customAmount - step, step) }
            Text(unit.display(customAmount))
                .font(Theme.Fonts.body(16, .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 64)
            stepButton("plus", label: "More") { customAmount = min(customAmount + step, 2000) }
            Spacer(minLength: 0)
            Button { add(customAmount) } label: {
                Text("Add")
                    .font(Theme.Fonts.body(15, .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Theme.Colors.skyAction, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(isWorking)
            .accessibilityLabel("Add \(unit.display(customAmount))")
        }
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(label) water")
    }

    private func undoToast(_ last: (id: UUID, ml: Double)) -> some View {
        HStack {
            Text("Added \(unit.display(last.ml))")
                .font(Theme.Fonts.body(15, .semibold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                let undone = last
                lastAdd = nil
                Task { await onUndo(undone.id, undone.ml) }
            } label: {
                Text("Undo")
                    .font(Theme.Fonts.body(14, .bold))
                    .foregroundStyle(Theme.Colors.limeInk)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Theme.Colors.lime, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Undo adding \(unit.display(last.ml))")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(minHeight: 52)
        .background(Theme.Colors.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func add(_ ml: Double) {
        guard !isWorking else { return }
        isWorking = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            if let id = await onAdd(ml) {
                lastAdd = (id, ml)
            }
            isWorking = false
        }
    }
}
