# Footing App Store screenshot set

Use real rendered Footing screens with fictional local data. No real user's food, medications, messages, Apple receipts or account details should appear. Files under `iphone-large/` are unaltered app captures at **1320 × 2868** from iPhone 18 Pro Max; `iphone-medium/` contains separately rendered **1206 × 2622** captures from iPhone 18 Pro. Both use opaque RGB PNGs and iOS 27.2. The live Media Manager currently marks medium display as required and large display as optional, so both are supplied. The `submission-medium/` and `submission-large/` folders hold the six selected files in upload order. They are candidates for selection, not fabricated device mockups.

Six selected screenshots are uploaded to App Store Connect for both medium and large iPhone displays, in numbered order. Nothing was submitted for review or released. The full capture galleries retain alternates for comparison.

## Recommended sequence

The first three images should explain the app before someone swipes. A clean six-image set is enough; use further slots only if they add a distinct benefit.

| Order | Screen | Optional headline for a later designed treatment | Purpose |
| --- | --- | --- | --- |
| 1 | Today, simple nutrition overview (`01-today-simple.png`) | **A little more footing, every day.** | Establish food, protein, water and the daily routine. Use the clean diary-based version for the opening image. |
| 2 | AI meal review (`02-ai-food-review.png`) | **Describe your meal. Review the details.** | Show actual editable food estimates. Clearly label **Premium** if adding marketing copy. Never imply recognition is exact or logging happens without confirmation. |
| 3 | Pulse conversation (`03-pulse-conversation.png`), or its start screen (`03-pulse.png`) | **Support that starts with your day.** | Show practical nutrition support with the in-app wellness disclaimer intact. Label **Premium** if using a designed treatment. |
| 4 | Progress (`04-progress.png`) | **See patterns. Start with today.** | Show protein floor days, trends and partial-log treatment. Fictional graph values are examples, not promised weight-loss outcomes. |
| 5 | Shot routine (`05-shot-routine.png`) | **Your shot routine, in one place.** | Explain optional schedule/injection record keeping. Do not market dose adjustment, treatment recommendations or efficacy. |
| 6 | Food detail (`08-food-detail.png`), or Profile (`07-profile.png`) | **Make familiar meals easier.** / **Your data. Your choices.** | Prefer food detail for feature discovery; use Profile if emphasizing permission and membership controls. |

Other candidates: Today with selected Health nutrition sources (`01-today.png`) for a Health-focused image; water picker (`06-water.png`) for a hydration detail. The search stress-test image (`02-food-search.png`) has deliberately numbered duplicate results and is **not recommended for publication**. The isolated water preview has a blank background, so prefer capturing the picker over Today for a designed hydration shot.

Keep founding-offer countdowns and “first 50” claims out of evergreen screenshots: availability can change after publication. The app and listing explain the current offer. A membership/payment screenshot belongs in subscription review materials; it does not need to take an early consumer-facing slot.

## iPhone Duo options

These are separate device assets, not two phones in one composition. Apple's accepted native dimensions are:

| Display | Portrait | Landscape |
| --- | --- | --- |
| Outer | **1398 × 2034** | **2034 × 1398** |
| Inner | **2007 × 2853** | **2853 × 2007** |

**Recommended Duo set:** Outer Today, outer food review, inner landscape Today, inner landscape Progress, inner food logging workspace, inner Pulse. This demonstrates the expanded layout instead of merely showing more whitespace. Capture Profile as an alternate for the sixth slot if it explains control better than another dashboard.

**Compact alternative:** outer Today, inner Today, inner Progress. This keeps the Duo story to three distinct views while the standard iPhone set covers the feature range.

Use the actual wide navigation rail and bounded panels already implemented in Footing. For both displays, verify readable text, sheets, keyboard, tab selection and retained drafts when changing display. Capture at native size; do not resize a tall iPhone screenshot, put iPad screenshots in the Duo slots, or invent an unfolded UI.

**Capture blocker as of November 15:** Xcode knows the iPhone Duo device type, but neither the installed iOS 27.0 runtime nor the newly downloaded iOS 27.2 arm64 runtime lists Duo among supported device types. `simctl create` rejects both combinations as incompatible. No runtime/device profiles were altered. Genuine Duo captures require a supported Apple runtime or a physical Duo; none are present in this folder. Installing 27.2 did not resolve this.

Apple says Duo screenshots become required in **April 2027** for apps using iOS 27.1 SDK or later. Uploading them also adds the “made for iPhone Duo” badge, so finish actual display acceptance before adding that claim.

## Visual treatment

Recommend starting with unframed, actual-app screenshots for the submission draft. If we create a marketing treatment, keep one short headline above one large screen, using existing Daylight ground/lime/indigo and bundled fonts. Make the actual app the dominant content. Avoid clinical claims, before/after bodies, invented reviews, pressure copy, or decorative device hardware that hides the UI. An optional product-page header is a separate asset, not a required screenshot.

## Capture provenance

- Source app: 1.3.9 (326), same feature UI as the TestFlight candidate, with later privacy-manifest-only edits during this preparation.
- Fixture routes live behind DEBUG flags and use production view implementations.
- Capture automation: `NutriPulseUITests/AppStoreCaptureUITests.swift`.
- Results under `build/AppStoreCaptures-*-20261115.xcresult`; per-file dimensions/device recorded in `iphone-large/capture-manifest.json`.
- Capture pass checks rendering and exports; it does not establish physical-device Health, Apple purchase, Duo fold/unfold, camera or microphone acceptance.
- [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
