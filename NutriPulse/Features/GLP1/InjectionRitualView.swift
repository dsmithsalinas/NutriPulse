import SwiftUI
import UIKit

// The Daylight "Shot day" screen (docs/daylight-redesign.md): a lime full-screen page with a
// slowly rotating orbit ring, the dose card, the hold-to-log button, site rotation, and the next
// shot's schedule. Logs today's shot and schedules the next reminder. Presented full-screen from
// the dose-day card on Today.
struct InjectionRitualView: View {
    let latest: GLP1Log?
    var onLogged: (GLP1Log) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var vm = InjectionRitualViewModel()

    @State private var updateGoingForward = true
    /// The site the rotation suggested when this screen opened — captured once so the "next"
    /// badge stays put even if the user taps a different site.
    @State private var suggestedSite: InjectionSite = .leftAbdomen

    @State private var didConfirm = false
    @State private var isSaving = false
    /// Bumped to give `HoldToConfirmButton` a fresh identity (and so a fresh internal state
    /// machine) after a failed save, so the user can hold again.
    @State private var holdResetID = UUID()

    var body: some View {
        ZStack {
            if didConfirm { confirmation } else { ritualContent }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.Colors.lime
                OrbitRing()
            }
            .ignoresSafeArea()
        }
        // The screen is lime in either theme, so its white tiles, close button and site chips
        // keep their light colours too. In dark mode they turned navy on lime, and the close
        // button became a dark ✕ on a dark circle.
        .environment(\.colorScheme, .light)
        .task {
            vm.load(from: latest)
            suggestedSite = vm.site
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
    }

    // MARK: Ritual content

    private var ritualContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                    .popIn(order: 0)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Shot day")
                        .font(Theme.Fonts.display(38, .extraBold, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.Colors.limeInk)
                        .accessibilityAddTraits(.isHeader)
                    Text("The shot does its part. Log it when it\u{2019}s done and I\u{2019}ll plan the week around it.")
                        .font(Theme.Fonts.body(16, .medium))
                        .foregroundStyle(Theme.Colors.limeLabel)
                }
                .popIn(order: 0)

                doseCard
                    .popIn(order: 1)

                Spacer(minLength: 20)
                holdButton
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 20)

                siteSection
                    .popIn(order: 2)

                nextShotRow
                    .popIn(order: 3)
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .frame(minHeight: 640)
        }
    }

    private var header: some View {
        HStack {
            Text(weekdayChipText)
                .font(Theme.Fonts.body(13, .bold))
                .foregroundStyle(Theme.Colors.limeLabel)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Theme.Colors.limeInk.opacity(0.1), in: Capsule())
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Colors.limeInk)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceCard, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Close")
        }
    }

    private var weekdayChipText: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: .now)
    }

    private var holdButton: some View {
        HoldToConfirmButton(
            duration: 1.5,
            label: Text("Hold to\nlog dose"),
            accessibilityLabel: "Log dose",
            accessibilityHint: "\(vm.medication.rawValue), \(vm.doseMg.glp1DoseString) milligrams, in \(vm.site.rawValue). Double tap to log immediately.",
            onConfirm: handleConfirm
        )
        .id(holdResetID)
    }

    // MARK: This dose

    private var doseCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This dose")
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(Theme.Colors.limeLine)
                    Text("\(vm.medication.rawValue) \u{00B7} \(vm.doseMg.glp1DoseString) mg")
                        .font(Theme.Fonts.number(20, .bold, relativeTo: .title3))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                Spacer(minLength: 8)
                doseStepper("minus", enabled: vm.canStepDown, label: "Lower dose") { vm.stepDose(-1) }
                doseStepper("plus", enabled: vm.canStepUp, label: "Raise dose") { vm.stepDose(1) }
            }

            // Only once the dose differs from the regular one — with nothing changed, the
            // toggle asks a question that has no answer (the old dose sheet had the same rule).
            if vm.doseChangedFromRegular {
            HStack {
                Spacer()
                Toggle(isOn: $updateGoingForward) {
                    Text("Set as my regular dose")
                        .font(Theme.Fonts.body(12, .semibold))
                        .foregroundStyle(Theme.Colors.limeLine)
                }
                .tint(Theme.Colors.limeInk)
                .fixedSize()
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: vm.doseChangedFromRegular)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func doseStepper(_ icon: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    // MARK: Site

    private var siteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TileEyebrow("Site", color: Theme.Colors.limeLabel)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                ForEach(InjectionSite.allCases) { site in
                    siteChip(site)
                }
            }
        }
    }

    private func siteChip(_ site: InjectionSite) -> some View {
        let selected = site == vm.site
        let isSuggested = site == suggestedSite
        return Button {
            vm.site = site
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(isSuggested ? "\(site.rawValue) \u{00B7} next" : site.rawValue)
                .font(Theme.Fonts.body(14, selected ? .bold : .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.Colors.limeInk, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(isSuggested ? "\(site.rawValue), suggested next site" : site.rawValue)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: Next shot

    private var nextShotRow: some View {
        HStack {
            Text("Next shot")
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(Theme.Colors.limeLabel)
            Spacer()
            Text("\(prospectiveNextDueText) \u{00B7} reminder 9:00 AM")
                .font(Theme.Fonts.body(14, .bold))
                .foregroundStyle(Theme.Colors.limeInk)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var prospectiveNextDueText: String {
        let due = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: due)
    }

    // MARK: Confirmation

    private var confirmation: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Theme.Colors.limeInk).frame(width: 92, height: 92)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Theme.Colors.lime)
            }
            .shadow(color: Theme.Colors.limeInk.opacity(0.25), radius: 30, y: 12)
            Text("Logged.")
                .font(Theme.Fonts.display(30, .extraBold, relativeTo: .title))
                .foregroundStyle(Theme.Colors.limeInk)
                .padding(.top, 20)
            Text("Next dose \(nextDoseText). You\u{2019}re protecting your progress.")
                .font(Theme.Fonts.body(15, .medium))
                .foregroundStyle(Theme.Colors.limeLabel)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .padding(.top, 6)
            Text("Reminder set \u{00B7} 7 days")
                .font(Theme.Fonts.body(13, .bold))
                .foregroundStyle(Theme.Colors.limeInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.6), in: Capsule())
                .padding(.top, 18)
            Spacer()
            Button("Done") { dismiss() }
                .font(Theme.Fonts.body(16, .bold))
                .foregroundStyle(Theme.Colors.lime)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.Colors.limeInk, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.bottom, 24)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isHeader)
    }

    private var nextDoseText: String {
        let due = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: due)
    }

    // MARK: Save

    private func handleConfirm() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            if let saved = await vm.confirm(updateGoingForward: updateGoingForward) {
                isSaving = false
                withAnimation(Theme.Motion.pop) { didConfirm = true }
                onLogged(saved)
                try? await Task.sleep(for: .seconds(2.2))
                dismiss()
            } else {
                isSaving = false
                // vm.errorMessage drives the alert above; give the hold button a fresh identity
                // so its internal state machine resets and the user can hold again.
                holdResetID = UUID()
            }
        }
    }
}

/// The mockup's dashed circle slowly rotating behind the whole screen. Static under Reduce
/// Motion.
private struct OrbitRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotated = false

    var body: some View {
        Circle()
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
            .foregroundStyle(Theme.Colors.limeInk.opacity(0.12))
            .frame(width: 640, height: 640)
            .rotationEffect(.degrees(rotated ? 360 : 0))
            .offset(x: -190, y: -160)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                    rotated = true
                }
            }
    }
}
