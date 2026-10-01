import SwiftUI

// Daylight goal builder: a picker screen of suggested templates (or "build your own"), then a
// three-step wizard — source, measurement, review — styled with the same tiles and chips as the
// rest of Goals. Used both as a sheet from GoalsView and standalone via `--goal-builder-preview`,
// so it keeps its own NavigationStack for the back/cancel chrome in both places.
struct CreateGoalView: View {
    @Environment(\.dismiss) private var dismiss
    let vm: GoalsViewModel
    @State private var draft: GoalDraft?
    @State private var step = 1
    @State private var isSaving = false
    @State private var showActiveGoalCapNote = false

    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    // A weight goal's target is always stored in kg; only the editor and review screens
    // convert, so an imperial user enters and reviews it in lbs.
    private var isWeightGoal: Bool { draft?.sourceMetric == .weight }

    init(vm: GoalsViewModel, initialDraft: GoalDraft? = nil) {
        self.vm = vm
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if draft == nil { startingPoints } else { builder }
                }
                .padding(Theme.Spacing.page)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .daylightSubpage("Create a goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if draft == nil {
                        Button("Cancel") { dismiss() }
                            .font(Theme.Fonts.body(16, .semibold))
                    } else {
                        Button {
                            if step > 1 { step -= 1 } else { draft = nil }
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .font(Theme.Fonts.body(16, .semibold))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if draft != nil { bottomAction }
            }
            .tint(Theme.Colors.primary)
        }
    }

    private var startingPoints: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
            DaylightPageTitle("Create a goal", subtitle: "Start with an idea, then make every part your own.")

            TileEyebrow("Suggested for you")

            VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                ForEach(GoalTemplate.all) { template in
                    templateRow(template)
                }
            }

            Button { begin(GoalDraft()) } label: {
                HStack(spacing: 14) {
                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Theme.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.surfaceInset, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Create my own goal")
                            .font(Theme.Fonts.body(16, .bold))
                            .foregroundStyle(Theme.Colors.primaryText)
                        Text("Choose what to track and how to measure it")
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.primary)
                }
                .tile()
            }
            .buttonStyle(PressableStyle(scale: 0.98))
            .accessibilityLabel("Create my own goal")
            .accessibilityHint("Choose what to track and how to measure it")
        }
    }

    private func templateRow(_ template: GoalTemplate) -> some View {
        Button { begin(GoalDraft(template: template)) } label: {
            HStack(spacing: 14) {
                Image(systemName: template.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceInset, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.title)
                        .font(Theme.Fonts.body(16, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(sourceLabel(for: template))
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 8)
                Text("Edit")
                    .font(Theme.Fonts.body(13, .bold))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Theme.Colors.primarySoft, in: Capsule())
            }
            .tile()
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .accessibilityLabel("\(template.title), \(sourceLabel(for: template))")
        .accessibilityHint("Edit this suggested goal")
    }

    @ViewBuilder
    private var builder: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
            VStack(alignment: .leading, spacing: 6) {
                DaylightPageTitle("Create a goal")
                Text("Step \(step) of 3")
                    .font(Theme.Fonts.body(13, .bold))
                    .foregroundStyle(Theme.Colors.primaryText)
            }

            switch step {
            case 1: sourceStep
            case 2: measurementStep
            default: reviewStep
            }
        }
    }

    private var sourceStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
            VStack(alignment: .leading, spacing: 10) {
                TileEyebrow("Suggested goal")
                HStack {
                    TextField("Name your goal", text: draftBinding(\.title), axis: .vertical)
                        .lineLimit(1...3)
                        .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Image(systemName: "pencil")
                        .foregroundStyle(Theme.Colors.primary)
                }
                .padding(14)
                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text("Start with a suggestion, then make it yours.")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .tile()

            TileEyebrow("How should Footing measure it?")

            VStack(alignment: .leading, spacing: 10) {
                Text("Automatic")
                    .font(Theme.Fonts.body(13, .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)

                VStack(spacing: 0) {
                    ForEach(Array(GoalTrackingSource.automatic.enumerated()), id: \.element.id) { index, source in
                        sourceRow(source)
                        if index < GoalTrackingSource.automatic.count - 1 {
                            Divider().padding(.leading, 58).overlay(Theme.Colors.hairline)
                        }
                    }
                }
            }
            .tile()

            if let current = draft, current.trackingSource.metrics.count > 1 {
                metricPicker(current)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Manual check-in")
                    .font(Theme.Fonts.body(13, .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)

                HStack(spacing: 10) {
                    ForEach(GoalTrackingSource.manual) { source in
                        manualSourceButton(source)
                    }
                }
            }
        }
    }

    private var measurementStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
            Text("Define success")
                .font(Theme.Fonts.display(22, .bold, relativeTo: .title2))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Footing will use this definition consistently and preserve it with your goal history.")
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.textSecondary)

            VStack(alignment: .leading, spacing: 16) {
                LabeledContent(draft?.targetPrompt ?? "Target") {
                    TextField("Target", value: displayTargetBinding, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(maxWidth: 120)
                }

                if draft?.trackingSource == .manualNumber {
                    LabeledContent("Unit") {
                        TextField("minutes", text: draftBinding(\.unit))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                } else if isWeightGoal {
                    LabeledContent("Unit", value: units.weightUnit)
                } else if let unit = draft?.unit, !unit.isEmpty {
                    LabeledContent("Unit", value: unit)
                }

                Divider().overlay(Theme.Colors.hairline)

                LabeledContent("Timeframe") {
                    Picker("Timeframe", selection: draftBinding(\.period)) {
                        ForEach(GoalPeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .labelsHidden()
                }

                if draft?.period == .custom {
                    Stepper(value: draftBinding(\.durationDays), in: 2...365) {
                        Text("\(draft?.durationDays ?? 21) days")
                    }
                }

                if supportsDirection {
                    LabeledContent("Direction") {
                        Picker("Direction", selection: draftBinding(\.comparison)) {
                            Text("At least").tag(GoalComparison.atLeast)
                            Text("At most").tag(GoalComparison.atMost)
                            Text("Reach").tag(GoalComparison.reach)
                        }
                        .labelsHidden()
                    }
                }
            }
            .font(Theme.Fonts.body(16))
            .foregroundStyle(Theme.Colors.textPrimary)
            .tile()

            VStack(alignment: .leading, spacing: 6) {
                Label(draft?.trackingSource.title ?? "Source", systemImage: draft?.trackingSource.symbol ?? "circle")
                    .font(Theme.Fonts.body(16, .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(draft?.trackingSource.detail ?? "")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .tile(Theme.Colors.surfaceInset, shadow: false)
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
            Text("Review your goal")
                .font(Theme.Fonts.display(22, .bold, relativeTo: .title2))
                .foregroundStyle(Theme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: 16) {
                Label(draft?.title ?? "", systemImage: draft?.trackingSource.symbol ?? "target")
                    .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                    .foregroundStyle(Theme.Colors.textPrimary)
                reviewRow("Measured with", draft?.trackingSource.title ?? "")
                reviewRow("Metric", draft?.sourceMetric?.displayName ?? draft?.trackingSource.title ?? "")
                reviewRow("Target", reviewTarget)
                reviewRow("Timeframe", reviewPeriod)
            }
            .tile()

            Label("Missing data stays unknown and will not be counted as a failure.", systemImage: "info.circle")
                .font(Theme.Fonts.body(13))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var bottomAction: some View {
        Button(isSaving ? "Creating…" : step == 3 ? "Create goal" : "Continue") {
            guard draft != nil else { return }
            if step < 3 {
                step += 1
                return
            }
            // A calm heads-up, never a block: past the suggested count, pause for confirmation
            // instead of silently piling on another goal.
            if vm.shouldWarnBeforeAddingGoal {
                showActiveGoalCapNote = true
                return
            }
            submit()
        }
        .buttonStyle(.brandPrimary)
        .disabled(!(draft?.isValid ?? false) || isSaving)
        .padding(Theme.Spacing.page)
        .background(.ultraThinMaterial)
        .alert(
            "You have \(vm.active.count) goals going",
            isPresented: $showActiveGoalCapNote
        ) {
            Button("Not now", role: .cancel) {}
            Button("Add anyway") { submit() }
        } message: {
            Text("Fewer goals tend to stick better. Add it anyway?")
        }
    }

    private func submit() {
        guard var current = draft else { return }
        current.title = current.title.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        Task {
            if await vm.create(current) { dismiss() }
            isSaving = false
        }
    }

    private func sourceRow(_ source: GoalTrackingSource) -> some View {
        let isSelected = draft?.trackingSource == source
        return Button { draft?.select(source) } label: {
            HStack(spacing: 12) {
                Image(systemName: source.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(Theme.Fonts.body(15, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(source.detail)
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.Colors.primary : Theme.Colors.textFaint)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 8)
            .background(isSelected ? Theme.Colors.primary.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel("\(source.title), \(source.detail)")
    }

    private func manualSourceButton(_ source: GoalTrackingSource) -> some View {
        let isSelected = draft?.trackingSource == source
        return Button { draft?.select(source) } label: {
            VStack(spacing: 7) {
                Image(systemName: source.symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(source.title)
                    .font(Theme.Fonts.body(12, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? Theme.Colors.primaryText : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(isSelected ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.surfaceInset,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Colors.primary.opacity(0.55) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel(source.title)
    }

    private func metricPicker(_ current: GoalDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TileEyebrow("Metric")
            Picker("Metric", selection: Binding(
                get: { current.sourceMetric ?? current.trackingSource.metrics[0] },
                set: { draft?.select($0) }
            )) {
                ForEach(current.trackingSource.metrics, id: \.self) { metric in
                    Text(metric.displayName).tag(metric)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.Colors.primary)
            .font(Theme.Fonts.body(15, .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .tile()
    }

    private func begin(_ newDraft: GoalDraft) {
        draft = newDraft
        step = 1
    }

    private func sourceLabel(for template: GoalTemplate) -> String {
        GoalDraft(template: template).trackingSource.title
    }

    private func draftBinding<Value>(_ keyPath: WritableKeyPath<GoalDraft, Value>) -> Binding<Value> {
        Binding(
            get: { draft![keyPath: keyPath] },
            set: { draft![keyPath: keyPath] = $0 }
        )
    }

    private var displayTargetBinding: Binding<Double> {
        Binding(
            get: {
                let stored = draft?.displayTargetValue ?? 0
                return isWeightGoal ? units.weightInput(from: stored) : stored
            },
            set: { newValue in
                draft?.displayTargetValue = isWeightGoal ? units.kgFrom(newValue) : newValue
            }
        )
    }

    private var supportsDirection: Bool {
        guard let source = draft?.trackingSource else { return false }
        return source == .manualNumber || source == .bodyLogs
    }

    private var reviewTarget: String {
        guard let draft else { return "" }
        if draft.trackingSource == .manualBoolean {
            let value = draft.displayTargetValue.formatted(.number.precision(.fractionLength(0...1)))
            return "At least \(value)%"
        }
        let displayed = isWeightGoal ? units.weightInput(from: draft.displayTargetValue) : draft.displayTargetValue
        let value = displayed.formatted(.number.precision(.fractionLength(0...1)))
        let unit = isWeightGoal ? units.weightUnit : draft.unit
        return "\(value) \(unit)"
    }

    private var reviewPeriod: String {
        guard let draft else { return "" }
        return draft.period == .custom ? "\(draft.durationDays) days" : draft.period.displayName
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.Fonts.body(14, .semibold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}
