import SwiftUI
import UIKit

// Pulse opens on a start screen and never messages first (docs/daylight-redesign.md): a
// greeting, tiles built on the device from today's data, fixed topics, and the last
// conversation. Tapping any of them — or sending from the composer — moves into the
// conversation, which has a "New topic" button back.
struct CoachView: View {
    let isActive: Bool
    @Environment(AppState.self) private var appState
    @Environment(\.tabBarHeight) private var tabBarHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm = CoachViewModel()
    @State private var dictation = DictationRecognizer()
    @AppStorage("chatHistoryVersion") private var chatHistoryVersion = 0
    @FocusState private var isInputFocused: Bool
    @State private var keyboardVisible = false
    @State private var inConversation = false
    @State private var showExperiment: PersonalExperiment?
    @State private var showAboutYou = false

    // The Daylight tab bar floats over content, and SwiftUI doesn't inset this pinned composer
    // by it (with the keyboard up it also rides the keyboard and lands on the composer), so the
    // whole measured bar height is cleared by hand in both states.
    private var composerClearance: CGFloat {
        max(tabBarHeight, 76) + (keyboardVisible ? 0 : 4)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if inConversation {
                        conversation
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        startScreen
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .frame(maxHeight: .infinity)

                composer
                    .padding(.bottom, composerClearance)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            // No navigation bar on either screen, so cover the status bar ourselves or scrolled
            // content slides under the clock.
            .overlay(alignment: .top) {
                // A ShapeStyle background extends into the safe area; a sized view doesn't.
                Color.clear
                    .frame(height: 0)
                    .background(Theme.Colors.ground)
            }
            .toolbar(.hidden, for: .navigationBar)
            // The composer below already clears the tab bar; the tab-wide end margin
            // (MainTabView) would leave a second gap above it.
            .contentMargins(.bottom, 0, for: .scrollContent)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: inConversation)
            .sheet(isPresented: $showAboutYou) {
                NavigationStack { AboutYouView() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = false }
        }
        .onChange(of: isActive) { _, active in
            guard active else {
                dictation.stop()
                return
            }
            activate()
        }
        // `onChange` misses the case where Pulse is already the selected tab when it appears.
        .onAppear {
            if isActive { activate() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard isActive else { return }
            returnToStartIfIdle()
            Task { await vm.refreshStartSuggestions() }
        }
        .onChange(of: appState.pendingCoachPrompt) { _, prompt in
            guard isActive, prompt != nil else { return }
            Task { await consumePendingPrompt() }
        }
        .onChange(of: chatHistoryVersion) {
            inConversation = false
            Task { await vm.reload() }
        }
        // Mirror live dictation into the composer, as Talk to Log does.
        .onChange(of: dictation.transcript) { _, transcript in
            if dictation.isListening { vm.inputText = transcript }
        }
        .onChange(of: dictation.status) { _, status in
            if status == .denied {
                vm.error = "Turn on microphone and speech recognition for Footing in Settings to talk to Pulse."
            }
        }
        .sheet(item: $showExperiment) { experiment in
            ExperimentDetailView(experiment: experiment) {
                await vm.refreshStartSuggestions()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK") { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
    }

    private func activate() {
        returnToStartIfIdle()
        Task {
            // The first load builds the start screen itself; later visits refresh it, since
            // the protein gap and shot day move through the day.
            if !(await vm.loadIfNeeded()) {
                await vm.refreshStartSuggestions()
            }
            await vm.refreshSuggestedPrompts()
            await consumePendingPrompt()
        }
    }

    // Pulse opens to its start screen. Coming back mid-conversation — a reply still loading,
    // or the last message only minutes ago — returns to that conversation instead of dropping it.
    private func returnToStartIfIdle() {
        guard inConversation, !vm.isLoading else { return }
        let lastActivity = vm.visibleMessages.last?.createdAt ?? .distantPast
        if Date.now.timeIntervalSince(lastActivity) > 10 * 60 {
            inConversation = false
        }
    }

    // A prompt handed over from another surface (e.g. the Today nudge) starts its own topic:
    // send it once, then clear it so it can't re-fire on the next tab switch.
    private func consumePendingPrompt() async {
        guard let prompt = appState.pendingCoachPrompt else { return }
        appState.pendingCoachPrompt = nil
        inConversation = true
        await vm.startTopic(prompt)
    }

    // Every path that sends anything to the AI goes through this. Closing the consent sheet
    // leaves you on the Pulse tab, so the tab itself has to hold the line too.
    private func pulseMaySend() -> Bool {
        let store = PulseProfileStore.shared
        if store.pulseActive { return true }
        if store.needsConsent { appState.showPulseConsentSheet = true }
        return false
    }

    private func start(_ suggestion: PulseStartSuggestion) {
        // The experiment tile opens the experiment itself for today's check-in. It sends
        // nothing to the AI, so it isn't gated on Pulse consent.
        if suggestion.kind == .experimentCheckIn {
            showExperiment = vm.runningExperiment
            return
        }
        guard pulseMaySend() else { return }
        dictation.stop()
        inConversation = true
        Task {
            if suggestion.kind == .mondayRecap {
                await vm.requestWeeklyRecap()
            } else {
                await vm.startTopic(suggestion.prompt)
            }
        }
    }

    private func startTopic(_ prompt: String) {
        guard pulseMaySend() else { return }
        dictation.stop()
        inConversation = true
        Task { await vm.startTopic(prompt) }
    }

    private func resume() {
        vm.resumeConversation()
        inConversation = true
    }

    // MARK: - Header

    private func pulseHeader<Trailing: View>(
        titleSize: CGFloat,
        subtitle: String?,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            PulseMark()
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .frame(width: 44, height: 44)
                .background(Theme.Colors.hero, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Pulse")
                    .font(Theme.Fonts.display(titleSize, .extraBold, relativeTo: .title))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
    }

    private var canSeeLine: String {
        vm.hasShotCycle
            ? "I've got today's log, your shot week and your goals."
            : "I've got today's log and your goals."
    }

    // MARK: - Start screen

    private var startScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                pulseHeader(titleSize: 24, subtitle: nil) {
                    if !vm.messages.isEmpty {
                        Button(action: resume) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(Theme.Colors.surfaceCard, in: Circle())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("Past conversations")
                    }
                }
                .popIn(order: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.firstName.map { "What's on your mind, \($0)?" } ?? "What's on your mind?")
                        .font(Theme.Fonts.display(32, .extraBold, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Opens "What Pulse knows" — the one place to see and edit everything
                    // Pulse has been told (docs/daylight-redesign.md, step 8).
                    Button { showAboutYou = true } label: {
                        // Stacked, not side by side: beside the line, the link squeezed it onto two.
                        VStack(alignment: .leading, spacing: 2) {
                            Text(canSeeLine)
                                .font(Theme.Fonts.body(15))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text("What I know about you ›")
                                .font(Theme.Fonts.body(14, .semibold))
                                .foregroundStyle(Theme.Colors.primaryText)
                        }
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("What Pulse knows about you")
                    .accessibilityHint("\(canSeeLine) Opens what Pulse knows, to review or change it.")
                }
                .padding(.top, 6)
                .popIn(order: 1)

                if !vm.startSuggestions.isEmpty {
                    sectionLabel("Suggested for right now")
                        .popIn(order: 2)
                    suggestionGrid
                }

                sectionLabel("Or talk about")
                    .popIn(order: 5)
                topicChips
                    .popIn(order: 5)

                if let last = vm.lastUserMessage {
                    pickUpRow(last)
                        .popIn(order: 6)
                } else if vm.historyLoadFailed {
                    historyRetryRow
                }
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func sectionLabel(_ text: String) -> some View {
        TileEyebrow(text, color: Theme.Colors.textFaint)
            .padding(.top, 4)
            .padding(.leading, 4)
    }

    // One tile spans the full width when there are one or three; two sit side by side.
    private var suggestionGrid: some View {
        let tiles = vm.startSuggestions
        let wideFirst = tiles.count != 2
        let rest = wideFirst ? Array(tiles.dropFirst()) : tiles
        return VStack(spacing: 10) {
            if wideFirst, let first = tiles.first {
                suggestionTile(first, wide: true)
                    .popIn(order: 2)
            }
            if !rest.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(rest.enumerated()), id: \.element.id) { index, tile in
                        suggestionTile(tile, wide: false)
                            .popIn(order: 3 + index)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func suggestionTile(_ suggestion: PulseStartSuggestion, wide: Bool) -> some View {
        let colors = TileColors(suggestion.kind)
        return Button { start(suggestion) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if suggestion.kind == .proteinGap {
                        Text(suggestion.eyebrow)
                            .font(Theme.Fonts.body(12, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.hero, in: Capsule())
                    } else {
                        Text(suggestion.eyebrow)
                            .font(Theme.Fonts.body(12, .bold))
                            .foregroundStyle(colors.label)
                    }
                    Spacer(minLength: 0)
                    if wide {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(colors.label)
                    }
                }
                Spacer(minLength: 0)
                Text(suggestion.prompt)
                    .font(wide ? Theme.Fonts.display(20, .bold, relativeTo: .title3) : Theme.Fonts.body(15, .bold))
                    .foregroundStyle(colors.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: wide ? 104 : 116, maxHeight: .infinity, alignment: .topLeading)
            .background(colors.fill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: colors.shadow ? Color(hex: 0x0F172A, opacity: 0.06) : .clear, radius: 1, y: 1)
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .accessibilityHint(suggestion.kind == .mondayRecap ? "Pulse writes your recap of last week"
                           : suggestion.kind == .experimentCheckIn ? "Opens your experiment to log today"
                           : "Sends this to Pulse")
    }

    private struct TileColors {
        let fill: Color, label: Color, ink: Color, shadow: Bool

        init(_ kind: PulseStartSuggestion.Kind) {
            switch kind {
            case .proteinGap:
                (fill, label, ink, shadow) = (Theme.Colors.heroDeep, Theme.Colors.heroLabel, .white, false)
            case .shotCycle:
                (fill, label, ink, shadow) = (Theme.Colors.lime, Theme.Colors.limeLabel, Theme.Colors.limeInk, false)
            case .mondayRecap:
                (fill, label, ink, shadow) = (Theme.Colors.violet, Theme.Colors.violetLabel, Theme.Colors.violetInk, false)
            case .meal:
                (fill, label, ink, shadow) = (Theme.Colors.surfaceCard, Theme.Colors.textSecondary, Theme.Colors.textPrimary, true)
            // Compile-only for now — CoachViewModel doesn't build this suggestion yet (that
            // wiring is out of scope here; see the personal-experiments handoff notes).
            // Violet matches the experiment tile elsewhere in the app.
            case .experimentCheckIn:
                (fill, label, ink, shadow) = (Theme.Colors.violet, Theme.Colors.violetLabel, Theme.Colors.violetInk, false)
            }
        }
    }

    private var topicChips: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(CoachSuggestionBuilder.topics, id: \.label) { topic in
                Button { startTopic(topic.prompt) } label: {
                    Text(topic.label)
                        .font(Theme.Fonts.body(14, .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressableStyle(scale: 0.95))
                .accessibilityHint("Starts a conversation with Pulse")
            }
        }
    }

    private func pickUpRow(_ last: CoachMessage) -> some View {
        Button(action: resume) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pick up where you left off · \(Self.relativeDay(last.createdAt))")
                        .font(Theme.Fonts.body(12, .semibold))
                        .foregroundStyle(Theme.Colors.textFaint)
                    Text("“\(last.content)”")
                        .font(Theme.Fonts.body(14, .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.textFaint)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .background(Theme.Colors.surfaceCard.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // History didn't load, so there's nothing to pick up — say so rather than silently
    // leaving the row out, and offer the retry the old empty tab had.
    private var historyRetryRow: some View {
        Button {
            Task { await vm.retryInitialLoad() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(Theme.Colors.textFaint)
                Text("Couldn't load past conversations")
                    .font(Theme.Fonts.body(14, .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer(minLength: 0)
                Text("Try again")
                    .font(Theme.Fonts.body(14, .bold))
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .background(Theme.Colors.surfaceCard.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private static func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: - Conversation

    private var conversation: some View {
        VStack(spacing: 0) {
            pulseHeader(
                titleSize: 28,
                subtitle: vm.hasShotCycle ? "Today's log, shot cycle, goals" : "Today's log and goals"
            ) {
                Button {
                    dictation.stop()
                    isInputFocused = false
                    inConversation = false
                    Task { await vm.refreshStartSuggestions() }
                } label: {
                    Label("New topic", systemImage: "plus")
                        .font(Theme.Fonts.body(14, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 40)
                        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 8)
            .padding(.bottom, 8)

            messageList
            if showQuickActions {
                quickActionStrip
            }
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Older pages only matter when the whole history is showing; a new topic
                    // starts after them.
                    if vm.canLoadOlder && vm.visibleMessages.count == vm.messages.count {
                        Button {
                            Task { await vm.loadOlderMessages() }
                        } label: {
                            if vm.isLoadingOlder {
                                ProgressView()
                            } else {
                                Text("Load earlier messages")
                                    .font(.footnote)
                            }
                        }
                        .disabled(vm.isLoadingOlder)
                        .padding(.bottom, 4)
                    }

                    // Without this the conversation is a blank scroll view when the history
                    // fetch fails — no spinner, no error, no way back.
                    if vm.historyLoadFailed && vm.messages.isEmpty && !vm.isLoading {
                        BrandedEmptyState(
                            icon: "wifi.exclamationmark",
                            title: "Can't reach Pulse",
                            message: "Your conversation didn't load. Check your connection and try again."
                        )
                        Button("Try again") {
                            Task { await vm.retryInitialLoad() }
                        }
                        .buttonStyle(.brandPrimary)
                        .padding(.horizontal, Theme.Spacing.xl)
                    }

                    ForEach(vm.visibleMessages) { msg in
                        MessageBubble(message: msg, vm: vm)
                    }
                    if vm.isLoading {
                        PulseTypingIndicator()
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
            }
            // Picking up a long history should land on the newest message, not the oldest.
            .defaultScrollAnchor(.bottom)
            // `.immediately` (not `.interactively`): with the keyboard up the transcript is
            // squeezed into a half window, so the fastest way back to the full conversation
            // should be to start scrolling it. Tapping the transcript dismisses too.
            .scrollDismissesKeyboard(.immediately)
            .contentShape(Rectangle())
            // Simultaneous, not `.onTapGesture`: a plain tap gesture on the ScrollView can
            // swallow taps meant for "Load earlier messages" and the bubbles.
            .simultaneousGesture(TapGesture().onEnded { isInputFocused = false })
            // Keyed on the newest message, not the count: prepending a page of older
            // messages changes the count too, and would yank the user back to the bottom
            // of the conversation they just scrolled up from.
            .onChange(of: vm.messages.last?.id) {
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom") }
            }
            .onChange(of: vm.isLoading) { _, loading in
                if loading {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom") }
                }
            }
        }
    }

    // MARK: - Quick actions

    // The newest assistant message's own follow-ups take over the strip when it has them
    // (docs/daylight-redesign.md: "follow-up chips"); otherwise the device-built suggestions
    // from before structured replies. See `PulseChipSource`.
    private var activeChips: [String] {
        PulseChipSource.chips(latestMessage: vm.visibleMessages.last, fallback: vm.suggestedPrompts)
    }

    private var showQuickActions: Bool {
        !activeChips.isEmpty && !vm.isLoading
    }

    private var quickActionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(activeChips, id: \.self) { action in
                    Button {
                        guard pulseMaySend() else { return }
                        Task { await vm.sendMessage(action) }
                    } label: {
                        Text(action)
                            .font(Theme.Fonts.body(13, .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(Theme.Colors.primaryText)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityHint("Sends this message to Pulse")
                }
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Composer

    private var trimmedInput: String {
        vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var composer: some View {
        VStack(spacing: 7) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField(inConversation ? "Ask Pulse…" : "Ask Pulse anything", text: $vm.inputText, axis: .vertical)
                    .font(Theme.Fonts.body(15))
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(minHeight: 52)
                    .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(dictation.isListening ? Theme.Colors.primary : Theme.Colors.hairline, lineWidth: 2)
                    }
                    .accessibilityLabel("Message Pulse")

                // Explicit way out of the keyboard. Only while editing, so it doesn't clutter
                // the resting state — and it lives here rather than in a `.keyboard` toolbar,
                // which the tab bar would cover.
                if isInputFocused {
                    Button { isInputFocused = false } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textFaint)
                            .frame(width: 32, height: 52)
                    }
                    .accessibilityLabel("Hide keyboard")
                    .transition(.scale.combined(with: .opacity))
                }

                composerAction
            }

            // Pulse is a coach, not a clinician. A persistent, low-key reminder here keeps that
            // clear at the exact moment a user might ask it something medical.
            Text("Pulse is a wellness coach, not a medical professional. Not medical advice.")
                .font(Theme.Fonts.body(11))
                .foregroundStyle(Theme.Colors.textFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Theme.Spacing.page)
        .padding(.top, 8)
    }

    // One button: the mic while the box is empty, stop while listening, send once there's text.
    private var composerAction: some View {
        let hasText = !trimmedInput.isEmpty
        let listening = dictation.isListening
        return Button {
            if listening {
                dictation.stop()
            } else if hasText {
                send()
            } else {
                Task { await dictation.start() }
            }
        } label: {
            Image(systemName: listening ? "stop.fill" : hasText ? "arrow.up" : "mic.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    hasText && vm.isLoading && !listening ? Theme.Colors.textFaint : Theme.Colors.primary,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.pressable)
        .disabled(hasText && vm.isLoading && !listening)
        .accessibilityLabel(listening ? "Stop listening" : hasText ? "Send" : "Talk to Pulse")
    }

    private func send() {
        guard pulseMaySend() else { return }
        let text = trimmedInput
        guard !text.isEmpty, !vm.isLoading else { return }
        if inConversation {
            Task { await vm.sendMessage() }
        } else {
            inConversation = true
            Task { await vm.startTopic(text) }
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: CoachMessage
    let vm: CoachViewModel

    var body: some View {
        // A recap replaces the plain bubble outright (docs/daylight-redesign.md: "the weekly
        // summary as a structured card"); a message without one — including the plain-text
        // fallback when structured outputs didn't come back — keeps today's bubble.
        if let recap = message.payload?.recap {
            RecapCard(message: message, recap: recap, vm: vm)
                .padding(.horizontal, 12)
        } else {
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 6) {
                    if message.isUser {
                        Spacer(minLength: 48)
                        bubbleText
                    } else {
                        pulseAvatar
                        bubbleText
                        Spacer(minLength: 48)
                    }
                }

                if let foods = message.payload?.foods, !foods.isEmpty {
                    FoodSuggestionCards(foods: foods, vm: vm)
                }
                if !message.isUser {
                    RememberSuggestionCards(message: message, vm: vm)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    // `Text(String)` does not parse markdown — only the LocalizedStringKey initializer
    // does. The system prompt permits bullet lists and never bans **bold**, which Claude
    // uses freely, so assistant replies rendered literal asterisks. Parsing inline-only
    // keeps line breaks intact (`.inlineOnlyPreservingWhitespace`), and any content that
    // fails to parse falls back to the raw string rather than disappearing.
    private var attributedContent: AttributedString {
        (try? AttributedString(
            markdown: message.content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(message.content)
    }

    private var bubbleText: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let contextLabel = message.automaticContextLabel {
                Text(contextLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(message.isUser ? .white.opacity(0.8) : Theme.Colors.textFaint)
            }
            Text(attributedContent)
        }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background {
                // Daylight: user bubbles are a solid indigo fill; Pulse bubbles stay white tiles.
                if message.isUser {
                    Theme.Colors.hero
                } else {
                    Theme.Colors.surfaceCard
                }
            }
            .foregroundStyle(message.isUser ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if !message.isUser {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
                }
            }
    }

    private var pulseAvatar: some View { PulseAvatar() }
}

// MARK: - Food suggestion cards

// Sits under an assistant bubble that suggested foods the user already eats
// (docs/daylight-redesign.md: "one-tap food cards, from frequently logged foods"). A name that
// doesn't resolve to a recent log is dropped rather than shown as a dead card.
private struct FoodSuggestionCards: View {
    let foods: [CoachMessagePayload.FoodSuggestion]
    let vm: CoachViewModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(foods) { food in
                if let log = vm.resolveFoodLog(named: food.name) {
                    FoodSuggestionCard(food: food, log: log, vm: vm)
                }
            }
        }
        .padding(.leading, 34)
        .padding(.trailing, 48)
    }
}

private struct FoodSuggestionCard: View {
    let food: CoachMessagePayload.FoodSuggestion
    let log: FoodLog
    let vm: CoachViewModel

    @State private var isLogging = false
    @State private var didLog = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(Theme.Fonts.body(14, .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                if !food.why.isEmpty {
                    Text(food.why)
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Button {
                guard !isLogging, !didLog else { return }
                Task {
                    isLogging = true
                    let ok = await vm.logSuggestedFood(log)
                    isLogging = false
                    if ok {
                        didLog = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            } label: {
                Group {
                    if isLogging {
                        ProgressView().tint(.white)
                    } else if didLog {
                        Image(systemName: "checkmark")
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.Colors.hero, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.pressable)
            .disabled(isLogging || didLog)
            .accessibilityLabel(didLog ? "Logged \(food.name)" : "Log \(food.name)")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(didLog ? 0.7 : 1)
    }
}

// MARK: - "Save to what Pulse knows?" cards

// Sits under an assistant bubble that just heard something about the user
// (docs/daylight-redesign.md, step 8) — 0–2 cards, already deduped server-side against what's
// saved. Saving keeps the card but shows "Saved"; "Not now" removes it. Allergies are never
// saved except by this explicit tap.
private struct RememberSuggestionCards: View {
    let message: CoachMessage
    let vm: CoachViewModel

    var body: some View {
        let suggestions = vm.rememberCards(for: message)
        if !suggestions.isEmpty {
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    RememberSuggestionCard(suggestion: suggestion, message: message, vm: vm)
                }
            }
            .padding(.leading, 34)
            .padding(.trailing, 48)
        }
    }
}

private struct RememberSuggestionCard: View {
    let suggestion: PulseRememberSuggestion
    let message: CoachMessage
    let vm: CoachViewModel

    var body: some View {
        let isSaving = vm.rememberIsSaving(suggestion, in: message)
        let isSaved = vm.rememberIsSaved(suggestion, in: message)

        VStack(alignment: .leading, spacing: 8) {
            Text("Save to what Pulse knows?")
                .font(Theme.Fonts.body(11, .bold))
                .textCase(.uppercase)
                .tracking(Theme.Typography.eyebrowTracking)
                .foregroundStyle(Theme.Colors.textFaint)

            HStack(spacing: 10) {
                Text(suggestion.label)
                    .font(Theme.Fonts.body(14, .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                if isSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                } else {
                    HStack(spacing: 6) {
                        Button("Not now") {
                            vm.dismissRememberSuggestion(suggestion, in: message)
                        }
                        .buttonStyle(.plain)
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Not now")
                        .accessibilityHint("Don't save \(suggestion.label) to what Pulse knows")

                        Button {
                            guard !isSaving else { return }
                            Task { await vm.saveRememberSuggestion(suggestion, in: message) }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Save")
                                }
                            }
                            .font(Theme.Fonts.body(13, .bold))
                            .foregroundStyle(.white)
                            .fixedSize()
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(Theme.Colors.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.pressable)
                        .disabled(isSaving)
                        .accessibilityLabel("Save")
                        .accessibilityHint("Saves \(suggestion.label) to what Pulse knows")
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Weekly recap card

// Replaces the plain bubble for a message with a `recap` payload (docs/daylight-redesign.md:
// "the weekly summary as a structured card (story, went well, pattern, focus, a 7-day bar
// chart)"). The four text fields are Pulse's; the chart is always built from the app's own data.
private struct RecapCard: View {
    let message: CoachMessage
    let recap: CoachMessagePayload.Recap
    let vm: CoachViewModel

    private var interval: (start: Date, end: Date, priorStart: Date) {
        WeeklyRecapSchedule.lastWeek(before: message.createdAt)
    }

    private var rangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: interval.start)) – \(formatter.string(from: interval.end))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Monday recap")
                    .font(Theme.Fonts.body(12, .bold))
                    .foregroundStyle(Theme.Colors.violetLabel)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Theme.Colors.violet, in: Capsule())
                Spacer(minLength: 0)
                Text(rangeLabel)
                    .font(Theme.Fonts.body(13, .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityLabel("Week of \(rangeLabel)")
            }

            Text(recap.story)
                .font(Theme.Fonts.display(21, .bold, relativeTo: .title3))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            WeeklyProteinBars(chart: vm.recapChart(for: message))
                .task { await vm.loadRecapChartIfNeeded(for: message) }

            HStack(alignment: .top, spacing: 10) {
                recapRow(title: "Went well", text: recap.wentWell, fill: Theme.Colors.lime, label: Theme.Colors.limeLabel, ink: Theme.Colors.limeInk)
                recapRow(title: "Pattern", text: recap.pattern, fill: Theme.Colors.violet, label: Theme.Colors.violetLabel, ink: Theme.Colors.violetInk)
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "scope")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Theme.NutrientColor.fat, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week's focus")
                        .font(Theme.Fonts.body(12, .bold))
                        .textCase(.uppercase)
                        .tracking(Theme.Typography.eyebrowTracking)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(recap.focus)
                        .font(Theme.Fonts.body(14))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.NutrientColor.fat.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(18)
        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color(hex: 0x0F172A, opacity: 0.06), radius: 1, y: 1)
    }

    private func recapRow(title: String, text: String, fill: Color, label: Color, ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Fonts.body(12, .bold))
                .textCase(.uppercase)
                .tracking(Theme.Typography.eyebrowTracking)
                .foregroundStyle(label)
            Text(text)
                .font(Theme.Fonts.body(14))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// The 7-day protein bar chart (Mon–Sun, `WeeklyRecapSchedule.lastWeek`), built entirely from the
// app's own local data — Pulse never supplies these numbers. A day with no log shows an empty
// track rather than a zero-height bar read as a miss. Bars draw in once, honoring Reduce Motion.
private struct WeeklyProteinBars: View {
    let chart: CoachViewModel.RecapChartData?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    private static let barHeight: CGFloat = 88

    private var days: [CoachContextBundle.LastWeekContext.Day] { chart?.days ?? [] }

    // Before the async load finishes, seven bare tracks hold the layout so the card doesn't pop
    // from blank to full height once the fetch completes.
    private var slotCount: Int { chart == nil ? 7 : days.count }

    private var maxValue: Double {
        max(chart?.goalProteinG ?? 0, Double(days.compactMap(\.proteinG).max() ?? 0), 1)
    }

    private var goalFraction: Double? {
        guard let goal = chart?.goalProteinG, goal > 0 else { return nil }
        return min(goal / maxValue, 1)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<slotCount, id: \.self) { index in
                        let day = days.indices.contains(index) ? days[index] : nil
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Theme.Colors.surfaceInset)
                                .frame(maxWidth: .infinity)
                                .frame(height: Self.barHeight)
                            if let proteinG = day?.proteinG {
                                let fraction = min(Double(proteinG) / maxValue, 1)
                                Capsule()
                                    .fill(day?.proteinFloorHit == true ? Theme.Colors.hero : Theme.Colors.heroLabel)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: (grown || reduceMotion) ? Self.barHeight * fraction : 0)
                            }
                        }
                    }
                }
                if let goalFraction {
                    Rectangle()
                        .fill(Theme.Colors.textFaint.opacity(0.6))
                        .frame(height: 1)
                        .offset(y: -Self.barHeight * goalFraction)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: Self.barHeight)

            HStack(spacing: 8) {
                ForEach(0..<slotCount, id: \.self) { index in
                    Text(days.indices.contains(index) ? String(days[index].day.prefix(1)) : "")
                        .font(Theme.Fonts.body(11, .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Protein by day")
        .accessibilityValue(accessibilitySummary)
        .onAppear {
            guard !grown, !reduceMotion else { grown = true; return }
            withAnimation(Theme.Motion.draw.delay(0.3)) { grown = true }
        }
    }

    private var accessibilitySummary: String {
        guard !days.isEmpty else { return "Not enough data yet" }
        return days.map { day in
            if let proteinG = day.proteinG {
                return "\(day.day): \(proteinG) grams" + (day.proteinFloorHit == true ? ", floor met" : "")
            }
            return "\(day.day): no log"
        }.joined(separator: "; ")
    }
}

// The brand mark on a solid indigo rounded square — reads as an avatar, not the loading spinner
// the bare ring used to look like mid-chat.
private struct PulseAvatar: View {
    var body: some View {
        PulseMark()
            .foregroundStyle(.white)
            .padding(6)
            .frame(width: 28, height: 28)
            .background(Theme.Colors.hero, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Typing indicator

private struct PulseTypingIndicator: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            pulseAvatar
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.2 : 0.85)
                        .opacity(phase == i ? 1.0 : 0.4)
                        .animation(.easeInOut(duration: 0.3), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .card()
            Spacer()
        }
        .padding(.horizontal, 12)
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }

    private var pulseAvatar: some View { PulseAvatar() }
}
