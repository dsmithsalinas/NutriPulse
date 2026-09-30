import SwiftUI

// Daylight Talk tab (docs/daylight-redesign.md): idle (mic hero + type box), listening (live
// transcript), parsing, then the confirm rows — with a lime "This clears your floor" tile when
// logging the parsed items would bring today's protein up to goal. The parse/confirm/save flow
// itself is unchanged from before the redesign; only the chrome around it moved.
struct TalkToLogView: View {
    @Bindable var vm: TalkToLogViewModel
    let date: Date
    let headerMeal: Meal
    let onLogged: (LogSource) -> Void

    @State private var dictation = DictationRecognizer()
    // What was already in the field when dictation started, so speech appends rather than
    // clobbers anything the user had typed.
    @State private var dictationBase = ""
    @FocusState private var isTyping: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let examples = [
        "Same breakfast as yesterday", "Half a chicken wrap", "Protein shake after the gym"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                if vm.hasParsed {
                    parsedContent
                } else if vm.isParsing {
                    parsingTile
                } else if dictation.isListening {
                    listeningTile
                } else {
                    idleContent
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) { actionBar }
        .onChange(of: dictation.transcript) { _, text in
            if dictation.isListening { vm.inputText = dictationBase + text }
        }
        .onChange(of: dictation.status) { _, status in
            switch status {
            case .denied:
                vm.errorMessage = "Microphone or speech access is off. Turn it on in Settings to speak your log."
            case .unavailable:
                vm.errorMessage = "Speech recognition isn't available right now. Type your log instead, or try again in a moment."
            default:
                break
            }
        }
        .onDisappear { dictation.stop() }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Idle (mic hero + type box)

    private var idleContent: some View {
        VStack(spacing: 18) {
            micHero
            dividerRow
            typeBox
            tryChips
        }
        .popIn(order: 0)
    }

    private var micHero: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("What did you have?")
                    .font(Theme.Fonts.display(22, .bold, relativeTo: .title2))
                    .foregroundStyle(.white)
                Text("Say it like you'd tell a friend. Portions and corrections are fine.")
                    .font(Theme.Fonts.body(14, relativeTo: .footnote))
                    .foregroundStyle(Theme.Colors.heroLabel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                dictationBase = vm.inputText.isEmpty ? "" : vm.inputText + " "
                Task { await dictation.start() }
            } label: {
                ZStack {
                    if !reduceMotion {
                        MicPulseRing(color: Theme.Colors.heroLabel)
                    }
                    Circle()
                        .fill(Theme.Colors.hero)
                        .frame(width: 96, height: 96)
                        .shadow(color: Theme.Colors.hero.opacity(0.45), radius: 14, y: 6)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 96, height: 96)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Talk to log your food")

            Text("Tap to talk")
                .font(Theme.Fonts.body(14, .bold))
                .foregroundStyle(Theme.Colors.heroSubtext)
        }
        .frame(maxWidth: .infinity)
        .tile(Theme.Colors.heroDeep, shadow: false)
    }

    private var dividerRow: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.Colors.hairline).frame(height: 1)
            Text("or type it")
                .font(Theme.Fonts.body(13, .bold))
                .foregroundStyle(Theme.Colors.textFaint)
            Rectangle().fill(Theme.Colors.hairline).frame(height: 1)
        }
    }

    private var canParse: Bool { !vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var typeBox: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("2 eggs, toast with butter, black coffee", text: $vm.inputText, axis: .vertical)
                .font(Theme.Fonts.body(16))
                .lineLimit(1...4)
                .focused($isTyping)
                .accessibilityLabel("Describe what you ate")
            Button {
                Task { await vm.parse(for: date) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(canParse ? Theme.Colors.primary : Theme.Colors.textFaint,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(!canParse)
            .accessibilityLabel("Add from text")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.tileSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.tileSmall, style: .continuous)
                .strokeBorder(canParse ? Theme.Colors.primary : Theme.Colors.hairline, lineWidth: 2)
        }
    }

    private var tryChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            TileEyebrow("Try", color: Theme.Colors.textFaint)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Self.examples, id: \.self) { example in
                    Button { vm.inputText = example } label: {
                        Text(example)
                            .font(Theme.Fonts.body(14, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableStyle(scale: 0.95))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Listening

    private var listeningTile: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    RecordingDot()
                    Text("LISTENING")
                        .font(Theme.Fonts.body(13, .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.Colors.heroLabel)
                }
                Spacer(minLength: 0)
                Text("Say it how you'd say it")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.heroLabel)
            }
            WaveformView()
            Text(dictation.transcript.isEmpty ? "…" : dictation.transcript)
                .font(Theme.Fonts.display(18, .medium, relativeTo: .title3))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(dictation.transcript.isEmpty ? "Listening" : dictation.transcript)
        }
        .tile(Theme.Colors.heroDeep, shadow: false)
    }

    // MARK: - Parsing

    private var parsingTile: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white)
            Text("Working out the details…")
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(Theme.Colors.heroLabel)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .tile(Theme.Colors.heroDeep, shadow: false)
    }

    // MARK: - Parsed (confirm)

    private var parsedContent: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array($vm.rows.enumerated()), id: \.element.id) { index, $row in
                ConfirmRowView(row: $row)
                    .popIn(order: index)
            }

            if vm.wouldClearProteinFloor {
                clearsFloorTile
                    .popIn(order: vm.rows.count)
            }

            correctionField

            Button("Start Over") { vm.reset() }
                .font(Theme.Fonts.body(13, .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.top, Theme.Spacing.xs)
        }
    }

    private var clearsFloorTile: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.Colors.lime)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.limeInk, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("This clears your floor")
                    .font(Theme.Fonts.body(15, .bold))
                    .foregroundStyle(Theme.Colors.limeInk)
                Text(floorProgressText)
                    .font(Theme.Fonts.body(13).monospacedDigit())
                    .foregroundStyle(Theme.Colors.limeLabel)
            }
            Spacer(minLength: 0)
        }
        .tile(Theme.Colors.lime, shadow: false)
        .accessibilityElement(children: .combine)
    }

    private var floorProgressText: String {
        let goal = Int((vm.proteinGoalG ?? 0).rounded())
        let after = Int((vm.todayProteinG + vm.pendingProteinG).rounded())
        let added = Int(vm.pendingProteinG.rounded())
        return "+\(added)g → \(after)g of \(goal)g"
    }

    private var correctionField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Actually, half the rice…", text: $vm.correctionText)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { vm.applyCorrection() }
                .font(Theme.Fonts.body(15))
            Button("Apply") { vm.applyCorrection() }
                .font(Theme.Fonts.body(14, .bold))
                .foregroundStyle(Theme.Colors.primaryText)
                .disabled(vm.correctionText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Bottom action bar

    @ViewBuilder
    private var actionBar: some View {
        if vm.hasParsed {
            HStack(spacing: 10) {
                Button {
                    Task {
                        do {
                            try await vm.logAll(on: date)
                            onLogged(.talk)
                        } catch {
                            vm.errorMessage = "Couldn't save that log. Try again."
                        }
                    }
                } label: {
                    if vm.isLogging {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(vm.pendingCount == 1 ? "Log it" : "Log \(vm.pendingCount) items")
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(Theme.Fonts.body(17, .bold))
                .foregroundStyle(.white)
                .frame(height: 56)
                .background(Theme.Colors.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .buttonStyle(.pressable)
                .disabled(vm.isLogging || vm.pendingCount == 0)
            }
        } else if dictation.isListening {
            HStack(spacing: 10) {
                Button {
                    dictation.stop()
                    isTyping = true
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Switch to typing")

                Button {
                    dictation.stop()
                    Task { await vm.parse(for: date) }
                } label: {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.Colors.listeningAction)
                        .frame(width: 16, height: 16)
                        .frame(width: 56, height: 56)
                        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Stop listening and log")

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Idle mic decoration

private struct MicPulseRing: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: 96, height: 96)
            .scaleEffect(animate ? 1.6 : 1)
            .opacity(animate ? 0 : 0.6)
            .onAppear {
                withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
            .accessibilityHidden(true)
    }
}

private struct RecordingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false
    var body: some View {
        Circle()
            .fill(Theme.Colors.listening)
            .frame(width: 8, height: 8)
            .opacity(dim ? 0.3 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
            .accessibilityHidden(true)
    }
}

private struct WaveformView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    private let heights: [CGFloat] = [18, 30, 40, 26, 36, 44, 30, 22, 38, 44, 28, 34, 20, 32, 24, 14]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(heights.indices, id: \.self) { i in
                Capsule()
                    .fill(Theme.Colors.heroLabel)
                    .frame(width: 4, height: (animate || reduceMotion) ? heights[i] : heights[i] * 0.4)
            }
        }
        .frame(height: 44)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { animate = true }
        }
        .accessibilityHidden(true)
    }
}

// One editable row in the confirm card — a single parsed food component.
private struct ConfirmRowView: View {
    @Binding var row: TalkToLogViewModel.ConfirmRow

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                row.isIncluded.toggle()
            } label: {
                // A saved row is locked: it's already in the day, and un-including it here
                // wouldn't remove it.
                Image(systemName: row.isSaved ? "checkmark.circle.fill"
                                 : row.isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(row.isSaved ? Theme.NutrientColor.fiber
                                     : row.isIncluded ? Theme.Colors.primary : Theme.Colors.textFaint)
            }
            .buttonStyle(.plain)
            .disabled(row.isSaved)
            .accessibilityLabel(row.isIncluded ? "Included — tap to remove \(row.name)" : "Excluded — tap to include \(row.name)")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(row.name)
                        .font(Theme.Fonts.body(15, .bold))
                        .lineLimit(1)
                    if row.source == "estimated" {
                        Text("estimated")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.NutrientColor.fat.opacity(0.15))
                            .foregroundStyle(Theme.NutrientColor.fat)
                            .clipShape(Capsule())
                    }
                }
                Text(row.isSaved
                     ? "Logged · \(Int(row.totalCalories.rounded())) cal"
                     : "\(row.servingDesc) · \(Int(row.totalCalories.rounded())) cal")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer(minLength: 0)

            Text("\(Int(row.totalProteinG.rounded()))g")
                .font(Theme.Fonts.number(15).monospacedDigit())
                .foregroundStyle(Theme.Colors.primaryText)

            if !row.isSaved {
                HStack(spacing: 4) {
                    Text(row.quantity.formatted())
                        .font(Theme.Fonts.body(13, .semibold))
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                    Stepper(value: $row.quantity, in: 0.25...10, step: 0.25) {
                        EmptyView()
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.quantity.formatted()) servings of \(row.name)")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .tile(radius: Theme.Radius.row, padding: 0)
        .opacity(row.isIncluded && !row.isSaved ? 1 : 0.4)
    }
}
