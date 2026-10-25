import XCTest
import SwiftUI
import UIKit
@testable import Footing

@MainActor
final class ProfileRenderingTests: XCTestCase {
    func testProfileMetadataResolvesWithinDeviceStackBudget() async {
        let resolved = expectation(description: "Profile metadata resolved on a device-sized stack")
        // Type metadata resolution is thread-safe and needs no UIKit access. The phone’s
        // crash report has a roughly 1 MB main-thread stack; a simulator can hide this bug.
        let worker = Thread {
            let bytes = MemoryLayout<ProfileView.Body>.size
            print("Profile root value storage: \(bytes) bytes")
            XCTAssertLessThan(bytes, 8 * 1024,
                              "Profile’s root must not embed the full settings/modifier tree.")
            resolved.fulfill()
        }
        worker.stackSize = 1024 * 1024
        worker.start()
        await fulfillment(of: [resolved], timeout: 10)
    }

    func testProfileCanRenderRepeatedlyWithLargeText() {
        for _ in 0..<3 {
            let host = UIHostingController(rootView: ProfileView.preview()
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge))
            host.loadViewIfNeeded()
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            let size = host.sizeThatFits(in: CGSize(width: 390, height: 844))
            XCTAssertTrue(size.width.isFinite && size.height.isFinite)
            XCTAssertGreaterThan(size.width, 0)
            XCTAssertGreaterThan(size.height, 0)
        }
    }

    func testUsualMealActionHasARealSymbolAndRendersInBothAppearances() throws {
        XCTAssertNotNil(UIImage(systemName: MealSectionView.saveUsualMealSymbol),
                        "A missing SF Symbol leaves an invisible but tappable meal action.")
        for scheme in [ColorScheme.light, .dark] {
            let card = MealSectionView(meal: .breakfast, logs: [], onSaveUsualMeal: {})
                .frame(width: 350).padding(20)
                .background(Theme.Colors.ground)
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage)
            let capture = XCTAttachment(image: image)
            capture.name = "usual-meal-bookmark-\(scheme)"
            capture.lifetime = .keepAlways
            add(capture)
        }
    }

    func testShotCycleSavedStatusUsesTodaysCheckInAndRenders() throws {
        let vm = TodayViewModel()
        XCTAssertNil(vm.todayShotCycleCheckIn)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        func checkIn(_ date: Date) -> ShotCycleCheckIn {
            ShotCycleCheckIn(id: UUID(), userId: UUID(), checkinDate: date.isoDateString, cycleDay: 0,
                appetite: 3, fullness: 3, nausea: 1, energy: 3, digestion: 3, note: nil, createdAt: date)
        }
        vm.shotCycleCheckIns = [checkIn(yesterday)]
        XCTAssertNil(vm.todayShotCycleCheckIn, "Yesterday’s entry must not mark today as saved.")
        vm.shotCycleCheckIns.insert(checkIn(.now), at: 0)
        XCTAssertNotNil(vm.todayShotCycleCheckIn)
        for saved in [false, true] {
            let tile = ShotCycleTile(cycleDay: 0, hasCheckIn: saved, onTap: {})
                .frame(width: 170).padding(16).background(Theme.Colors.ground)
            let renderer = ImageRenderer(content: tile)
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage)
            let attachment = XCTAttachment(image: image)
            attachment.name = saved ? "shot-cycle-saved" : "shot-cycle-not-saved"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        vm.selectedDate = yesterday
        XCTAssertNil(vm.todayShotCycleCheckIn, "The Today-only status must not leak into another date.")
    }

    func testHealthSupportCardsRenderWithLargeText() throws {
        let recovery = RecoveryOpportunity(workoutName: "Strength", durationMinutes: 30, proteinGap: 40, waterGapMl: 500, finishedAt: .now)
        let cards = VStack(spacing: 16) {
            GentlerDayCard(onFamiliar: {}, onLighter: {}, onDismiss: {})
            RecoveryCoachCard(opportunity: recovery, onCloseGap: {}, onReviewWater: {}, onAddWater: { _ in })
        }.frame(width: 350).padding(20).background(Theme.Colors.ground)
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        let renderer = ImageRenderer(content: cards)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "health-support-large-text"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testHealthSupportCardsReviewCapture() throws {
        let recovery = RecoveryOpportunity(workoutName: "Strength", durationMinutes: 30, proteinGap: 40, waterGapMl: 500, finishedAt: .now)
        let cards = VStack(alignment: .leading, spacing: 20) {
            GentlerDayCard(onFamiliar: {}, onLighter: {}, onDismiss: {})
            RecoveryCoachCard(opportunity: recovery, onCloseGap: {}, onReviewWater: {}, onAddWater: { _ in })
        }.frame(width: 350).padding(20).background(Theme.Colors.ground)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: cards)
        renderer.scale = 3
        let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
        attachment.name = "gentler-day-and-recovery"; attachment.lifetime = .keepAlways; add(attachment)
    }

}
