#if DEBUG
import SwiftUI
import WidgetKit

// `--widget-preview`: the Protein Floor widget's views at iPhone widget sizes, inside the app,
// so the design can be checked without adding widgets to a home screen. Lock Screen sizes sit
// on a dark wallpaper stand-in with white content, roughly as the system tints them.
struct WidgetGalleryPreview: View {
    private let partial = ProteinFloorSnapshot(proteinToday: 94, proteinGoal: 140, updatedAt: .now)
    private let cleared = ProteinFloorSnapshot(proteinToday: 146, proteinGoal: 140, updatedAt: .now)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DaylightPageTitle("Widgets")
                HStack(spacing: 16) {
                    home(partial, .systemSmall)
                    home(cleared, .systemSmall)
                }
                home(partial, .systemMedium)
                TileEyebrow("Lock Screen")
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        ProteinFloorWidgetView(snapshot: partial, family: .accessoryCircular)
                            .frame(width: 72, height: 72)
                        ProteinFloorWidgetView(snapshot: partial, family: .accessoryRectangular)
                            .frame(width: 172, height: 76)
                    }
                    ProteinFloorWidgetView(snapshot: partial, family: .accessoryInline)
                }
                .foregroundStyle(.white)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0x1E293B), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .environment(\.colorScheme, .dark)
            }
            .padding(Theme.Spacing.page)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
    }

    private func home(_ snapshot: ProteinFloorSnapshot, _ family: WidgetFamily) -> some View {
        let size = family == .systemMedium ? CGSize(width: 364, height: 170) : CGSize(width: 170, height: 170)
        return ProteinFloorWidgetView(snapshot: snapshot, family: family)
            .padding(family == .systemMedium ? 12 : 16)
            .frame(width: size.width, height: size.height)
            .background {
                if family == .systemSmall {
                    ProteinFloorWidgetBackground(snapshot: snapshot)
                } else {
                    Theme.Colors.ground
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color(hex: 0x0F172A, opacity: 0.12), radius: 10, y: 4)
    }
}
#endif
