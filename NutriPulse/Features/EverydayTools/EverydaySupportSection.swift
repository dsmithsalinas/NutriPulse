import SwiftUI

/// Practical support can be browsed without opening a chat or granting AI consent.
struct EverydaySupportSection: View {
    var identifierPrefix = "pulse"
    var showsLighterTracking = true
    @Environment(AppState.self) private var appState
    @State private var expanded = false
    @State private var presentation: Presentation?
    @State private var pendingHandoff: Handoff?
    private enum Route { case offScript, tools, lighter }
    private struct Presentation: Identifiable {
        let id = UUID()
        let route: Route
        let owner: UUID?
    }
    private struct Handoff { let prompt: String; let owner: UUID }
    private var currentOwner: UUID? {
        #if DEBUG
        if DebugLaunch.tour { return appState.session?.user.id ?? AppStoreScreenshotPreview.sampleUser }
        #endif
        return appState.session?.user.id
    }
    var body: some View {
        VStack(spacing: 0) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Make today easier").font(Theme.Fonts.body(16, .bold))
                        Text("Practical tools · no chat required")
                            .font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }.frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("\(identifierPrefix).supportTools.toggle")
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            if expanded {
                VStack(spacing: 0) {
                    action("Today went sideways", symbol: "arrow.triangle.branch", route: .offScript, identifier: "offScript")
                    Divider()
                    action("Everyday tools", symbol: "sparkles", route: .tools, identifier: "everydayTools")
                    if showsLighterTracking {
                        Divider()
                        action(TrackingPreferencesStore.shared.isActive ? "Manage lighter tracking" : "Take it easier",
                               symbol: "leaf", route: .lighter, identifier: "lighterTracking")
                    }
                }.padding(.top, 8)
            }
        }
        .tint(Theme.Colors.primary).foregroundStyle(Theme.Colors.textPrimary)
        .tile(padding: 14).accessibilityElement(children: .contain).accessibilityIdentifier("\(identifierPrefix).supportTools")
        .sheet(item: $presentation, onDismiss: {
            let handoff = pendingHandoff; pendingHandoff = nil
            // Only an explicit Ask Pulse action can produce a handoff.
            guard let handoff, handoff.owner == currentOwner else { return }
            appState.askPulse(handoff.prompt)
        }) { item in
            if item.route == .lighter {
                LighterTrackingSheet()
            } else if let owner = item.owner, owner == currentOwner {
                if item.route == .tools {
                    EverydayToolsView(userId: owner, onAskPulse: { pendingHandoff = .init(prompt: $0, owner: owner) })
                } else {
                    OffScriptSheet(userId: owner, date: .now,
                        onAskPulse: { pendingHandoff = .init(prompt: $0, owner: owner) }, onSaved: {})
                }
            } else {
                VStack(spacing: 16) {
                    Text("Sign in again to open these tools.")
                    Button("Close") { presentation = nil }
                }.padding()
            }
        }
        .onChange(of: appState.session?.user.id) { _, _ in
            pendingHandoff = nil; presentation = nil; expanded = false
        }
    }

    private func action(_ title: String, symbol: String, route destination: Route, identifier: String) -> some View {
        Button {
            pendingHandoff = nil
            presentation = .init(route: destination, owner: currentOwner)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 20)
                Text(title).font(Theme.Fonts.body(14, .semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("\(identifierPrefix).\(identifier)")
    }
}
