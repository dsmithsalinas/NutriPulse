import SwiftUI

struct SummaryStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onComplete: () -> Void

    private var firstName: String {
        vm.fullName.split(separator: " ").first.map(String.init) ?? "there"
    }

    var body: some View {
        let goals = vm.calculatedGoals
        ZStack {
            Theme.Colors.ground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    OnboardingPulseAvatar(size: 96)
                        .padding(.top, 24)

                    Text("So great to meet you, \(firstName).")
                        .font(.system(size: 27, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)

                    Text("Here's where we're starting. I'm ready when you are — anytime you need me, just say the word.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 9)
                        .padding(.horizontal, 8)

                    targetsCard(goals)
                        .padding(.top, 22)

                    Text("You can fine-tune these anytime in Settings.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.Colors.textFaint)
                        .padding(.top, 12)

                    Text("NutriPulse is a wellness tracker, not a medical device, and Pulse is not a medical professional. Nothing here is medical advice — always talk to your doctor about medication and health decisions.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.Colors.textFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Button(vm.isLoading ? "Saving…" : "Start tracking", action: onComplete)
                .buttonStyle(.brandPrimary)
                .disabled(vm.isLoading)
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
                .background(.bar)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func targetsCard(_ goals: CalculatedGoals) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(Int(goals.calories))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.NutrientColor.calories)
                Text("calories / day")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)

            Divider().overlay(Theme.Colors.hairline)

            macroRow(color: Theme.NutrientColor.protein, label: "Protein", grams: goals.proteinG)
            macroRow(color: Theme.NutrientColor.carbs,   label: "Carbs",   grams: goals.carbsG)
            macroRow(color: Theme.NutrientColor.fat,     label: "Fat",     grams: goals.fatG)
            macroRow(color: Theme.NutrientColor.fiber,   label: "Fiber",   grams: goals.fiberG)

            Divider().overlay(Theme.Colors.hairline)

            HStack(spacing: 12) {
                Image(systemName: "drop.fill").foregroundStyle(Theme.NutrientColor.water)
                Text("Water").font(.system(size: 15))
                Spacer()
                Text(String(format: "%.1f L / day", goals.waterMlTarget / 1000))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
        }
    }

    private func macroRow(color: Color, label: String, grams: Double) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 15))
            Spacer()
            Text("\(Int(grams)) g")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }
}
