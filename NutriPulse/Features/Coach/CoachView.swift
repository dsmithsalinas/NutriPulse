import SwiftUI
import UIKit

struct CoachView: View {
    let isActive: Bool
    @Environment(AppState.self) private var appState
    @Environment(\.tabBarHeight) private var tabBarHeight
    @State private var vm = CoachViewModel()
    @AppStorage("chatHistoryVersion") private var chatHistoryVersion = 0
    @FocusState private var isInputFocused: Bool
    @State private var keyboardVisible = false

    // With the keyboard down, only the raised Log (+) juts into content, so a modest gap does
    // it. With the keyboard up, SwiftUI stops insetting content by the tab bar entirely and the
    // bar lands right on top of the composer — hiding the text and the keyboard's Done button —
    // so the whole bar height has to be cleared by hand. Measured, so Dynamic Type still works.
    private var composerClearance: CGFloat {
        keyboardVisible ? max(tabBarHeight, 96) : 48
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                if showQuickActions {
                    quickActionStrip
                }
                Divider()
                inputBar
                    .padding(.bottom, composerClearance)
                    // Paint the clearance too, so the composer, the gap and the tab bar read as
                    // one surface instead of a band of `ground` stranded between two cards.
                    .background(Theme.Colors.surfaceCard)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 7) {
                        PulseMark()
                            .foregroundStyle(Theme.Colors.primary)
                            .frame(width: 19, height: 19)
                        Text("Pulse")
                            .fontWeight(.semibold)
                    }
                }
                // No `.keyboard` toolbar item here: the tab bar sits in exactly that strip above
                // the keyboard, so a Done button lands on top of it and reads as broken. The
                // composer carries its own dismiss control instead.
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = false }
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            Task {
                await vm.loadIfNeeded()
                await consumePendingPrompt()
            }
        }
        .onChange(of: appState.pendingCoachPrompt) { _, prompt in
            guard isActive, prompt != nil else { return }
            Task { await consumePendingPrompt() }
        }
        .onChange(of: chatHistoryVersion) {
            Task { await vm.reload() }
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

    // A prompt handed over from another surface (e.g. the Today nudge): send it once, then
    // clear it so it can't re-fire on the next tab switch.
    private func consumePendingPrompt() async {
        guard let prompt = appState.pendingCoachPrompt else { return }
        appState.pendingCoachPrompt = nil
        await vm.sendMessage(prompt)
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if vm.canLoadOlder {
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

                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg)
                    }
                    if vm.isLoading {
                        PulseTypingIndicator()
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
            }
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

    private var showQuickActions: Bool {
        !vm.messages.contains { $0.isUser } && !vm.isLoading
    }

    private var quickActionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickActions, id: \.self) { action in
                    Button {
                        Task { await vm.sendMessage(action) }
                    } label: {
                        Text(action)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.Colors.primary.opacity(0.1))
                            .foregroundStyle(Theme.Colors.primary)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Theme.Colors.primary.opacity(0.28), lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private let quickActions = [
        "How did I do today?",
        "Am I hitting my protein goal?",
        "What should I eat for dinner?",
        "How's my week looking?",
        "I just worked out — what should I eat?",
        "Why isn't my weight moving?"
    ]

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                TextField("Ask Pulse…", text: $vm.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.surfaceInset)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
                    }

                // Explicit way out of the keyboard. Only while editing, so it doesn't clutter
                // the resting state — and it lives here rather than in a `.keyboard` toolbar,
                // which the tab bar would cover.
                if isInputFocused {
                    Button { isInputFocused = false } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textFaint)
                    }
                    .accessibilityLabel("Hide keyboard")
                    .transition(.scale.combined(with: .opacity))
                }

                Button {
                    Task { await vm.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(sendButtonActive ? AnyShapeStyle(Theme.Colors.primaryGradient) : AnyShapeStyle(Color.secondary))
                }
                .disabled(!sendButtonActive)
            }

            // Pulse is a coach, not a clinician. A persistent, low-key reminder here keeps that
            // clear at the exact moment a user might ask it something medical.
            Text("Pulse is a wellness coach, not a medical professional. Not medical advice.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Colors.surfaceCard)
    }

    private var sendButtonActive: Bool {
        !vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty && !vm.isLoading
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: CoachMessage

    var body: some View {
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
        .padding(.horizontal, 12)
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
        Text(attributedContent)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background {
                if message.isUser {
                    Theme.Colors.primaryGradient
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

// The brand mark on a solid gradient tile — reads as an avatar, not the loading spinner the
// bare ring used to look like mid-chat.
private struct PulseAvatar: View {
    var body: some View {
        PulseMark()
            .foregroundStyle(.white)
            .padding(6)
            .frame(width: 28, height: 28)
            .background(Theme.Colors.primaryGradient, in: Circle())
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
