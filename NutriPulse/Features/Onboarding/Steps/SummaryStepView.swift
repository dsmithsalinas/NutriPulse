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
                        .popIn(order: 0)

                    Text("So great to meet you, \(firstName).")
                        .font(Theme.Fonts.display(27, .extraBold, relativeTo: .title))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)
                        .accessibilityAddTraits(.isHeader)
                        .popIn(order: 1)

                    Text("Here's where we're starting. I'm ready when you are — anytime you need me, just say the word.")
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 9)
                        .padding(.horizontal, 8)
                        .popIn(order: 2)

                    targetsCard(goals)
                        .padding(.top, 22)
                        .popIn(order: 3)

                    Text("You can fine-tune these anytime in Settings.")
                        .font(Theme.Fonts.body(12.5))
                        .foregroundStyle(Theme.Colors.textFaint)
                        .padding(.top, 12)

                    Text("Footing is a wellness tracker, not a medical device, and Pulse is not a medical professional. Nothing here is medical advice — always talk to your doctor about medication and health decisions.")
                        .font(Theme.Fonts.body(11.5))
                        .foregroundStyle(Theme.Colors.textFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                onComplete()
            } label: {
                if vm.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Start tracking")
                }
            }
            .buttonStyle(.brandPrimary)
            .disabled(vm.isLoading)
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.vertical, 12)
            .background(Theme.Colors.ground)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func targetsCard(_ goals: CalculatedGoals) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(Int(goals.calories))")
                    .font(Theme.Fonts.number(56, .extraBold, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.NutrientColor.calories)
                Text("calories / day")
                    .font(Theme.Fonts.body(14))
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
                Text("Water").font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(String(format: "%.1f L / day", goals.waterMlTarget / 1000))
                    .font(Theme.Fonts.number(15, .bold, relativeTo: .body))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
        }
        .shadow(color: Color(hex: 0x0F172A, opacity: 0.06), radius: 1, y: 1)
    }

    private func macroRow(color: Color, label: String, grams: Double) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text("\(Int(grams)) g")
                .font(Theme.Fonts.number(15, .bold, relativeTo: .body))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }
}
