import SwiftUI

struct CreateGoalView: View {
    @Environment(\.dismiss) private var dismiss
    let vm: GoalsViewModel
    @State private var draft: GoalDraft?
    @State private var step = 1
    @State private var isSaving = false

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
                .padding(16)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .navigationTitle("Create a goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if draft == nil {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button {
                            if step > 1 { step -= 1 } else { draft = nil }
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if draft != nil { bottomAction }
            }
        }
    }

    private var startingPoints: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start with an idea, then make every part your own.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)

            Text("Suggested for you")
                .font(Theme.Typography.title)

            VStack(spacing: 0) {
                ForEach(Array(GoalTemplate.all.enumerated()), id: \.element.id) { index, template in
                    Button { begin(GoalDraft(template: template)) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: template.symbol)
                                .font(.system(size: 19))
                                .foregroundStyle(Theme.Colors.primary)
                                .frame(width: 42, height: 42)
                                .background(Theme.Colors.surfaceInset)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.title)
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(sourceLabel(for: template))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            Spacer()
                            Text("Edit")
                                .font(Theme.Typography.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.primary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .overlay(Capsule().stroke(Theme.Colors.primary.opacity(0.35)))
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if index < GoalTemplate.all.count - 1 {
                        Divider().overlay(Theme.Colors.hairline)
                    }
                }
            }
            .padding(.horizontal, 14)
            .card()

            Button { begin(GoalDraft()) } label: {
                HStack(spacing: 14) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.Colors.primary)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Theme.Colors.primary.opacity(0.55)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Create my own goal")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.primary)
                        Text("Choose what to track and how to measure it")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.Colors.primary)
                }
                .padding(16)
                .background(Theme.Colors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(Theme.Colors.primary.opacity(0.45), style: .init(lineWidth: 1, dash: [3]))
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var builder: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Step \(step) of 3")
                .font(Theme.Typography.body.weight(.semibold))
                .foregroundStyle(Theme.Colors.primary)

            switch step {
            case 1: sourceStep
            case 2: measurementStep
            default: reviewStep
            }
        }
    }

    private var sourceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Suggested goal")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                HStack {
                    TextField("Name your goal", text: draftBinding(\.title))
                        .font(Theme.Typography.title)
                    Image(systemName: "pencil")
                        .foregroundStyle(Theme.Colors.primary)
                }
                .padding(14)
                .background(Theme.Colors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.Colors.primary.opacity(0.65))
                }
                Text("Start with a suggestion, then make it yours.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(16)
            .card()

            Text("How should Footing measure it?")
                .font(Theme.Typography.title)

            Text("Automatic")
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)

            VStack(spacing: 0) {
                ForEach(Array(GoalTrackingSource.automatic.enumerated()), id: \.element.id) { index, source in
                    sourceRow(source)
                    if index < GoalTrackingSource.automatic.count - 1 {
                        Divider().padding(.leading, 58).overlay(Theme.Colors.hairline)
                    }
                }
            }
            .padding(.horizontal, 12)
            .card()

            if let current = draft, current.trackingSource.metrics.count > 1 {
                metricPicker(current)
            }

            Text("Manual check-in")
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)

            HStack(spacing: 10) {
                ForEach(GoalTrackingSource.manual) { source in
                    manualSourceButton(source)
                }
            }
        }
    }

    private var measurementStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Define success")
                .font(Theme.Typography.title)
            Text("Footing will use this definition consistently and preserve it with your goal history.")
                .font(Theme.Typography.body)
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
            .padding(16)
            .card()

            VStack(alignment: .leading, spacing: 6) {
                Label(draft?.trackingSource.title ?? "Source", systemImage: draft?.trackingSource.symbol ?? "circle")
                    .font(Theme.Typography.headline)
                Text(draft?.trackingSource.detail ?? "")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surfaceInset)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review your goal")
                .font(Theme.Typography.title)

            VStack(alignment: .leading, spacing: 16) {
                Label(draft?.title ?? "", systemImage: draft?.trackingSource.symbol ?? "target")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                reviewRow("Measured with", draft?.trackingSource.title ?? "")
                reviewRow("Metric", draft?.sourceMetric?.displayName ?? draft?.trackingSource.title ?? "")
                reviewRow("Target", reviewTarget)
                reviewRow("Timeframe", reviewPeriod)
            }
            .padding(18)
            .card()

            Label("Missing data stays unknown and will not be counted as a failure.", systemImage: "info.circle")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var bottomAction: some View {
        Button(isSaving ? "Creating…" : step == 3 ? "Create goal" : "Continue") {
            guard var current = draft else { return }
            if step < 3 {
                step += 1
                return
            }
            current.title = current.title.trimmingCharacters(in: .whitespacesAndNewlines)
            isSaving = true
            Task {
                if await vm.create(current) { dismiss() }
                isSaving = false
            }
        }
        .buttonStyle(.brandPrimary)
        .disabled(!(draft?.isValid ?? false) || isSaving)
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private func sourceRow(_ source: GoalTrackingSource) -> some View {
        Button { draft?.select(source) } label: {
            HStack(spacing: 12) {
                Image(systemName: source.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.surfaceInset)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(Theme.Typography.body.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(source.detail)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: draft?.trackingSource == source ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(draft?.trackingSource == source ? Theme.Colors.primary : Theme.Colors.textFaint)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 8)
            .background(
                draft?.trackingSource == source
                    ? Theme.Colors.surfaceInset
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        draft?.trackingSource == source
                            ? Theme.Colors.primary.opacity(0.7)
                            : Color.clear
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func manualSourceButton(_ source: GoalTrackingSource) -> some View {
        Button { draft?.select(source) } label: {
            VStack(spacing: 7) {
                Image(systemName: source.symbol)
                    .font(.system(size: 18))
                Text(source.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(draft?.trackingSource == source ? Theme.Colors.primary : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Theme.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(draft?.trackingSource == source ? Theme.Colors.primary : Theme.Colors.hairline)
            }
        }
        .buttonStyle(.plain)
    }

    private func metricPicker(_ current: GoalDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metric")
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
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
            get: { draft?.displayTargetValue ?? 0 },
            set: { draft?.displayTargetValue = $0 }
        )
    }

    private var supportsDirection: Bool {
        guard let source = draft?.trackingSource else { return false }
        return source == .manualNumber || source == .bodyLogs
    }

    private var reviewTarget: String {
        guard let draft else { return "" }
        let value = draft.displayTargetValue.formatted(.number.precision(.fractionLength(0...1)))
        if draft.trackingSource == .manualBoolean { return "At least \(value)%" }
        return "\(value) \(draft.unit)"
    }

    private var reviewPeriod: String {
        guard let draft else { return "" }
        return draft.period == .custom ? "\(draft.durationDays) days" : draft.period.displayName
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .font(Theme.Typography.body)
    }
}
