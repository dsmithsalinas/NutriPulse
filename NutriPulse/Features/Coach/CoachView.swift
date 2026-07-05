import SwiftUI

struct CoachView: View {
    let isActive: Bool
    @State private var vm = CoachViewModel()
    @AppStorage("chatHistoryVersion") private var chatHistoryVersion = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                if showQuickActions {
                    quickActionStrip
                }
                Divider()
                inputBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image("PulseMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("Pulse")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
            }
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            Task { await vm.loadIfNeeded() }
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

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
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
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) {
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.primary.opacity(0.08))
                            .foregroundStyle(Theme.Colors.primary)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Theme.Colors.primary.opacity(0.25), lineWidth: 1))
                    }
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
        HStack(spacing: 8) {
            TextField("Ask Pulse…", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await vm.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(sendButtonActive ? Theme.Colors.primary : Color.secondary)
            }
            .disabled(!sendButtonActive)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.background)
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

    private var bubbleText: some View {
        Text(message.content)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if message.isUser {
                    Theme.Colors.primaryGradient
                } else {
                    Theme.Colors.surface
                }
            }
            .foregroundStyle(message.isUser ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var pulseAvatar: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.primary.opacity(0.12))
                .frame(width: 28, height: 28)
            Image("PulseMark")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        }
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

    private var pulseAvatar: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.primary.opacity(0.12))
                .frame(width: 28, height: 28)
            Image("PulseMark")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        }
    }
}
