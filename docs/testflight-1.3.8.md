# Footing 1.3.8 — Apple build preparation

Prepared November 12, 2026. Previous uploaded build: 1.3.7 (303). Expected git-derived build: 306 after this preparation commit. App and widget versions match. Archive/export validation evidence belongs in `build/TestFlight-1.3.8-306/release-verification.json`. Preparation is not upload, Apple processing, tester distribution, or App Review submission.

## Included

- Expanded iPhone layouts with reserved navigation rail, portrait bottom navigation, dedicated dashboard/logging layouts, readable secondary sheets and large-text fixes.
- Optional Apple Health nutrition reads, with independent source selection for calories, protein, carbs, total fat and fiber. Selected sources replace Footing totals for that nutrient; no imported meal copies or write-back.
- Source attribution, unknown-versus-zero handling, UUID deduplication, account isolation, refreshed corrections/deletions, and consistent selected totals in Today, Progress and Pulse.
- Local Pulse sanitizer update for source attribution and instructions against counting meals twice.

## Prior verification

Nutrition pass: 58 distinct Xcode checks (10 UI and 48 unit/rendering) and two Node context tests passed. Real simulator captures cover portrait, expanded, no-data and largest-text layouts. Physical Duo transitions and live signed Health imports are not claimed as verified. The build-preparation pass completed 554 unit checks (545 passed, nine opt-in checks skipped, zero failures) and 32 local Pulse/provider/consent/nutrition contract tests. The older Pulse test harness now includes the real consent helper with explicit consented fixtures and simulated unavailable lookups; production consent behavior is unchanged. Exact archive outcomes are recorded with the build artifacts.

## Before distribution

- Push the committed release source and deploy the updated `coach-chat` function with JWT/consent enforcement retained. No schema migration is required for nutrition importing. The server change is still local at preparation time.
- Publish the updated privacy-policy source at `marketing/site-v2/public/privacy.html`, and check App Store privacy declarations for the optional nutrition data and consented Pulse sharing. No policy publication or App Store metadata changes are part of preparation.
- Verify real Health permission allow/deny/revoke, import from the user's diabetes app, source selection, edits/deletions, foreground refresh and account switching on a signed device. Verify no re-entry or duplicate totals.
- Physical Duo fold/unfold, camera/audio, save/undo, notifications and widgets remain device checks.

## Suggested TestFlight notes

Footing now adapts to wider iPhone layouts while keeping portrait navigation familiar. You can optionally use Apple Health nutrition from another app: open Profile → Apple Health → Nutrition sources and choose a source separately for each nutrient. The chosen source replaces Footing’s total for that nutrient rather than adding both together. Please test permissions, source switching, missing data and updates made in the original app.

## Rollout — November 12, 2026

Release source `c372989011127cd2258a0eaadfb1b901afaf91d9` was pushed to `origin/codex/footing-testflight-1-3-2`. The signed 1.3.8 (306) archive was uploaded without rebuilding; Xcode confirmed “Upload succeeded” at 11:39 AM Pacific and reported “Uploaded package is processing.” App Store Connect’s Build Uploads table independently shows version 1.3.8, build 306, status Processing, created November 12 at 11:39 AM. Tester availability and App Review approval are separate states.

`coach-chat` v35 is ACTIVE with JWT verification enabled. All six deployed files match committed release source, including nutrition source handling and AI consent enforcement. An unauthenticated live request returned HTTP 401. The privacy policy at https://tryfooting.app/privacy returned HTTP 200 and matches the committed November 12 nutrition policy; Cloudflare deployment version `d56cceb6-c910-4b7c-a1aa-b23bd8c88ce1`. Physical Health and Duo acceptance checks above remain device checks.

The archive, export, upload and deployment evidence is in `build/TestFlight-1.3.8-306/release-verification.json` and accompanying logs.
