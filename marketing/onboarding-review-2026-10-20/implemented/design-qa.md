# Onboarding design QA — October 21, 2026

Source: ../mockups/02-start-with-what-matters-revised.png. Native implementation: 01-support.png through 05-ready.png. Combined comparison: comparison-final.jpg. Viewport: iPhone 17 Pro, 402×874 points, light appearance, fixture example data. The mock's app-content frames are approximately 390×844; native status/safe areas are intentionally preserved. Character artwork is the exact approved pose asset, not the generated mock's reconstruction.

## Review and corrections

Initial combined comparison (comparison-initial.jpg) found P2 mismatches in welcome logo alignment, selected-row styling, heading hierarchy and missing visible picker labels. Corrected to a leading welcome logo, lime selected row with circle/chevron, display heading wrapping, and explicit picker labels. Initial captures also caught a native transition; captures now settle before recording.

A later accessibility capture found a truncated primary label and scroll content visible beneath the action area at the largest text size (P2). Actions now live outside the clipped scrolling region, and primary labels grow vertically. 09-large-text-permission.png shows the complete Review & allow Pulse label and separate unobscured actions. The full disclosure remains scrollable; its opening and content are verified by UI tests.

The final combined image was opened and reviewed against the selected storyboard. All five screens, the grouped final shortcuts, full focus quote, opt-in save and skip actions, editable targets, keyboard sheet and privacy sheet are present. Current Daylight colors/fonts and approved brand assets are used. No unresolved P0/P1/P2 visual issues in the captured states.

Native production adaptations: age uses a birth-date picker to preserve existing profile/calculation behavior; measurement fields support explicit metric/imperial entry; estimates use actual calculator output rather than fixed illustrative values; full AI disclosure is a sheet before granting consent; focus length matches the existing 300-scalar memory limit; adult confirmation is explicit; optional shot/preferences setup is deferred to Profile. Contextual focus prompt reflects the support choice. The final review preserves the full typed sentence.

P3 differences: system pickers and sheet chrome differ from the illustrative generated input cards; standard SF Symbols omit decorative colored icon circles. Cove is the approved production pose rather than a new rendering. These do not block the selected flow.

Verification scope: native simulator and no-write UI fixtures. No website/browser rendering is claimed. Real-account onboarding writes and physical-device Health grants remain outside this pass. This is not an App Store submission-readiness certification.

final result: passed
