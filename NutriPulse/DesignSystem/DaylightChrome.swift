import SwiftUI
import UIKit

// Daylight for the system pieces SwiftUI draws through UIKit: navigation bars, segmented
// pickers, and grouped forms. Every pushed screen and settings form picks this up, so the
// secondary screens match the rebuilt ones without each re-styling its own chrome.

enum DaylightChrome {
    /// Called once at launch (FootingApp.init).
    @MainActor
    static func install() {
        let ink = UIColor(Theme.Colors.textPrimary)
        let ground = UIColor(Theme.Colors.ground)

        func font(_ name: String, _ size: CGFloat, _ style: UIFont.TextStyle) -> UIFont {
            let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .bold)
            return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
        }

        // Navigation bars: the page's own ground behind them, no hairline, Bricolage titles.
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = ground
        bar.shadowColor = .clear
        bar.titleTextAttributes = [.foregroundColor: ink, .font: font("Figtree-Bold", 17, .headline)]
        bar.largeTitleTextAttributes = [.foregroundColor: ink, .font: font("BricolageGrotesque96pt-ExtraBold", 34, .largeTitle)]
        let plain = UIBarButtonItemAppearance()
        plain.normal.titleTextAttributes = [.font: font("Figtree-SemiBold", 17, .body)]
        bar.buttonAppearance = plain
        bar.backButtonAppearance = plain
        let done = UIBarButtonItemAppearance()
        done.normal.titleTextAttributes = [.font: font("Figtree-Bold", 17, .body)]
        bar.doneButtonAppearance = done
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
        UINavigationBar.appearance().tintColor = UIColor(Theme.Colors.primary)

        // Segmented pickers: an inverted selection, Figtree labels (matches the Log sheet's tab bar).
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = UIColor(Theme.Colors.selectionFill)
        segmented.setTitleTextAttributes([.foregroundColor: UIColor(Theme.Colors.selectionText), .font: font("Figtree-Bold", 14, .subheadline)], for: .selected)
        segmented.setTitleTextAttributes([.foregroundColor: ink, .font: font("Figtree-SemiBold", 14, .subheadline)], for: .normal)
    }
}

// MARK: - Forms

/// A grouped Form or List in Daylight: the page ground behind it, the brand tint on toggles and
/// pickers, and Figtree for row text. Pair each Section with `.daylightSection()` for white rows.
/// Usage: `Form { ... }.daylightForm()`
struct DaylightFormStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.ground.ignoresSafeArea())
            .font(Theme.Fonts.body(16))
            .tint(Theme.Colors.primary)
            .foregroundStyle(Theme.Colors.textPrimary)
    }
}

/// White rows for a Form/List section, like a Daylight tile.
struct DaylightSectionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.listRowBackground(Theme.Colors.surfaceCard)
    }
}

extension View {
    func daylightForm() -> some View { modifier(DaylightFormStyle()) }
    func daylightSection() -> some View { modifier(DaylightSectionStyle()) }
}

/// A Form/List section header in the Daylight eyebrow style. Usage:
/// `Section { ... } header: { DaylightSectionHeader("Units") }`
struct DaylightSectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        TileEyebrow(text, color: Theme.Colors.textFaint)
            .padding(.leading, -4)
    }
}

/// Footer text under a Form section.
struct DaylightSectionFooter: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(Theme.Fonts.body(13))
            .foregroundStyle(Theme.Colors.textSecondary)
    }
}

// MARK: - Pushed pages

/// A pushed Daylight screen keeps the system bar for the back button and swipe-back, but draws
/// its title in the content with `DaylightPageTitle`: the system title can't take Bricolage on
/// iOS 26. `navigationTitle` is still set, for the back-button menu and VoiceOver.
/// Usage: `ScrollView { DaylightPageTitle("Analytics"); ... }.daylightSubpage("Analytics")`
struct DaylightSubpage: ViewModifier {
    let title: String
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Theme.Colors.ground.ignoresSafeArea())
    }
}

extension View {
    func daylightSubpage(_ title: String) -> some View { modifier(DaylightSubpage(title: title)) }
}

/// The large title at the top of a pushed Daylight screen, with an optional line under it.
struct DaylightPageTitle: View {
    let title: String
    var subtitle: String? = nil

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Fonts.display(34, .extraBold, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
