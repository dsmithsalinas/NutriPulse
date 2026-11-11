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
            .daylightReadableWidth()
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
            .daylightReadableWidth()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            }
            // The page's own ground behind the bar once content scrolls under it. Hidden, the
            // in-content title and controls slid under the clock and the floating back button.
            // At rest the bar matches the page, so nothing changes until the user scrolls.
            .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
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

// MARK: - Adaptive layout

extension View {
    /// Apply to a scroll view's content (after page padding), or to a sheet's canvas.
    /// The outer frame keeps the scroll/safe-area surface full width. No size-based
    /// branches or identity changes: drafts, navigation and focus survive a resize.
    func daylightReadableWidth(_ maximum: CGFloat = 720) -> some View {
        frame(maxWidth: maximum).frame(maxWidth: .infinity)
    }
}

/// Equal-width tiles become a vertical list in narrow windows and at larger text sizes.
/// Layout changes placement without replacing the children or their state.
struct DaylightTileRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var content: Content

    var body: some View {
        DaylightTileLayout(stacked: typeSize >= .xxxLarge) { content }
    }
}

struct DaylightTileLayout: Layout {
    var stacked = false
    var spacing: CGFloat = Theme.Spacing.tileGap

    private func isVertical(_ width: CGFloat, count: Int) -> Bool {
        stacked || width < CGFloat(count) * 160 + CGFloat(max(0, count - 1)) * spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width ?? 720
        let vertical = isVertical(width, count: subviews.count)
        let gaps = CGFloat(subviews.count - 1) * spacing
        let childWidth = vertical ? width : max(0, (width - gaps) / CGFloat(subviews.count))
        let heights = subviews.map { $0.sizeThatFits(.init(width: childWidth, height: nil)).height }
        return CGSize(width: width, height: vertical ? heights.reduce(0, +) + gaps : heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let vertical = isVertical(bounds.width, count: subviews.count)
        let gaps = CGFloat(subviews.count - 1) * spacing
        let width = vertical ? bounds.width : max(0, (bounds.width - gaps) / CGFloat(subviews.count))
        var origin = bounds.origin
        for view in subviews {
            let childProposal = ProposedViewSize(width: width, height: nil)
            view.place(at: origin, anchor: .topLeading, proposal: childProposal)
            if vertical { origin.y += view.sizeThatFits(childProposal).height + spacing }
            else { origin.x += width + spacing }
        }
    }
}


/// Dashboard groups share one scroll view. Wide windows place related groups in two
/// lanes; narrow windows keep their original reading order and view identities.
struct DaylightDashboard<Content: View>: View {
    var lanes: [Int] = [0, 1]
    var firstColumnFraction: CGFloat = 0.5
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var content: Content

    var body: some View {
        DaylightDashboardLayout(lanes: lanes, firstColumnFraction: firstColumnFraction, stacked: typeSize >= .xxxLarge) { content }
    }
}

struct DaylightDashboardLayout: Layout {
    var lanes: [Int]
    var firstColumnFraction: CGFloat = 0.5
    var stacked = false
    var spacing: CGFloat = Theme.Spacing.tileGap

    private func arrangement(width: CGFloat, subviews: Subviews) -> (CGSize, [CGRect]) {
        let expanded = !stacked && width >= 600 + spacing
        let fraction = min(0.7, max(0.3, firstColumnFraction))
        let widths = expanded ? [(width - spacing) * fraction, (width - spacing) * (1 - fraction)] : [width, width]
        var heights: [CGFloat] = [0, 0]
        var frames: [CGRect] = []
        for (index, child) in subviews.enumerated() {
            let lane = expanded && lanes.indices.contains(index) ? min(1, max(0, lanes[index])) : 0
            let childWidth = widths[lane]
            let height = child.sizeThatFits(.init(width: childWidth, height: nil)).height
            frames.append(CGRect(x: lane == 0 ? 0 : widths[0] + spacing, y: heights[lane], width: childWidth, height: height))
            heights[lane] += height + spacing
        }
        return (CGSize(width: width, height: max(0, (heights.max() ?? 0) - spacing)), frames)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? 1060, subviews: subviews).0
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrangement(width: bounds.width, subviews: subviews).1
        for (child, frame) in zip(subviews, frames) {
            child.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                        anchor: .topLeading, proposal: .init(width: frame.width, height: frame.height))
        }
    }
}
