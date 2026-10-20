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

}
