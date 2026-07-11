import SwiftUI
import UIKit

// The weekly injection, made a moment: a living aurora, a press-and-hold orb, an optional dose
// change (medication-aware ladder), and a warm bloom + confirmation. Logs today's shot and
// schedules the next reminder. Presented full-screen from the dose-day card on Today.
struct InjectionRitualView: View {
    let latest: GLP1Log?
    var onLogged: (GLP1Log) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm = InjectionRitualViewModel()

    @State private var updateGoingForward = true
    @State private var showDoseSheet = false
    @State private var doseBeforeSheet: Double = 0

    // hold-to-log state
    @State private var holdProgress: CGFloat = 0
    @State private var isHolding = false
    @State private var didConfirm = false
    @State private var bloom = false
    @State private var breathing = false
    @State private var confirmWork: DispatchWorkItem?

    private let holdDuration: Double = 1.2

    var body: some View {
        ZStack {
            AuroraView()
                .scaleEffect(bloom ? 1.4 : 1)
                .animation(.easeOut(duration: 0.9), value: bloom)

            RadialGradient(colors: [.clear, .black.opacity(0.5)],
                           center: .center, startRadius: 130, endRadius: 470)
                .allowsHitTesting(false)

            if didConfirm { confirmation } else { ritualContent }

            VStack {
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .opacity(didConfirm ? 0 : 1)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .task { vm.load(from: latest) }
        .onAppear { breathing = true }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        .sheet(isPresented: $showDoseSheet) {
            doseSheet
                .presentationDetents([.height(400)])
                .presentationBackground(Color(hex: 0x16141F))
        }
    }

    // MARK: Ritual content

    private var ritualContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 78)
            Text("SHOT DAY")
                .font(.system(size: 12, weight: .bold)).tracking(3)
                .foregroundStyle(.white.opacity(0.72))
            Text("\(vm.medication.rawValue) \u{00B7} \(vm.doseMg.glp1DoseString) mg")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(.white).padding(.top, 6)
            Text("Rotate site \u{2014} suggested \(vm.site.rawValue)")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.72)).padding(.top, 3)

            Button {
                doseBeforeSheet = vm.doseMg
                showDoseSheet = true
            } label: {
                Label("Change dose", systemImage: "pencil")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13).padding(.vertical, 6)
                    .background(.white.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.26)))
            }
            .padding(.top, 11)

            Spacer()
            orb
            Spacer()

            siteChips.padding(.bottom, 10)
            Text(isHolding ? "Keep holding\u{2026}" : "Press and hold to log")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 44)
        }
        .padding(.horizontal, 24)
    }

    private var orb: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.16), lineWidth: 5)
            Circle().trim(from: 0, to: holdProgress)
                .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0xCFD0FF), Color(hex: 0x7C7EF7), Color(hex: 0x8B5CF6)],
                    center: UnitPoint(x: 0.36, y: 0.3), startRadius: 4, endRadius: 90))
                .frame(width: 150, height: 150)
                .shadow(color: Color(hex: 0x8B5CF6).opacity(0.55), radius: 42)
                .scaleEffect(isHolding ? 1.09 : (breathing && !reduceMotion ? 1.045 : 1))
                .animation(reduceMotion ? nil : .easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: breathing)
                .animation(.easeOut(duration: 0.2), value: isHolding)
                .overlay {
                    Text(isHolding ? "Hold\u{2026}" : "Hold to\nlog dose")
                        .font(.system(size: 13, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                }
        }
        .frame(width: 210, height: 210)
        .contentShape(Circle())
        .gesture(holdGesture)
    }

    private var siteChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InjectionSite.allCases) { s in
                    let on = s == vm.site
                    Button { vm.site = s } label: {
                        Text(s.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(on ? 1 : 0.8))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.white.opacity(on ? 0.18 : 0.06), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(on ? 0.5 : 0.2)))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: Confirmation

    private var confirmation: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(.white.opacity(0.16)).frame(width: 92, height: 92)
                    .overlay(Circle().strokeBorder(.white.opacity(0.4)))
                Image(systemName: "checkmark").font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
            }
            .shadow(color: .white.opacity(0.35), radius: 40)
            Text("Logged.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white).padding(.top, 22)
            Text("Next dose \(nextDoseText). You\u{2019}re protecting your progress. \u{1F4AA}")
                .font(.system(size: 15)).foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center).frame(maxWidth: 260).padding(.top, 8)
            Text("Reminder set \u{00B7} 7 days")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(.white.opacity(0.12), in: Capsule()).padding(.top, 22)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 24).padding(.bottom, 44)
        }
        .transition(.opacity)
    }

    private var nextDoseText: String {
        let due = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: due)
    }

    // MARK: Dose sheet

    private var doseSheet: some View {
        VStack(spacing: 16) {
            Capsule().fill(.white.opacity(0.22)).frame(width: 40, height: 5).padding(.top, 10)
            Text(vm.medication.rawValue == "Saxenda" ? "Today\u{2019}s dose" : "This week\u{2019}s dose")
                .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            Text("Changed your dose? Set it for this shot.")
                .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.58))

            HStack(spacing: 20) {
                stepper("minus", enabled: vm.canStepDown) { vm.stepDose(-1) }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(vm.doseMg.glp1DoseString)
                        .font(.system(size: 42, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("mg").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                .frame(minWidth: 120).foregroundStyle(.white)
                stepper("plus", enabled: vm.canStepUp) { vm.stepDose(1) }
            }
            .padding(.top, 4)

            Toggle(isOn: $updateGoingForward) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Make this my dose going forward")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    Text("Updates your profile \u{2014} we\u{2019}ll use it for your next shots too.")
                        .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.55))
                }
            }
            .tint(Color(hex: 0x8B5CF6))
            .padding(12)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 10) {
                Button("Cancel") { vm.doseMg = doseBeforeSheet; showDoseSheet = false }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    .padding(.vertical, 15).padding(.horizontal, 22)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
                Button("Set dose") { showDoseSheet = false }
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(LinearGradient(colors: [Color(hex: 0x6366F1), Color(hex: 0x8B5CF6)],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 15))
            }
        }
        .padding(.horizontal, 22).padding(.bottom, 24)
    }

    private func stepper(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.18)))
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    // MARK: Hold gesture

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isHolding, !didConfirm else { return }
                beginHold()
            }
            .onEnded { _ in endHold() }
    }

    private func beginHold() {
        isHolding = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.linear(duration: holdDuration)) { holdProgress = 1 }
        let work = DispatchWorkItem { confirm() }
        confirmWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: work)
    }

    private func endHold() {
        guard !didConfirm else { return }
        isHolding = false
        confirmWork?.cancel(); confirmWork = nil
        withAnimation(.easeOut(duration: 0.25)) { holdProgress = 0 }
    }

    private func confirm() {
        guard !didConfirm else { return }
        isHolding = false
        confirmWork = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
            didConfirm = true
            bloom = true
        }
        Task {
            if let saved = await vm.confirm(updateGoingForward: updateGoingForward) {
                onLogged(saved)
                try? await Task.sleep(for: .seconds(2.8))
                dismiss()
            } else {
                withAnimation { didConfirm = false; bloom = false; holdProgress = 0 }
            }
        }
    }
}
